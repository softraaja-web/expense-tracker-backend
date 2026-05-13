"""
Pydantic models for transaction data.
"""

from pydantic import BaseModel, Field
from typing import Optional


class TransactionData(BaseModel):
    """Represents a parsed transaction from a GPay screenshot."""
    id: Optional[str] = Field(default=None, description="Unique transaction ID")
    date: str = Field(default="", description="Transaction date")
    amount: str = Field(default="", description="Transaction amount in ₹")
    recipient: str = Field(default="", description="Recipient name")
    upi_id: Optional[str] = Field(default=None, description="UPI ID if available")
    type: str = Field(default="expense", description="Transaction type: expense / income")
    tag: str = Field(default="Others", description="Category tag")
    confidence: float = Field(default=1.0, description="Parsing confidence 0-1")
    source: str = Field(default="screenshot", description="Source of entry: screenshot, text, manual")
    raw_text: Optional[str] = Field(default=None, description="Original OCR text or pasted text")


class TransactionSaveRequest(BaseModel):
    """Request body for saving a transaction to Supabase."""
    user_id: str = Field(default="", description="User ID from Firebase")
    date: str
    amount: str
    recipient: str
    upi_id: Optional[str] = None
    type: str = "expense"
    tag: str = "Others"
    source: str = "screenshot"


class TransactionResponse(BaseModel):
    """API response after processing an image."""
    success: bool
    data: Optional[TransactionData] = None
    message: str = ""
    needs_review: bool = False


class DailyTotalResponse(BaseModel):
    """Response for daily total endpoint."""
    date: str
    total_expense: float = 0.0
    total_income: float = 0.0
    net_balance: float = 0.0
    transaction_count: int = 0


class HistoryResponse(BaseModel):
    """Response for history endpoint."""
    success: bool
    transactions: list[dict] = []
    message: str = ""


class AnalysisRequest(BaseModel):
    """Request body for AI spending analysis."""
    category_totals: dict[str, float]
    total_spending: float


class AnalysisResponse(BaseModel):
    """Response from AI spending analysis."""
    success: bool
    insight: str
    message: str = ""


class PlanRequest(BaseModel):
    """Request body for subscription plan upgrade."""
    plan_id: str = "plus"
