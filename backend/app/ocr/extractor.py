"""
OCR text extraction using Tesseract.
Preprocesses images for better accuracy on mobile screenshots.
"""

import io
import logging
from PIL import Image, ImageFilter, ImageEnhance
import pytesseract
from app.config import get_settings

logger = logging.getLogger(__name__)


def _configure_tesseract():
    """Set Tesseract executable path from config if provided."""
    settings = get_settings()
    if settings.tesseract_cmd:
        pytesseract.pytesseract.tesseract_cmd = settings.tesseract_cmd


def preprocess_image(image: Image.Image) -> Image.Image:
    """
    Preprocess image for better OCR accuracy.
    
    Steps:
    1. Convert to grayscale
    2. Increase contrast
    3. Increase sharpness
    4. Apply slight denoise
    5. Resize if too small
    """
    # Convert to grayscale
    gray = image.convert("L")

    # Increase contrast
    enhancer = ImageEnhance.Contrast(gray)
    gray = enhancer.enhance(2.0)

    # Increase sharpness
    enhancer = ImageEnhance.Sharpness(gray)
    gray = enhancer.enhance(2.0)

    # Resize if image is too small (improves OCR on small screenshots)
    width, height = gray.size
    if width < 800:
        scale = 800 / width
        new_size = (int(width * scale), int(height * scale))
        gray = gray.resize(new_size, Image.LANCZOS)

    # Slight denoise
    gray = gray.filter(ImageFilter.MedianFilter(size=3))

    return gray


def extract_text(image_bytes: bytes) -> str:
    """
    Extract text from image bytes using Tesseract OCR.
    
    Args:
        image_bytes: Raw bytes of the screenshot image
        
    Returns:
        Extracted text string
        
    Raises:
        ValueError: If image cannot be processed
    """
    _configure_tesseract()

    try:
        # Open image from bytes
        image = Image.open(io.BytesIO(image_bytes))
        logger.info(f"Image opened: size={image.size}, mode={image.mode}")

        # Preprocess for better OCR
        processed = preprocess_image(image)

        # Run Tesseract OCR with automatic page segmentation
        custom_config = r'--oem 3 --psm 3 -l eng'
        text = pytesseract.image_to_string(processed, config=custom_config)

        logger.info(f"OCR extracted {len(text)} characters")
        logger.info(f"OCR text preview:\n{text[:500]}...")

        if not text.strip():
            raise ValueError("OCR returned empty text. Image may be unclear.")

        return text.strip()

    except Exception as e:
        logger.error(f"OCR extraction failed: {e}")
        raise ValueError(f"Failed to extract text from image: {str(e)}")
