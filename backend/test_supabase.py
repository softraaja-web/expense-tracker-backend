
import os
import socket
from dotenv import load_dotenv
import httpx

load_dotenv()

url = os.getenv("SUPABASE_URL")
key = os.getenv("SUPABASE_KEY")

print(f"Testing connection to: {url}")

hostname = url.replace("https://", "").replace("http://", "").split("/")[0]
print(f"Hostname: {hostname}")

try:
    ip = socket.gethostbyname(hostname)
    print(f"IP address: {ip}")
except Exception as e:
    print(f"DNS Resolution failed: {e}")

try:
    with httpx.Client() as client:
        response = client.get(f"{url}/rest/v1/", headers={"apikey": key, "Authorization": f"Bearer {key}"})
        print(f"HTTP Status: {response.status_code}")
        print(f"Response: {response.text[:100]}...")
except Exception as e:
    print(f"HTTP Request failed: {e}")
