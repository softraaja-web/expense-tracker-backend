
import os
import google.generativeai as genai
from dotenv import load_dotenv

load_dotenv()
api_key = os.getenv("GEMINI_API_KEY")

if not api_key:
    print("No API key found")
    exit(1)

genai.configure(api_key=api_key)
model = genai.GenerativeModel("gemini-flash-latest")

try:
    response = model.generate_content("Say hello")
    print(f"Response: {response.text}")
except Exception as e:
    print(f"Error: {e}")
