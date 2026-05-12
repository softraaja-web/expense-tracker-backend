"""
GPay Transaction Extractor - FastAPI Backend
Main application entry point with all API endpoints.
"""

import logging
from datetime import datetime, date, timezone, timedelta
from fastapi import FastAPI, File, UploadFile, HTTPException, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse


from app.config import get_settings

from app.models.transaction import (
    TransactionData,
    TransactionSaveRequest,
    TransactionResponse,
    DailyTotalResponse,
    HistoryResponse,
    AnalysisRequest,
    AnalysisResponse,
)
from app.ocr.extractor import extract_text
from app.parser.regex_parser import parse_transaction
from app.parser.llm_parser import parse_with_llm, analyze_spending
from app.tagger.categorizer import categorize_transaction, get_available_tags
import hmac
import hashlib
import razorpay
from app.auth.firebase_auth import get_current_user
from app.db.supabase_client import (
    insert_transaction, 
    get_user_transactions, 
    get_user_daily_total,
    update_user_credits,
    update_user_plan
)

# ─── Logging Setup ──────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

# ─── App Initialization ─────────────────────────────────────────────
settings = get_settings()

app = FastAPI(
    title=settings.app_name,
    description="Extract transaction details from Google Pay screenshots and log them to Google Sheets",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# Initialize Razorpay Client
razorpay_client = razorpay.Client(
    auth=(settings.razorpay_key, settings.razorpay_secret)
) if settings.razorpay_key and settings.razorpay_secret else None

# ─── CORS Middleware ─────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.get_cors_origins(),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─── Health Check ────────────────────────────────────────────────────
@app.get("/")
async def root():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "app": settings.app_name,
        "version": "1.0.0",
    }


@app.get("/health")
async def health_check():
    """Detailed health check."""
    return {
        "status": "healthy",
        "supabase_configured": bool(settings.supabase_url),
        "firebase_configured": bool(settings.firebase_credentials_json),
        "gemini_configured": bool(settings.gemini_api_key),
        "tesseract_configured": bool(settings.tesseract_cmd),
    }


