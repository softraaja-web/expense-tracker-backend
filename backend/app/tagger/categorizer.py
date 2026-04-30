"""
Auto-tagging module for transaction categorization.
Uses keyword matching against recipient names and UPI IDs.
"""

import logging
from typing import Optional

logger = logging.getLogger(__name__)

# ─── Category Keywords ──────────────────────────────────────────────
CATEGORY_KEYWORDS: dict[str, list[str]] = {
    "Food": [
        "swiggy", "zomato", "dominos", "pizza", "burger", "mcdonald",
        "kfc", "subway", "restaurant", "cafe", "coffee", "starbucks",
        "food", "eat", "dine", "biryani", "kitchen", "bakery",
        "dunkin", "baskin", "ice cream", "chai", "tea", "hotel",
        "mess", "canteen", "tiffin", "barbeque", "grill",
    ],
    "Travel": [
        "uber", "ola", "rapido", "metro", "bus", "irctc", "redbus",
        "makemytrip", "goibibo", "cleartrip", "yatra", "flight",
        "train", "cab", "auto", "rickshaw", "taxi", "petrol",
        "fuel", "hp", "indian oil", "bharat petroleum", "shell",
        "parking", "fastag", "toll",
    ],
    "Shopping": [
        "amazon", "flipkart", "myntra", "ajio", "meesho", "snapdeal",
        "mall", "shop", "store", "mart", "bazaar", "retail",
        "reliance", "dmart", "bigbasket", "grofers", "blinkit",
        "zepto", "instamart", "jiomart", "nykaa", "purplle",
    ],
    "Bills": [
        "electricity", "water", "gas", "broadband", "jio", "airtel",
        "vodafone", "vi", "bsnl", "wifi", "internet", "bill",
        "recharge", "dth", "tata sky", "dish tv", "postpaid",
        "prepaid", "insurance", "lic", "emi", "loan",
        "rent", "maintenance", "society",
    ],
    "Entertainment": [
        "netflix", "hotstar", "spotify", "prime", "disney",
        "pvr", "inox", "cinema", "movie", "game", "gaming",
        "steam", "playstation", "xbox", "youtube", "premium",
        "zee5", "sonyliv", "jiocinema", "voot", "mubi",
    ],
    "Health": [
        "pharmacy", "medical", "hospital", "doctor", "clinic",
        "apollo", "medplus", "netmeds", "1mg", "pharmeasy",
        "lab", "diagnostic", "health", "gym", "fitness",
        "cult", "yoga",
    ],
    "Education": [
        "school", "college", "university", "course", "udemy",
        "coursera", "unacademy", "byju", "tuition", "coaching",
        "book", "stationery", "exam", "fee",
    ],
    "Transfer": [
        "transfer", "self", "own account", "savings",
        "neft", "imps", "rtgs", "bank",
    ],
}


def categorize_transaction(
    recipient: str,
    upi_id: Optional[str] = None,
) -> str:
    """
    Auto-categorize a transaction based on recipient name and UPI ID.
    
    Args:
        recipient: Name of the recipient/merchant
        upi_id: UPI ID if available
        
    Returns:
        Category tag string (e.g., "Food", "Travel", "Others")
    """
    # Combine recipient and UPI ID for matching
    search_text = recipient.lower()
    if upi_id:
        search_text += " " + upi_id.lower()

    # Check each category's keywords
    for category, keywords in CATEGORY_KEYWORDS.items():
        for keyword in keywords:
            if keyword in search_text:
                logger.info(
                    f"Auto-tagged '{recipient}' as '{category}' "
                    f"(matched keyword: '{keyword}')"
                )
                return category

    logger.info(f"No category match for '{recipient}', defaulting to 'Others'")
    return "Others"


def get_available_tags() -> list[str]:
    """Return list of all available category tags."""
    return list(CATEGORY_KEYWORDS.keys()) + ["Others"]
