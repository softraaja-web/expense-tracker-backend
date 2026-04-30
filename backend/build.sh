#!/usr/bin/env bash
# Build script for Render deployment

set -o errexit  # Exit on error

# Install Tesseract OCR (system dependency for image text extraction)
apt-get update && apt-get install -y --no-install-recommends tesseract-ocr tesseract-ocr-eng

# Install Python dependencies
pip install --upgrade pip
pip install -r requirements.txt