# ─── Upload & Extract ───────────────────────────────────────────────
@app.post("/upload", response_model=TransactionResponse)
async def upload_image(file: UploadFile = File(...), current_user: dict = Depends(get_current_user)):
    """
    Upload a Google Pay screenshot and extract transaction details.
    
    Flow:
    1. Check user credits/plan
    2. Read image bytes
    3. Run Tesseract OCR to extract text
    4. Parse with regex patterns
    5. If low confidence, fallback to Gemini LLM
    6. Auto-tag the transaction
    7. Decrement credit (if free)
    8. Return extracted data
    """
    # Step 0: Check credits/plan
    profile = current_user.get("profile") or {}
    plan = profile.get("plan", "free")
    credits = profile.get("credits", 0)

    if plan == "free" and credits <= 0:
        raise HTTPException(
            status_code=403,
            detail="Credit limit reached. Please upgrade to Pro for unlimited uploads."
        )

    # Step 0.1: Validate file type
    is_image = False
    if file.content_type and file.content_type.startswith("image/"):
        is_image = True
    elif file.filename:
        ext = file.filename.split(".")[-1].lower()
        if ext in ["png", "jpg", "jpeg", "webp"]:
            is_image = True

    if not is_image:
        logger.warning(f"Rejecting file with content_type={file.content_type}, filename={file.filename}")
        raise HTTPException(
            status_code=400,
            detail="File must be an image (PNG, JPG, JPEG, WEBP)"
        )

    try:
        # Step 1: Read image bytes
        image_bytes = await file.read()
        logger.info(f"Received image: {file.filename}, size: {len(image_bytes)} bytes")

        # Validate size (Max 10MB)
        if len(image_bytes) > 10 * 1024 * 1024:
            raise HTTPException(status_code=400, detail="File too large (max 10MB)")

        if len(image_bytes) == 0:
            logger.warning("Rejecting empty file upload")
            raise HTTPException(status_code=400, detail="Empty file uploaded")

        # Step 2: OCR extraction
        try:
            ocr_text = extract_text(image_bytes)
        except ValueError as e:
            return TransactionResponse(
                success=False,
                message=f"OCR failed: {str(e)}",
                needs_review=True,
                data=TransactionData(raw_text="OCR extraction failed"),
            )

        # Step 3: Regex parsing
        transaction, confidence = parse_transaction(ocr_text)

        # Step 4: LLM fallback if regex confidence is low or critical fields missing
        if confidence < 0.7 or not transaction or not transaction.amount:
            logger.info(f"Low regex confidence ({confidence:.2f}) or missing amount, trying LLM fallback...")
            llm_result, llm_confidence = await parse_with_llm(ocr_text)

            if llm_result and llm_confidence > confidence:
                logger.info(f"LLM result better: {llm_confidence:.2f} vs {confidence:.2f}")
                transaction = llm_result
                confidence = llm_confidence

        # Step 5: If still no result, return empty editable fields
        if not transaction:
            return TransactionResponse(
                success=False,
                message="Could not extract transaction details. Please fill in manually.",
                needs_review=True,
                data=TransactionData(raw_text=ocr_text),
            )

        # Step 6: Auto-tag
        tag = categorize_transaction(transaction.recipient, transaction.upi_id)
        transaction.tag = tag
        transaction.confidence = confidence

        # Determine if user should review
        needs_review = confidence < 0.8

        # Step 7: Decrement credit for free plan
        if plan == "free":
            update_user_credits(current_user.get("uid"), -1)

        return TransactionResponse(
            success=True,
            data=transaction,
            message="Transaction extracted successfully" if not needs_review
                    else "Extracted with low confidence. Please review.",
            needs_review=needs_review,
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error during upload processing: {e}", exc_info=True)
        raise HTTPException(
            status_code=500, 
            detail=f"An internal error occurred while processing the image. Please try again or fill in manually."
        )


# ─── Parse Text ──────────────────────────────────────────────────
@app.post("/parse-text", response_model=TransactionResponse)
async def parse_text_endpoint(request: Request, current_user: dict = Depends(get_current_user)):
    """
    Parse pasted transaction text.
    """
    try:
        body = await request.json()
        raw_text = body.get("text", "")
        
        if not raw_text:
            raise HTTPException(status_code=400, detail="No text provided")

        # Step 1: Regex parsing
        transaction, confidence = parse_transaction(raw_text)

        # Step 2: LLM fallback if regex confidence is low
        if confidence < 0.7 or not transaction or not transaction.amount:
            logger.info(f"Low regex confidence ({confidence:.2f}) for text, trying LLM fallback...")
            llm_result, llm_confidence = await parse_with_llm(raw_text)

            if llm_result and llm_confidence > confidence:
                transaction = llm_result
                confidence = llm_confidence

        # Step 3: If still no result, return empty editable fields
        if not transaction:
            return TransactionResponse(
                success=False,
                message="Could not extract details from text. Please fill in manually.",
                needs_review=True,
                data=TransactionData(raw_text=raw_text, source="text"),
            )

        # Step 4: Auto-tag
        tag = categorize_transaction(transaction.recipient, transaction.upi_id)
        transaction.tag = tag
        transaction.confidence = confidence
        transaction.source = "text"
        transaction.raw_text = raw_text

        return TransactionResponse(
            success=True,
            data=transaction,
            message="Text parsed successfully",
            needs_review=confidence < 0.8,
        )
    except Exception as e:
        logger.error(f"Text parsing failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ─── Save Transaction ───────────────────────────────────────────────
@app.post("/save")
async def save_transaction(request: TransactionSaveRequest, current_user: dict = Depends(get_current_user)):
    """
    Save a confirmed transaction to Supabase.
    Called after user reviews and optionally edits the extracted data.
    """
    try:
        user_id = current_user.get("uid")
        if not user_id:
            raise HTTPException(status_code=401, detail="User ID not found in token")

        success, message = insert_transaction(
            user_id=user_id,
            date_str=request.date,
            amount=request.amount,
            recipient=request.recipient,
            upi_id=request.upi_id or "",
            tx_type=request.type,
            tag=request.tag,
            source=request.source,
        )

        if success:
            return {
                "success": True,
                "message": message,
            }
        else:
            raise HTTPException(
                status_code=500,
                detail=message,
            )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Save failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Save failed: {str(e)}")


# ─── History ─────────────────────────────────────────────────────────
@app.get("/history", response_model=HistoryResponse)
async def get_history(count: int = 20, type: str | None = None, current_user: dict = Depends(get_current_user)):
    """Fetch recent transactions from Supabase for the current user."""
    try:
        user_id = current_user.get("uid")
        transactions = get_user_transactions(user_id, count, tx_type=type)
        return HistoryResponse(
            success=True,
            transactions=transactions,
            message=f"Fetched {len(transactions)} transactions",
        )
    except Exception as e:
        logger.error(f"History fetch failed: {e}")
        return HistoryResponse(
            success=False,
            transactions=[],
            message=f"Failed to fetch history: {str(e)}",
        )


# ─── Daily Total ────────────────────────────────────────────────────
@app.get("/daily-total", response_model=DailyTotalResponse)
async def daily_total(target_date: str | None = None, current_user: dict = Depends(get_current_user)):
    """
    Get total spending for a specific date for the current user.
    Defaults to today if no date provided.
    """
    try:
        if not target_date:
            target_date = date.today().strftime("%d %b %Y")

        user_id = current_user.get("uid")
        summary = get_user_daily_total(user_id, target_date)

        return DailyTotalResponse(
            date=target_date,
            total_expense=summary["total_expense"],
            total_income=summary["total_income"],
            net_balance=summary["net_balance"],
            transaction_count=summary["transaction_count"],
        )
    except Exception as e:
        logger.error(f"Daily total failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ─── Tags ────────────────────────────────────────────────────────────
@app.get("/tags")
async def list_tags():
    """Get all available category tags."""
    return {"tags": get_available_tags()}


# ─── Analysis ────────────────────────────────────────────────────────
@app.post("/analyze-spending", response_model=AnalysisResponse)
async def analyze_spending_endpoint(request: AnalysisRequest, current_user: dict = Depends(get_current_user)):
    """Generate AI spending insights."""
    try:
        insight = await analyze_spending(request.category_totals, request.total_spending)
        return AnalysisResponse(
            success=True,
            insight=insight,
        )
    except Exception as e:
        logger.error(f"Analysis endpoint failed: {e}")
        return AnalysisResponse(
            success=False,
            insight="Could not generate analysis.",
            message=str(e),
        )



# ─── User Profile ───────────────────────────────────────────────────
@app.get("/profile")
async def get_profile(current_user: dict = Depends(get_current_user)):
    """Get the current user's profile, plan, and credits."""
    return current_user.get("profile", {})


# ─── Payments (Razorpay) ───────────────────────────────────────────
@app.post("/create-order")
async def create_order(current_user: dict = Depends(get_current_user)):
    """Create a Razorpay order for Pro subscription."""
    if not razorpay_client:
        raise HTTPException(status_code=500, detail="Razorpay not configured")

    try:
        # Amount: ₹99 (9900 paise)
        amount = 9900 
        currency = "INR"
        notes = {"user_id": current_user.get("uid")}

        order = razorpay_client.order.create({
            "amount": amount,
            "currency": currency,
            "notes": notes
        })

        return order
    except Exception as e:
        logger.error(f"Razorpay order creation failed: {e}")
        raise HTTPException(status_code=500, detail=f"Order creation failed: {str(e)}")


@app.post("/verify-payment")
async def verify_payment(request: Request, current_user: dict = Depends(get_current_user)):
    """Verify Razorpay payment signature and upgrade user."""
    try:
        data = await request.json()
        payment_id = data.get("razorpay_payment_id")
        order_id = data.get("razorpay_order_id")
        signature = data.get("razorpay_signature")

        if not all([payment_id, order_id, signature]):
            raise HTTPException(status_code=400, detail="Missing payment details")

        # Verify Signature
        params_dict = {
            'razorpay_order_id': order_id,
            'razorpay_payment_id': payment_id,
            'razorpay_signature': signature
        }
        
        # Mock verification for testing/development
        is_mock = payment_id.startswith("mock_")
        
        if not is_mock:
            try:
                if not razorpay_client:
                    raise HTTPException(status_code=500, detail="Razorpay not configured")
                razorpay_client.utility.verify_payment_signature(params_dict)
            except Exception:
                logger.warning(f"Invalid payment signature for user {current_user.get('uid')}")
                raise HTTPException(status_code=400, detail="Invalid payment signature")
        else:
            logger.info(f"Using mock payment verification for user {current_user.get('uid')}")

        # Upgrade User
        expiry_date = (datetime.now(timezone.utc) + timedelta(days=30)).isoformat()
        
        success = update_user_plan(
            user_id=current_user.get("uid"),
            plan="pro",
            expiry_date=expiry_date,
            credits=999999 # Unlimited (large number)
        )

        if success:
            return {"success": True, "message": "Upgraded to Pro plan successfully"}
        else:
            raise HTTPException(status_code=500, detail="Payment verified but failed to update profile")

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Payment verification failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ─── Error Handlers ─────────────────────────────────────────────────
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Global exception handler for unhandled errors."""
    logger.error(f"Unhandled error: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "An unexpected error occurred. Please try again."},
    )
