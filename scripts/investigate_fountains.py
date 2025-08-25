#!/usr/bin/env python3
"""
Investigate what's actually in the fountains table
Find out why we have 580 fountains instead of 429
"""

import os
from supabase import create_client, Client
from dotenv import load_dotenv
import logging
from collections import defaultdict

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

def investigate_fountain_excess():
    """Investigate why we have too many fountains"""
    supabase: Client = create_client(
        os.getenv("SUPABASE_URL"), 
        os.getenv("SUPABASE_KEY")
    )
    
    logger.info("🔍 Investigating fountain database excess...")
    
    # Get ALL fountains with basic info
    fountains = supabase.table("fountains").select("id, original_mapid, name, city_id, created_at, updated_at").execute()
    total = len(fountains.data)
    
    logger.info(f"📊 Total fountains in database: {total}")
    logger.info(f"📊 Expected fountains: 429 (278 Vancouver + 151 Burnaby)")
    logger.info(f"📊 Excess fountains: {total - 429}")
    
    # Analyze by original_mapid patterns
    patterns = defaultdict(list)
    for fountain in fountains.data:
        mapid = fountain['original_mapid']
        if mapid.startswith('DFPB'):
            patterns['Vancouver_DFPB'].append(fountain)
        elif mapid.isdigit():
            patterns['Burnaby_numeric'].append(fountain)
        elif mapid.startswith('BBY'):
            patterns['Burnaby_BBY_format'].append(fountain)
        else:
            patterns[f'Other_{mapid[:10]}'].append(fountain)
    
    logger.info("\n📊 Breakdown by ID pattern:")
    for pattern, fountain_list in patterns.items():
        logger.info(f"   - {pattern}: {len(fountain_list)} fountains")
        if len(fountain_list) <= 5:  # Show details for small groups
            for f in fountain_list[:3]:
                logger.info(f"     * {f['original_mapid']}: {f.get('name', 'No name')[:40]}...")
    
    # Check for exact duplicates by original_mapid
    mapid_counts = defaultdict(list)
    for fountain in fountains.data:
        mapid_counts[fountain['original_mapid']].append(fountain)
    
    duplicates = {mapid: fountains for mapid, fountains in mapid_counts.items() if len(fountains) > 1}
    
    logger.info(f"\n🔍 Exact duplicates by original_mapid: {len(duplicates)}")
    for mapid, fountain_list in duplicates.items():
        logger.info(f"   - {mapid}: {len(fountain_list)} copies")
        for f in fountain_list:
            logger.info(f"     * ID: {f['id']}, Created: {f['created_at']}")
    
    # Check city distribution
    cities = supabase.table("cities").select("*").execute()
    city_lookup = {c['id']: c['name'] for c in cities.data}
    
    city_counts = defaultdict(int)
    for fountain in fountains.data:
        city_name = city_lookup.get(fountain['city_id'], f"Unknown_{fountain['city_id']}")
        city_counts[city_name] += 1
    
    logger.info(f"\n🏙️ Fountains by city:")
    for city, count in city_counts.items():
        logger.info(f"   - {city}: {count} fountains")
    
    # Look for fountains with missing/empty original_mapid
    missing_mapid = [f for f in fountains.data if not f.get('original_mapid') or f['original_mapid'].strip() == '']
    if missing_mapid:
        logger.info(f"\n⚠️ Fountains with missing/empty original_mapid: {len(missing_mapid)}")
        for f in missing_mapid[:5]:
            logger.info(f"   - ID: {f['id']}, Name: {f.get('name', 'No name')}")
    
    # Check for fountains with weird characters or formats
    weird_mapids = []
    for fountain in fountains.data:
        mapid = fountain['original_mapid']
        if mapid and (len(mapid) > 20 or any(c in mapid for c in ['\n', '\t', '  ', '"', "'"])):
            weird_mapids.append(fountain)
    
    if weird_mapids:
        logger.info(f"\n⚠️ Fountains with suspicious original_mapid: {len(weird_mapids)}")
        for f in weird_mapids[:5]:
            logger.info(f"   - '{f['original_mapid']}': {f.get('name', 'No name')[:30]}")
    
    # Sample some Vancouver fountains to see what they look like
    vancouver_samples = [f for f in fountains.data if f['original_mapid'].startswith('DFPB')][:5]
    logger.info(f"\n📍 Sample Vancouver fountains:")
    for f in vancouver_samples:
        logger.info(f"   - {f['original_mapid']}: {f.get('name', 'No name')[:50]}")
    
    # Sample some Burnaby fountains
    burnaby_samples = [f for f in fountains.data if f['original_mapid'].isdigit()][:5]
    logger.info(f"\n📍 Sample Burnaby fountains:")
    for f in burnaby_samples:
        logger.info(f"   - {f['original_mapid']}: {f.get('name', 'No name')[:50]}")

def count_csv_sources():
    """Count what we expect from CSV files"""
    import pandas as pd
    from pathlib import Path
    
    project_root = Path(__file__).parent.parent
    
    logger.info("\n📄 Checking source CSV files:")
    
    # Vancouver CSV
    vancouver_csv = project_root / "data" / "raw" / "vancouver_fountains_raw.csv"
    if vancouver_csv.exists():
        vancouver_df = pd.read_csv(vancouver_csv)
        logger.info(f"   - Vancouver CSV: {len(vancouver_df)} rows")
        logger.info(f"     Sample MAPIDs: {vancouver_df['MAPID'].head(3).tolist()}")
    
    # Burnaby CSV  
    burnaby_csv = project_root / "data" / "raw" / "burnaby_fountains_raw.csv"
    if burnaby_csv.exists():
        burnaby_df = pd.read_csv(burnaby_csv)
        logger.info(f"   - Burnaby CSV: {len(burnaby_df)} rows")
        logger.info(f"     Sample COMPKEYs: {burnaby_df['COMPKEY'].head(3).tolist()}")
    
    expected_total = len(vancouver_df) + len(burnaby_df)
    logger.info(f"   - Expected total from CSVs: {expected_total}")

if __name__ == "__main__":
    investigate_fountain_excess()
    count_csv_sources()
