#!/usr/bin/env python3
"""
Check current database schema and table structure
"""

import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

def check_schema():
    """Check what tables and columns exist in the database"""
    supabase: Client = create_client(
        os.getenv("SUPABASE_URL"), 
        os.getenv("SUPABASE_KEY")
    )
    
    print("🔍 Checking current database schema...")
    print("=" * 60)
    
    # List all tables
    try:
        # This is a PostgreSQL-specific query to get table names
        result = supabase.rpc('get_tables').execute()
        print("Tables found:", result.data)
    except:
        print("Could not get table list via RPC, trying direct queries...")
    
    # Try to query common table names
    common_tables = [
        "fountains", "ratings", "cities", "source_datasets", 
        "instagram_posts", "fountain_rating_summary", "fountain_reviews",
        "fountain_details"
    ]
    
    for table_name in common_tables:
        try:
            # Try to get one row to see if table exists
            result = supabase.table(table_name).select("*").limit(1).execute()
            print(f"✅ Table '{table_name}' exists with {len(result.data)} rows")
            
            # If table exists, show its structure by getting column info
            if result.data:
                sample_row = result.data[0]
                print(f"   Columns: {list(sample_row.keys())}")
                
        except Exception as e:
            print(f"❌ Table '{table_name}' not found or error: {e}")
    
    print("\n" + "=" * 60)
    print("🔍 Checking specific table structures...")
    
    # Check fountains table structure
    try:
        fountains = supabase.table("fountains").select("*").limit(1).execute()
        if fountains.data:
            print("\n📋 Fountains table structure:")
            for col, value in fountains.data[0].items():
                print(f"   {col}: {type(value).__name__} = {value}")
    except Exception as e:
        print(f"❌ Error checking fountains table: {e}")
    
    # Check ratings table structure
    try:
        ratings = supabase.table("ratings").select("*").limit(1).execute()
        if ratings.data:
            print("\n📋 Ratings table structure:")
            for col, value in ratings.data[0].items():
                print(f"   {col}: {type(value).__name__} = {value}")
    except Exception as e:
        print(f"❌ Error checking ratings table: {e}")
    
    # Check if any views exist
    try:
        # Try to query fountain_details view
        details = supabase.table("fountain_details").select("*").limit(1).execute()
        if details.data:
            print("\n📋 Fountain_details view structure:")
            for col, value in details.data[0].items():
                print(f"   {col}: {type(value).__name__} = {value}")
    except Exception as e:
        print(f"❌ Fountain_details view not found: {e}")

if __name__ == "__main__":
    check_schema()
