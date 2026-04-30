
import os
import sys
from dotenv import load_dotenv

# Add backend to path
sys.path.append(os.path.abspath('c:/Working Folder/GpayHomeAccount/backend'))

from app.db.supabase_client import insert_transaction, _get_client

def test_insert():
    load_dotenv('c:/Working Folder/GpayHomeAccount/backend/.env')
    
    # Check if client works
    client = _get_client()
    if not client:
        print("Failed to initialize Supabase client")
        return

    print("Supabase client initialized")
    
    # Test insertion
    user_id = "test_user_id"
    date_str = "30 Apr 2026"
    amount = "1500.00"
    recipient = "Test Recipient"
    upi_id = "test@upi"
    tx_type = "expense"
    tag = "Others"
    source = "manual"
    
    print(f"Attempting to insert transaction for user: {user_id}")
    success = insert_transaction(
        user_id=user_id,
        date_str=date_str,
        amount=amount,
        recipient=recipient,
        upi_id=upi_id,
        tx_type=tx_type,
        tag=tag,
        source=source
    )
    
    if success:
        print("Insertion successful!")
    else:
        print("Insertion failed.")

    # Test insertion with invalid date
    print("\nAttempting to insert transaction with invalid date...")
    success = insert_transaction(
        user_id=user_id,
        date_str="Invalid Date",
        amount=amount,
        recipient=recipient,
        upi_id=upi_id,
        tx_type=tx_type,
        tag=tag,
        source=source
    )
    
    if success:
        print("Insertion (invalid date) successful!")
    else:
        print("Insertion (invalid date) failed.")

if __name__ == "__main__":
    test_insert()
