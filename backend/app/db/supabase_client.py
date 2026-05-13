"""
Supabase PostgreSQL client integration.
"""

import re
from datetime import datetime, date
from typing import Optional
import logging
from supabase import create_client, Client
from app.config import get_settings

logger = logging.getLogger(__name__)


def _get_client() -> Optional[Client]:
    """Create and return a Supabase client."""
    settings = get_settings()
    
    if not settings.supabase_url or not settings.supabase_key:
        logger.error("Supabase URL or Key not configured")
        return None
        
    try:
        supabase: Client = create_client(settings.supabase_url, settings.supabase_key)
        return supabase
    except Exception as e:
        logger.error(f"Failed to initialize Supabase client: {e}")
        return None



def get_user_profile(user_id: str) -> Optional[dict]:
    """Fetch user profile from Supabase."""
    client = _get_client()
    if not client:
        return None

    try:
        response = client.table("users").select("*").eq("id", user_id).execute()
        if hasattr(response, 'data') and response.data:
            return response.data[0]
        return None
    except Exception as e:
        logger.error(f"Failed to fetch user profile: {e}")
        return None


def create_user_profile(user_id: str, email: str) -> Optional[dict]:
    """Create a new user profile with free plan and 20 credits."""
    client = _get_client()
    if not client:
        return None

    try:
        data = {
            "id": user_id,
            "email": email,
            "plan": "free",
            "credits": 20,
            "expiry_date": None
        }
        response = client.table("users").insert(data).execute()
        if hasattr(response, 'data') and response.data:
            return response.data[0]
        return None
    except Exception as e:
        logger.error(f"Failed to create user profile: {e}")
        return None


def update_user_credits(user_id: str, delta: int) -> bool:
    """Increment or decrement user credits."""
    client = _get_client()
    if not client:
        return False

    try:
        # First get current credits
        profile = get_user_profile(user_id)
        if not profile:
            return False
        
        new_credits = max(0, profile.get("credits", 0) + delta)
        
        response = client.table("users").update({"credits": new_credits}).eq("id", user_id).execute()
        return bool(hasattr(response, 'data') and response.data)
    except Exception as e:
        logger.error(f"Failed to update user credits: {e}")
        return False


def update_user_plan(user_id: str, plan: str, expiry_date: str, credits: int = 999999) -> bool:
    """Upgrade user plan and set expiry date."""
    client = _get_client()
    if not client:
        return False

    try:
        data = {
            "plan": plan,
            "expiry_date": expiry_date,
            "credits": credits
        }
        response = client.table("users").update(data).eq("id", user_id).execute()
        return bool(hasattr(response, 'data') and response.data)
    except Exception as e:
        logger.error(f"Failed to update user plan: {e}")
        return False


def insert_transaction(
    user_id: str,
    date_str: str,
    amount: str,
    recipient: str,
    upi_id: str = "",
    tx_type: str = "expense",
    tag: str = "Others",
    source: str = "screenshot",
) -> tuple[bool, str]:
    """
    Insert a transaction into Supabase.
    Returns (success, message/error)
    """
    client = _get_client()
    if not client:
        return False, "Supabase client not initialized. Check configuration."

    try:
        # Normalize Date (Target: YYYY-MM-DD for PostgreSQL)
        formatted_date = None
        try:
            cleaned_date = date_str.strip()
            for fmt in ("%d %B %Y", "%d %b %Y", "%Y-%m-%d", "%d %b %y"):
                try:
                    dt = datetime.strptime(cleaned_date, fmt)
                    formatted_date = dt.strftime("%Y-%m-%d")
                    break
                except ValueError:
                    continue
            
            # Default to today if parsing failed
            if not formatted_date:
                logger.warning(f"Could not parse date '{date_str}', defaulting to today.")
                formatted_date = date.today().strftime("%Y-%m-%d")
        except Exception as e:
            logger.warning(f"Date formatting error: {e}, defaulting to today.")
            formatted_date = date.today().strftime("%Y-%m-%d")

        # Normalize Amount
        numeric_amount = re.sub(r'[^\d.]', '', amount)
        final_amount = 0.0
        if numeric_amount:
            try:
                final_amount = float(numeric_amount)
            except ValueError:
                pass
                
        data = {
            "user_id": user_id,
            "amount": final_amount,
            "to_name": recipient,
            "upi_id": upi_id if upi_id else None,
            "date": formatted_date, # Use actual date format for Supabase DATE col
            "type": tx_type,
            "tag": tag,
            "source": source
        }
        
        response = client.table("transactions").insert(data).execute()
        
        # Check if insert was successful
        if hasattr(response, 'data') and response.data:
            msg = f"Saved: {recipient} - {amount}"
            logger.info(f"Appended transaction for user {user_id}: {msg}")
            return True, msg
        else:
            err_msg = f"Failed to save: {response}"
            logger.error(err_msg)
            return False, err_msg
            
    except Exception as e:
        error_str = str(e)
        # Check if error is due to missing 'source' column (fallback for older DBs)
        if "source" in error_str.lower():
            logger.warning("Database missing 'source' column. Retrying without source field...")
            try:
                if "source" in data:
                    del data["source"]
                response = client.table("transactions").insert(data).execute()
                if hasattr(response, 'data') and response.data:
                    return True, f"Saved (without source): {recipient} - {amount}"
            except Exception as retry_e:
                error_str = f"Retry failed: {retry_e}"
        
        logger.error(f"Failed to append row: {error_str}")
        return False, error_str


