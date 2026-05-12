
import os
import sys
import io
from PIL import Image

# Add the backend/app directory to path so we can import app modules
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.ocr.extractor import extract_text
from app.parser.regex_parser import parse_transaction
from app.parser.llm_parser import parse_with_llm
import asyncio

async def test_ocr_and_parser(image_path):
    print(f"Testing with image: {image_path}")
    
    if not os.path.exists(image_path):
        print(f"Error: Image not found at {image_path}")
        return

    with open(image_path, "rb") as f:
        image_bytes = f.read()

    print(f"Image size: {len(image_bytes)} bytes")

    try:
        # Step 1: OCR
        print("\n--- Running OCR ---")
        ocr_text = extract_text(image_bytes)
        print(f"Extracted Text:\n{ocr_text}")

        # Step 2: Regex Parser
        print("\n--- Running Regex Parser ---")
        transaction, confidence = parse_transaction(ocr_text)
        if transaction:
            print(f"Regex Result: {transaction.dict()}")
            print(f"Confidence: {confidence}")
        else:
            print("Regex Parser failed to extract data.")

        # Step 3: LLM Parser (if needed or for comparison)
        print("\n--- Running LLM Parser ---")
        llm_result, llm_confidence = await parse_with_llm(ocr_text)
        if llm_result:
            print(f"LLM Result: {llm_result.dict()}")
            print(f"Confidence: {llm_confidence}")
        else:
            print("LLM Parser failed or not configured.")

    except Exception as e:
        print(f"Error during processing: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    image_path = r"C:\Users\raaja\.gemini\antigravity\brain\83af3b1b-f6d6-44bd-ac3b-b72bdb748cb7\fake_gpay_screenshot_1778559973852.png"
    asyncio.run(test_ocr_and_parser(image_path))
