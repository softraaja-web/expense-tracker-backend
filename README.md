# GPay Home Account – Transaction Extractor & Logger

Extract transaction details from Google Pay screenshots using OCR + AI, and log them into Google Sheets.

## 🏗️ Architecture

```
┌─────────────────┐     ┌─────────────────────────────────────┐     ┌──────────────┐
│   Flutter App   │────▶│         FastAPI Backend              │────▶│ Google Sheets│
│  (Android/Web)  │◀────│  OCR → Regex → LLM → Auto-Tag       │◀────│              │
└─────────────────┘     └─────────────────────────────────────┘     └──────────────┘
```

## 📁 Project Structure

```
GpayHomeAccount/
├── backend/                    # FastAPI Python backend
│   ├── app/
│   │   ├── main.py            # API endpoints
│   │   ├── config.py          # Environment config
│   │   ├── ocr/extractor.py   # Tesseract OCR
│   │   ├── parser/
│   │   │   ├── regex_parser.py  # Regex parsing
│   │   │   └── llm_parser.py   # Gemini fallback
│   │   ├── sheets/client.py   # Google Sheets integration
│   │   ├── tagger/categorizer.py  # Auto-categorization
│   │   └── models/transaction.py  # Data models
│   ├── Dockerfile
│   ├── render.yaml
│   └── requirements.txt
├── frontend/
│   └── gpay_extractor/        # Flutter app
│       └── lib/
│           ├── main.dart
│           ├── screens/       # Home, Result, History
│           ├── widgets/       # TransactionCard, TagSelector, DailySummary
│           ├── services/      # API communication
│           └── models/        # Data models
└── docs/
    └── google_sheets_setup.md
```

## 🚀 Quick Start

### Prerequisites
- Python 3.11+
- Flutter 3.x
- Tesseract OCR installed
- Google Cloud project with Sheets API enabled

### Backend Setup

```bash
cd backend

# Create virtual environment
python -m venv venv
venv\Scripts\activate  # Windows
# source venv/bin/activate  # macOS/Linux

# Install dependencies
pip install -r requirements.txt

# Configure environment
copy .env.example .env
# Edit .env with your credentials

# Run development server
uvicorn app.main:app --reload --port 8000
```

### Frontend Setup

```bash
cd frontend/gpay_extractor

# Install dependencies
flutter pub get

# Run on Android emulator
flutter run

# Run on Chrome
flutter run -d chrome
```

### Google Sheets Setup

See [docs/google_sheets_setup.md](docs/google_sheets_setup.md) for detailed instructions.

## 📡 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Health check |
| GET | `/health` | Detailed health status |
| POST | `/upload` | Upload screenshot for OCR extraction |
| POST | `/save` | Save transaction to Google Sheets |
| GET | `/history` | Get recent transactions |
| GET | `/daily-total` | Get daily spending total |
| GET | `/tags` | Get available category tags |

## 🏷️ Auto-Tagging Categories

| Category | Examples |
|----------|---------|
| Food | Swiggy, Zomato, Restaurant, Cafe |
| Travel | Uber, Ola, Rapido, Metro, Petrol |
| Shopping | Amazon, Flipkart, Myntra, BigBasket |
| Bills | Jio, Airtel, Electricity, Rent |
| Entertainment | Netflix, Spotify, PVR |
| Health | Apollo, Pharmacy, Gym |
| Education | School, Udemy, Courses |
| Transfer | Self-transfer, Bank, NEFT |
| Others | Default category |

## 📱 Sample Test Scenarios

### Expected OCR Input (from GPay screenshot):
```
✓ Paid ₹500.00
Paid to John Doe
john.doe@upi
15 Apr 2026

UPI transaction ID
ABC123456789
```

### Expected Parsed Output:
```json
{
  "date": "15 Apr 2026",
  "amount": "₹500.00",
  "recipient": "John Doe",
  "upi_id": "john.doe@upi",
  "type": "Paid",
  "tag": "Others",
  "confidence": 1.0
}
```

### Google Sheets Row:
| Date | Amount | To | UPI ID | Type | Tag |
|------|--------|----|--------|------|-----|
| 15 Apr 2026 | ₹500.00 | John Doe | john.doe@upi | Paid | Others |

## 🚢 Deployment (Render)

1. Push to GitHub
2. Connect repo to [Render](https://render.com)
3. Create Web Service → Select Docker
4. Set environment variables in Render dashboard
5. Deploy

## 🔐 Security

- All API keys stored as environment variables
- Service account credentials never committed to code
- `.env` file is gitignored
- CORS configured for production origins

## 📄 License

MIT License