def get_user_transactions(user_id: str, count: int = 20, tx_type: Optional[str] = None, month: Optional[int] = None, year: Optional[int] = None) -> list[dict]:
    """
    Fetch recent transactions for a specific user, optionally filtered by type.
    """
    client = _get_client()
    if not client:
        return []

    try:
        query = client.table("transactions")\
            .select("*")\
            .eq("user_id", user_id)
        
        if tx_type and tx_type != 'All':
            query = query.eq("type", tx_type.lower())

        if year:
            if month:
                # Filter for specific month and year
                import calendar
                last_day = calendar.monthrange(year, month)[1]
                start_date = f"{year}-{month:02d}-01"
                end_date = f"{year}-{month:02d}-{last_day}"
                query = query.gte("date", start_date).lte("date", end_date)
            else:
                # Filter for entire year
                query = query.gte("date", f"{year}-01-01").lte("date", f"{year}-12-31")

        response = query.order("date", desc=True)\
            .order("created_at", desc=True)\
            .limit(count)\
            .execute()
            
        if hasattr(response, 'data') and response.data:
            transactions = []
            for row in response.data:
                # Format back to frontend expected structure
                
                # Format date back to 'DD MMM YYYY' for frontend
                display_date = row.get("date", "")
                if display_date:
                    try:
                        dt = datetime.strptime(display_date, "%Y-%m-%d")
                        display_date = dt.strftime("%d %b %Y")
                    except ValueError:
                        pass
                
                tx = {
                    "id": str(row.get("id", "")),
                    "date": display_date,
                    "amount": str(row.get("amount", 0)),
                    "recipient": row.get("to_name", ""),
                    "upi_id": row.get("upi_id", ""),
                    "type": row.get("type", "expense"),
                    "tag": row.get("tag", "Others"),
                    "source": row.get("source", "screenshot")
                }
                transactions.append(tx)
            return transactions
            
        return []
    except Exception as e:
        logger.error(f"Failed to fetch transactions for user {user_id}: {e}")
        return []


def get_user_daily_total(user_id: str, target_date: Optional[str] = None) -> dict:
    """
    Calculate summary metrics for a specific user on a given date.
    Returns {total_expense, total_income, net_balance, transaction_count}
    """
    if not target_date:
        formatted_target = date.today().strftime("%Y-%m-%d")
    else:
        formatted_target = None
        for fmt in ("%d %B %Y", "%d %b %Y", "%Y-%m-%d"):
            try:
                dt = datetime.strptime(target_date.strip(), fmt)
                formatted_target = dt.strftime("%Y-%m-%d")
                break
            except ValueError:
                continue
                
        if not formatted_target:
             logger.warning(f"Could not parse target date for daily total: {target_date}")
             return {"total_expense": 0.0, "total_income": 0.0, "net_balance": 0.0, "transaction_count": 0}
             
    client = _get_client()
    if not client:
        return {"total_expense": 0.0, "total_income": 0.0, "net_balance": 0.0, "transaction_count": 0}

    try:
        response = client.table("transactions")\
            .select("amount, type")\
            .eq("user_id", user_id)\
            .eq("date", formatted_target)\
            .execute()
            
        if hasattr(response, 'data') and response.data:
            total_expense = sum(float(row.get("amount", 0)) for row in response.data if row.get("type") == "expense")
            total_income = sum(float(row.get("amount", 0)) for row in response.data if row.get("type") == "income")
            
            return {
                "total_expense": total_expense,
                "total_income": total_income,
                "net_balance": total_income - total_expense,
                "transaction_count": len(response.data)
            }
            
        return {"total_expense": 0.0, "total_income": 0.0, "net_balance": 0.0, "transaction_count": 0}
    except Exception as e:
        logger.error(f"Failed to calculate daily total for user {user_id}: {e}")
        return {"total_expense": 0.0, "total_income": 0.0, "net_balance": 0.0, "transaction_count": 0}


def delete_transaction(user_id: str, transaction_id: str) -> tuple[bool, str]:
    """
    Delete a transaction from Supabase.
    """
    client = _get_client()
    if not client:
        return False, "Supabase client not initialized"

    try:
        # Delete only if it belongs to the user
        response = client.table("transactions")\
            .delete()\
            .eq("id", transaction_id)\
            .eq("user_id", user_id)\
            .execute()
            
        if hasattr(response, 'data') and response.data:
            return True, "Transaction deleted successfully"
        else:
            return False, "Transaction not found or not owned by user"
    except Exception as e:
        logger.error(f"Failed to delete transaction {transaction_id}: {e}")
        return False, str(e)
