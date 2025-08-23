#!/usr/bin/env python3
"""
Debug script to understand why we have 1000 fountains instead of ~427
"""

import os
from supabase import create_client, Client
from dotenv import load_dotenv
import pandas as pd

load_dotenv()

def debug_fountain_data():
    supabase: Client = create_client(
        os.getenv("SUPABASE_URL"), 
        os.getenv("SUPABASE_KEY")
    )
    
    print("🔍 Debugging fountain data...")
    print("=" * 60)
    
    # Get all fountains with source info
    fountains = supabase.table("fountains").select("*, cities(name), source_datasets(dataset_name)").execute()
    
    print(f"Total fountains in database: {len(fountains.data)}")
    print()
    
    # Group by city and source
    city_source_counts = {}
    duplicate_mapids = {}
    
    for fountain in fountains.data:
        city_name = fountain.get('cities', {}).get('name', 'Unknown') if fountain.get('cities') else 'Unknown'
        source_name = fountain.get('source_datasets', {}).get('dataset_name', 'Unknown') if fountain.get('source_datasets') else 'Unknown'
        
        key = f"{city_name} - {source_name}"
        city_source_counts[key] = city_source_counts.get(key, 0) + 1
        
        # Check for duplicate mapids
        mapid = fountain.get('original_mapid')
        if mapid:
            if mapid in duplicate_mapids:
                duplicate_mapids[mapid].append(fountain.get('id'))
            else:
                duplicate_mapids[mapid] = [fountain.get('id')]
    
    print("📊 Fountains by city and source:")
    for key, count in city_source_counts.items():
        print(f"   {key}: {count}")
    
    print()
    
    # Check for duplicates
    duplicates = {k: v for k, v in duplicate_mapids.items() if len(v) > 1}
    if duplicates:
        print(f"⚠️  Found {len(duplicates)} duplicate mapids:")
        for mapid, fountain_ids in list(duplicates.items())[:10]:  # Show first 10
            print(f"   {mapid}: {len(fountain_ids)} copies")
        if len(duplicates) > 10:
            print(f"   ... and {len(duplicates) - 10} more")
    else:
        print("✅ No duplicate mapids found")
    
    print()
    
    # Check for fountains without mapids
    no_mapid = [f for f in fountains.data if not f.get('original_mapid')]
    print(f"📝 Fountains without original_mapid: {len(no_mapid)}")
    
    # Show sample of fountains without mapids
    if no_mapid:
        print("   Sample fountains without mapid:")
        for fountain in no_mapid[:5]:
            print(f"   - {fountain.get('name', 'Unnamed')} (ID: {fountain.get('id')})")
    
    print()
    
    # Check if ETL ran multiple times
    print("🔄 Checking for possible duplicate runs...")
    
    # Look at creation timestamps
    from collections import Counter
    creation_dates = []
    for fountain in fountains.data:
        created_at = fountain.get('created_at', '')
        if created_at:
            # Extract just the date part
            date_part = created_at.split('T')[0]
            creation_dates.append(date_part)
    
    date_counts = Counter(creation_dates)
    print("📅 Fountains by creation date:")
    for date, count in sorted(date_counts.items()):
        print(f"   {date}: {count} fountains")
    
    return len(fountains.data), duplicates

def check_raw_data():
    """Double-check the raw CSV data"""
    print("\n" + "=" * 60)
    print("🔍 Checking raw CSV data...")
    
    vancouver_df = pd.read_csv("data/raw/vancouver_fountains_raw.csv")
    burnaby_df = pd.read_csv("data/raw/burnaby_fountains_raw.csv")
    
    print(f"Vancouver CSV: {len(vancouver_df)} rows")
    print(f"Burnaby CSV: {len(burnaby_df)} rows")
    print(f"Total expected: {len(vancouver_df) + len(burnaby_df)}")
    
    # Check for duplicates in raw data
    vancouver_dupes = vancouver_df['MAPID'].duplicated().sum() if 'MAPID' in vancouver_df.columns else 0
    burnaby_dupes = burnaby_df['COMPKEY'].duplicated().sum() if 'COMPKEY' in burnaby_df.columns else 0
    
    print(f"Vancouver duplicates in raw: {vancouver_dupes}")
    print(f"Burnaby duplicates in raw: {burnaby_dupes}")

if __name__ == "__main__":
    total_fountains, duplicates = debug_fountain_data()
    check_raw_data()
    
    print("\n" + "=" * 60)
    print("🔧 RECOMMENDATIONS:")
    
    if total_fountains > 450:  # Expected ~427
        print("❌ Too many fountains in database!")
        print("   Likely causes:")
        print("   1. ETL pipeline ran multiple times without clearing data")
        print("   2. Duplicate data in source files")
        print("   3. Issue with data cleaning logic")
        print()
        print("🛠️  FIXES:")
        print("   1. Clear and reload: python scripts/etl_pipeline.py")
        print("   2. Check logs for ETL errors")
        print("   3. Verify source data integrity")
    else:
        print("✅ Fountain count looks reasonable")
    
    if duplicates:
        print(f"\n⚠️  {len(duplicates)} duplicate mapids need cleanup")
