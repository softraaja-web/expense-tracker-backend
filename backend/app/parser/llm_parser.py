"""
LLM-based fallback parser using Google Gemini.
Used when regex parsing fails or has low confidence.
"""

import json
import logging
import asyncio
from typing import Optional, Tuple
import google.generativeai as genai
from app.models.transaction import TransactionData
from app.config import get_settings

logger = logging.getLogger(__name__)

# Structured prompt for Gemini
EXTRACTION_PROMPT = """You are a transaction data extractor. Extract the following fields from this Google Pay screenshot OCR text.

OCR Text:
---
{ocr_text}
---

Extract EXACTLY these fields and return as JSON:
{{
    "date": "transaction date in DD MMM YYYY format (e.g., 15 Jan 2024)",
    "amount": "amount with ₹ symbol (e.g., ₹1,500.00)",
    "recipient": "name of the person or merchant paid to or received from",
    "upi_id": "UPI ID if visible (e.g., user@upi), null if not found",
    "type": "expense or income"
}}

Rules:
- If a field cannot be determined, use empty string "" (except upi_id which should be null)
- IMPORTANT: GPay OCR often misreads the '₹' symbol as the number '2' or '?'. For example, if the OCR says '2100' or '?100' at the top, it is actually '₹100'. ALWAYS remove the leading '2' or '?' if it appears to be a misread currency symbol.
- Example: OCR '250' -> Amount '50.00', OCR '2100' -> Amount '100.00'.
- For amount, use numeric values ONLY (e.g., 100.00). Do NOT include the ₹ symbol or currency codes.
- For date, normalize to 'DD MMM YYYY' format (e.g., 20 Apr 2026)
- For type, determine if money was sent (expense) or received (income)
- Return ONLY valid JSON, no markdown formatting, no explanation

JSON:"""

# Global model instance for reuse
_model = None

def _get_model():
    """Lazy initialize and return the Gemini model."""
    global _model
    if _model is None:
        settings = get_settings()
        if not settings.gemini_api_key:
            return None
        
        genai.configure(api_key=settings.gemini_api_key)
        # Using flash-latest as 2.0-flash is reported as no longer available in 2026
        _model = genai.GenerativeModel("gemini-flash-latest")
    return _model


def _parse_gemini_response(response_text: str) -> Optional[dict]:
    """Parse Gemini response text into a dictionary."""
    if not response_text:
        return None
        
    try:
        # Try direct JSON parse
        return json.loads(response_text.strip())
    except json.JSONDecodeError:
        pass

    # Try extracting JSON from markdown code blocks
    import re
    json_match = re.search(r'```(?:json)?\s*\n?(.*?)\n?```', response_text, re.DOTALL)
    if json_match:
        try:
            return json.loads(json_match.group(1).strip())
        except json.JSONDecodeError:
            pass

    # Try finding JSON object pattern
    json_match = re.search(r'\{[^{}]*\}', response_text, re.DOTALL)
    if json_match:
        try:
            return json.loads(json_match.group(0))
        except json.JSONDecodeError:
            pass

    return None


async def parse_with_llm(ocr_text: str) -> Tuple[Optional[TransactionData], float]:
    """
    Parse OCR text using Google Gemini as a fallback.
    
    Args:
        ocr_text: Raw text from OCR extraction
        
    Returns:
        Tuple of (TransactionData or None, confidence_score)
    """
    model = _get_model()
    if not model:
        logger.warning("Gemini model not initialized (check API key)")
        return None, 0.0

    try:
        prompt = EXTRACTION_PROMPT.format(ocr_text=ocr_text)
        
        # Use async method to avoid blocking the event loop
        response = await model.generate_content_async(prompt)

        # Handle safety filter blocks or empty responses
        if not response:
            logger.warning("Gemini returned null response")
            return None, 0.0
            
        try:
            response_text = response.text
        except ValueError:
            # This happens if response was blocked by safety filters
            logger.warning(f"Gemini response was blocked or has no text: {response.candidates}")
            return None, 0.0

        if not response_text:
            logger.warning("Gemini returned empty text response")
            return None, 0.0

        logger.info(f"Gemini response: {response_text[:200]}...")

        # Parse the response
        parsed = _parse_gemini_response(response_text)
        if not parsed:
            logger.warning("Failed to parse Gemini response as JSON")
            return None, 0.0

        # Build TransactionData from parsed response
        transaction = TransactionData(
            date=parsed.get("date", ""),
            amount=parsed.get("amount", ""),
            recipient=parsed.get("recipient", ""),
            upi_id=parsed.get("upi_id"),
            type=parsed.get("type", "expense"),
            confidence=0.85,  # Base confidence for LLM
            raw_text=ocr_text,
        )

        # Calculate actual confidence based on found fields
        confidence = 0.0
        if transaction.amount:
            confidence += 0.35
        if transaction.recipient:
            confidence += 0.30
        if transaction.date:
            confidence += 0.25
        if transaction.upi_id:
            confidence += 0.10

        # LLM results get a slight confidence boost for better contextual understanding
        confidence = min(confidence * 1.1, 1.0)
        transaction.confidence = confidence

        logger.info(f"LLM parsing successful with confidence {confidence:.2f}")
        return transaction, confidence

    except Exception as e:
        logger.error(f"LLM parsing failed: {e}", exc_info=True)
        return None, 0.0


async def analyze_spending(category_totals: dict[str, float], total_spending: float) -> str:
    """
    Generate AI spending insights based on category totals.
    """
    model = _get_model()
    if not model:
        return "AI analysis unavailable."

    prompt = f"""
    You are a friendly financial coach. Analyze the following spending data and give 3 short, actionable insights or tips.
    Keep it encouraging and brief (max 3 sentences per point).

    Spending Data:
    - Total Spending: ₹{total_spending:.2f}
    - Breakdown by Category: {json.dumps(category_totals)}

    Format your response as a single concise paragraph or 3 bullet points.
    Focus on where the most money is going and give practical advice.
    """

    try:
        response = await model.generate_content_async(prompt)
        return response.text.strip()
    except Exception as e:
        logger.error(f"AI Analysis failed: {e}")
        return "Could not generate spending insights at this time."

