import pandas as pd
from datetime import datetime
from supabase import create_client, Client
from dotenv import load_dotenv
import os

load_dotenv()
supabase: Client = create_client(os.getenv("SUPABASE_URL"), os.getenv("SUPABASE_KEY"))

df = pd.read_csv("data/ratings.csv")

# Clean and convert
df["visited"] = df["visited"].str.upper() == "YES"
df["visit_date"] = pd.to_datetime(df["visit_date"], format="%m/%d/%Y")

for _, row in df.iterrows():
    supabase.table("ratings").insert({
        "fountain_id": row["id"],
        "ig_post_url": row["ig_post_url"],
        "rating": row["rating"],
        "flow": row["flow"],
        "temp": row["temp"],
        "drainage": row["drainage"],
        "caption": row["caption"],
        "visited": row["visited"],
        "visit_date": row["visit_date"].date().isoformat()
    }).execute()
