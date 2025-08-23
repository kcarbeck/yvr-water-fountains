from supabase import create_client
from dotenv import load_dotenv
import os

load_dotenv()

url = os.getenv("SUPABASE_URL")
key = os.getenv("SUPABASE_KEY")

print("Using URL:", url)
print("Using Key (first few chars):", key[:6])

supabase = create_client(url, key)

# test a basic call
response = supabase.table("fountains").select("*").limit(1).execute()
print("Success:", response)
