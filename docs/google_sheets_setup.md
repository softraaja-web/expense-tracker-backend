# Google Sheets API Setup Guide

## Step-by-Step Setup

### 1. Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click **"Select a project"** → **"New Project"**
3. Name it: `GPay Transaction Extractor`
4. Click **Create**

### 2. Enable Required APIs

1. In your project, go to **APIs & Services** → **Library**
2. Search and enable:
   - **Google Sheets API**
   - **Google Drive API**

### 3. Create a Service Account

1. Go to **APIs & Services** → **Credentials**
2. Click **"+ Create Credentials"** → **"Service Account"**
3. Fill in:
   - Name: `gpay-extractor-service`
   - Description: `Service account for GPay transaction logging`
4. Click **Create and Continue**
5. Role: Select **Editor** (or `Basic > Editor`)
6. Click **Done**

### 4. Generate Service Account Key

1. Click on your newly created service account
2. Go to the **Keys** tab
3. Click **Add Key** → **Create new key**
4. Select **JSON** format
5. Click **Create** — the JSON file will be downloaded
6. **Save this file securely** — you'll need its contents

### 5. Create the Google Sheet

1. Go to [Google Sheets](https://sheets.google.com)
2. Create a new spreadsheet
3. Name it: `GPay Transactions`
4. Add these headers in Row 1:

| A | B | C | D | E | F |
|---|---|---|---|---|---|
| Date | Amount | To | UPI ID | Type | Tag |

5. Copy the **Spreadsheet ID** from the URL:
   ```
   https://docs.google.com/spreadsheets/d/{THIS_IS_YOUR_SHEET_ID}/edit
   ```

### 6. Share the Sheet with Service Account

1. Open the JSON key file you downloaded
2. Find the `client_email` field (looks like: `gpay-extractor-service@project-id.iam.gserviceaccount.com`)
3. In your Google Sheet, click **Share**
4. Paste the `client_email` address
5. Set permission to **Editor**
6. Uncheck "Notify people"
7. Click **Share**

### 7. Configure Environment Variables

#### For Local Development

Create a `.env` file in the `backend/` directory:

```env
GOOGLE_SHEETS_ID=your_spreadsheet_id_here
GOOGLE_CREDENTIALS_JSON=path/to/your/service-account-key.json
GEMINI_API_KEY=your_gemini_api_key_here
TESSERACT_CMD=C:\Program Files\Tesseract-OCR\tesseract.exe
```

**Option A:** Set `GOOGLE_CREDENTIALS_JSON` to the file path of your JSON key:
```env
GOOGLE_CREDENTIALS_JSON=C:\path\to\credentials.json
```

**Option B:** Paste the entire JSON content as a single line:
```env
GOOGLE_CREDENTIALS_JSON={"type":"service_account","project_id":"...","private_key":"..."}
```

#### For Render Deployment

In Render Dashboard → Environment Variables:
- `GOOGLE_SHEETS_ID`: Your spreadsheet ID
- `GOOGLE_CREDENTIALS_JSON`: Paste the **entire JSON content** of the key file
- `GEMINI_API_KEY`: Your Gemini API key
- `TESSERACT_CMD`: `/usr/bin/tesseract` (set automatically in Docker)

### 8. Get a Gemini API Key

1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Click **"Create API key"**
3. Select your Google Cloud project
4. Copy the API key
5. Add to your `.env` file as `GEMINI_API_KEY`

### 9. Install Tesseract OCR (Local Development)

#### Windows
1. Download from: https://github.com/UB-Mannheim/tesseract/wiki
2. Install to default path: `C:\Program Files\Tesseract-OCR\`
3. Set in `.env`: `TESSERACT_CMD=C:\Program Files\Tesseract-OCR\tesseract.exe`

#### macOS
```bash
brew install tesseract
```

#### Linux
```bash
sudo apt-get install tesseract-ocr
```

## Verification

After setup, verify by running:

```bash
cd backend
python -c "from app.sheets.client import _get_worksheet; ws = _get_worksheet(); print('Connected!' if ws else 'Failed')"
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `gspread.exceptions.SpreadsheetNotFound` | Make sure you shared the sheet with the service account email |
| `google.auth.exceptions.DefaultCredentialsError` | Check that `GOOGLE_CREDENTIALS_JSON` is correctly set |
| `PermissionError` on Sheets | Ensure the service account has Editor access |
| Empty OCR text | Check Tesseract installation and `TESSERACT_CMD` path |
