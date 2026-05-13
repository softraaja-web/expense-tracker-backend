"""
Firebase Authentication middleware.
"""

import os
import json
import logging
from typing import Optional
from fastapi import Request, HTTPException, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import firebase_admin
from firebase_admin import credentials, auth
from datetime import datetime, timezone
from app.config import get_settings
from app.db.supabase_client import get_user_profile, create_user_profile, update_user_plan

logger = logging.getLogger(__name__)

security = HTTPBearer()

# --- Firebase Initialization ---
def _initialize_firebase():
    """Initialize Firebase Admin SDK."""
    if firebase_admin._apps:
        return # Already initialized
        
    settings = get_settings()
    cred_path = settings.firebase_credentials_json
    
    if not cred_path:
        logger.warning("Firebase credentials not configured. Auth will fail.")
        return

    try:
        if not cred_path:
            logger.error("FIREBASE_CREDENTIALS_JSON is empty or not set.")
            return

        # 1. Try as a file path
        if os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
            logger.info("Firebase Admin SDK initialized from file.")
            return

        # 2. Try as a JSON string
        # Clean the string (remove potential surrounding quotes or escaping)
        cleaned_json = cred_path.strip()
        if cleaned_json.startswith("'") or cleaned_json.startswith('"'):
            cleaned_json = cleaned_json[1:-1]
        
        try:
            cred_dict = json.loads(cleaned_json)
            cred = credentials.Certificate(cred_dict)
            firebase_admin.initialize_app(cred)
            logger.info("Firebase Admin SDK initialized from JSON string.")
        except json.JSONDecodeError as je:
            logger.error(f"Failed to parse FIREBASE_CREDENTIALS_JSON as JSON: {je}")
            # Log a small snippet of the string for debugging (hide sensitive parts)
            snippet = cleaned_json[:20] + "..." + cleaned_json[-20:] if len(cleaned_json) > 40 else cleaned_json
            logger.error(f"JSON Snippet: {snippet}")
    except Exception as e:
        logger.error(f"Unexpected error initializing Firebase: {e}")

# Initialize on module load
_initialize_firebase()


def verify_firebase_token(id_token: str) -> dict:
    """
    Verify Firebase JWT token and return user data.
    """
    try:
        decoded_token = auth.verify_id_token(id_token, clock_skew_seconds=10)
        return {
            "uid": decoded_token.get("uid"),
            "email": decoded_token.get("email"),
            "name": decoded_token.get("name", "")
        }
    except Exception as e:
        logger.error(f"Firebase token verification failed: {e}")
        raise HTTPException(
            status_code=401,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def get_current_user(credentials: HTTPAuthorizationCredentials = Security(security)) -> dict:
    """
    FastAPI dependency to extract and verify the current user from Bearer token.
    Also handles user initialization and plan expiry logic.
    """
    token = credentials.credentials
    user_data = verify_firebase_token(token)
    uid = user_data.get("uid")
    email = user_data.get("email")

    if uid:
        # Check/Initialize user in Supabase
        profile = get_user_profile(uid)
        if not profile:
            logger.info(f"New user detected, creating profile for {email}")
            profile = create_user_profile(uid, email)
        
        # Fallback if profile is still None (DB issue)
        if not profile:
            logger.warning(f"Could not load/create profile for {uid}, using defaults")
            profile = {"plan": "free", "credits": 20}
        
        # Check plan expiry for non-free plans
        if profile.get("plan") != "free":
            expiry_str = profile.get("expiry_date")
            if expiry_str:
                try:
                    # Parse ISO format expiry date
                    expiry_date = datetime.fromisoformat(expiry_str.replace("Z", "+00:00"))
                    if expiry_date < datetime.now(timezone.utc):
                        logger.info(f"Plan expired for user {uid}, downgrading to free.")
                        update_user_plan(uid, "free", None, 0)
                        profile["plan"] = "free"
                        profile["credits"] = 0
                except Exception as e:
                    logger.error(f"Error checking plan expiry: {e}")

        # Add profile info to user_data for use in endpoints
        user_data["profile"] = profile

    return user_data
