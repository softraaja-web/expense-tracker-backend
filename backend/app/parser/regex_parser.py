"""
Regex-based parser for Google Pay transaction screenshots.
Handles common GPay text patterns for amount, recipient, UPI ID, date, and type.
"""

import re
import logging
from typing import Optional
from app.models.transaction import TransactionData

logger = logging.getLogger(__name__)

# ─── Amount Patterns ────────────────────────────────────────────────
AMOUNT_PATTERNS = [
    r'[₹?]\s*([\d,]+\.?\d*)',                    # ₹1,500.00 or ?1,500.00 (common OCR error)
    r'Rs\.?\s*([\d,]+\.?\d*)',                   # Rs. 1500 or Rs 1500
    r'INR\s*([\d,]+\.?\d*)',                      # INR 1500
    r'(?:Amount|Paid|Sent)\s*:?\s*₹?\s*([\d,]+\.?\d*)', # Amount: 500
    r'(?:Paid|Sent|Received)\s*[₹]?\s*([\d,]+\.?\d*)',  # Paid ₹500
    r'([\d,]+\.?\d*)\s*(?:paid|sent|received)',   # 500 paid
]

# ─── Recipient Patterns ─────────────────────────────────────────────
RECIPIENT_PATTERNS = [
    r'(?i)(?:Paid to|Sent to|To|Paying|to)\s*\n?\s*(.+?)(?:\s+On|\s+Ref|\n|$)',   # Paid to \n John Doe
    r'(?i)(?:Received from|From|from)\s*\n?\s*(.+?)(?:\s+in|\s+On|\n|$)',           # Received from \n Jane
    r'(?i)(?:Beneficiary|Name)\s*:?\s*\n?\s*(.+?)(?:\s+On|\s+Ref|\n|$)',        # Beneficiary: \n John
]

# ─── UPI ID Patterns ────────────────────────────────────────────────
UPI_PATTERNS = [
    r'([\w.\-]+@[\w]+)',                           # user@upi or user@okaxis
    r'UPI\s*(?:ID|Id|id)\s*:?\s*([\w.\-]+@[\w]+)', # UPI ID: user@upi
]

# ─── Date Patterns ──────────────────────────────────────────────────
DATE_PATTERNS = [
    r'(\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{4})',  # 15 Jan 2024
    r'(\d{1,2}\s+(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{4})',  # 15 January 2024
    r'(\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4})',        # 15/01/2024 or 15-01-24
    r'(\d{4}[/\-]\d{1,2}[/\-]\d{1,2})',           # 2024/01/15
    r'(?:Date|Completed on|Debited on)\s*:?\s*(.+?)(?:\n|$)',  # Date: 15 Jan 2024
]

# ─── Transaction Type Patterns ──────────────────────────────────────
TYPE_PATTERNS = [
    (r'(?i)(?:received|credited|received from|from)', "income"),
    (r'(?i)(?:paid|sent|debited|to|paying)', "expense"),
]


def _extract_amount(text: str) -> Optional[str]:
    """Extract transaction amount from OCR text."""
    for pattern in AMOUNT_PATTERNS:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            amount = match.group(1).replace(",", "").strip()
            try:
                # Validate it's a real number
                float(amount)
                return f"₹{amount}"
            except ValueError:
                continue
    return None


def _extract_recipient(text: str) -> Optional[str]:
    """Extract recipient name from OCR text."""
    for pattern in RECIPIENT_PATTERNS:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            name = match.group(1).strip()
            # Clean up the name - remove trailing special chars
            name = re.sub(r'[^\w\s]$', '', name).strip()
            if len(name) > 1 and len(name) < 100:
                return name
    return None


def _extract_upi_id(text: str) -> Optional[str]:
    """Extract UPI ID from OCR text."""
    for pattern in UPI_PATTERNS:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            upi_id = match.group(1) if '@' in match.group(1) else match.group(0)
            upi_id = upi_id.strip()
            if '@' in upi_id:
                return upi_id
    return None


def _extract_date(text: str) -> Optional[str]:
    """Extract transaction date from OCR text."""
    for pattern in DATE_PATTERNS:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            date_str = match.group(1).strip()
            if len(date_str) > 4:
                return date_str
    return None


def _extract_type(text: str) -> str:
    """Determine transaction type (expense/income)."""
    for pattern, tx_type in TYPE_PATTERNS:
        if re.search(pattern, text):
            return tx_type
    return "expense"  # Default to expense


def parse_transaction(ocr_text: str) -> tuple[TransactionData | None, float]:
    """
    Parse OCR text using regex patterns to extract transaction details.
    
    Args:
        ocr_text: Raw text from OCR extraction
        
    Returns:
        Tuple of (TransactionData or None, confidence_score)
        confidence_score: 0.0 to 1.0 based on how many fields were extracted
    """
    logger.info("Starting regex parsing...")

    amount = _extract_amount(ocr_text)
    recipient = _extract_recipient(ocr_text)
    upi_id = _extract_upi_id(ocr_text)
    date = _extract_date(ocr_text)
    tx_type = _extract_type(ocr_text)

    # Calculate confidence based on extracted fields
    fields_found = sum([
        bool(amount),      # Weight: 0.35
        bool(recipient),   # Weight: 0.30
        bool(date),        # Weight: 0.25
        bool(upi_id),      # Weight: 0.10
    ])

    confidence = 0.0
    if amount:
        confidence += 0.35
    if recipient:
        confidence += 0.30
    if date:
        confidence += 0.25
    if upi_id:
        confidence += 0.10

    logger.info(
        f"Regex results: amount={amount}, recipient={recipient}, "
        f"date={date}, upi_id={upi_id}, type={tx_type}, "
        f"confidence={confidence:.2f}"
    )

    # If we got at least amount OR recipient, return partial data
    if amount or recipient:
        return TransactionData(
            date=date or "",
            amount=amount or "",
            recipient=recipient or "",
            upi_id=upi_id,
            type=tx_type,
            confidence=confidence,
            raw_text=ocr_text,
        ), confidence

    # Complete parsing failure
    logger.warning("Regex parsing failed to extract any meaningful data")
    return None, 0.0
