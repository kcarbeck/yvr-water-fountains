#!/usr/bin/env python3
"""
Cleanup duplicate fountains from database
Keeps only the most recent version of each fountain based on original_mapid
"""

import os
from supabase import create_client, Client
from dotenv import load_dotenv
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

def cleanup_duplicate_fountains():
    """Remove duplicate fountains, keeping only the most recent one"""
    supabase: Client = create_client(
        os.getenv("SUPABASE_URL"), 
        os.getenv("SUPABASE_KEY")
    )
    
    logger.info("🧹 Starting duplicate fountain cleanup...")
    
    # First, let's see what we have
    fountains = supabase.table("fountains").select("id, original_mapid, created_at, updated_at").execute()
    total_before = len(fountains.data)
    logger.info(f"📊 Total fountains before cleanup: {total_before}")
    
    # Group by original_mapid to find duplicates
    mapid_groups = {}
    for fountain in fountains.data:
        mapid = fountain['original_mapid']
        if mapid not in mapid_groups:
            mapid_groups[mapid] = []
        mapid_groups[mapid].append(fountain)
    
    # Find duplicates
    duplicates_found = 0
    to_delete = []
    
    for mapid, fountain_list in mapid_groups.items():
        if len(fountain_list) > 1:
            duplicates_found += len(fountain_list) - 1
            
            # Sort by updated_at to keep the most recent
            fountain_list.sort(key=lambda x: x['updated_at'], reverse=True)
            keep = fountain_list[0]
            delete_list = fountain_list[1:]
            
            logger.info(f"🔍 Found {len(fountain_list)} copies of {mapid}, keeping most recent")
            
            for fountain in delete_list:
                to_delete.append(fountain['id'])
    
    logger.info(f"📊 Found {duplicates_found} duplicate fountains to remove")
    
    if not to_delete:
        logger.info("✅ No duplicates found! Database is clean.")
        return
    
    # Ask for confirmation
    response = input(f"\n⚠️ This will DELETE {len(to_delete)} duplicate fountains. Continue? (yes/no): ")
    if response.lower() not in ['yes', 'y']:
        logger.info("❌ Cleanup cancelled by user")
        return
    
    # Delete duplicates in batches to avoid timeout
    batch_size = 50
    deleted_count = 0
    
    for i in range(0, len(to_delete), batch_size):
        batch = to_delete[i:i + batch_size]
        
        try:
            # Delete fountains (this will cascade to ratings/instagram_posts)
            for fountain_id in batch:
                supabase.table("fountains").delete().eq("id", fountain_id).execute()
                deleted_count += 1
            
            logger.info(f"🗑️ Deleted batch {i//batch_size + 1}: {len(batch)} fountains")
            
        except Exception as e:
            logger.error(f"❌ Error deleting batch: {e}")
            break
    
    # Final count
    fountains_after = supabase.table("fountains").select("id", count="exact").execute()
    total_after = fountains_after.count
    
    logger.info("=" * 50)
    logger.info(f"✅ Cleanup complete!")
    logger.info(f"📊 Before: {total_before} fountains")
    logger.info(f"📊 After: {total_after} fountains")
    logger.info(f"🗑️ Deleted: {deleted_count} duplicates")
    
    # Quick verification
    if total_after <= 429:  # Expected max (278 Vancouver + 151 Burnaby)
        logger.info("✅ Fountain count looks correct!")
    else:
        logger.warning(f"⚠️ Still have {total_after} fountains (expected ~429)")

def show_duplicate_summary():
    """Show summary of duplicates without deleting"""
    supabase: Client = create_client(
        os.getenv("SUPABASE_URL"), 
        os.getenv("SUPABASE_KEY")
    )
    
    logger.info("🔍 Checking for duplicate fountains...")
    
    # Get all fountains
    fountains = supabase.table("fountains").select("original_mapid, created_at").execute()
    logger.info(f"📊 Total fountains: {len(fountains.data)}")
    
    # Group by mapid
    mapid_counts = {}
    for fountain in fountains.data:
        mapid = fountain['original_mapid']
        mapid_counts[mapid] = mapid_counts.get(mapid, 0) + 1
    
    # Find duplicates
    duplicates = {mapid: count for mapid, count in mapid_counts.items() if count > 1}
    
    if duplicates:
        logger.info(f"🚨 Found {len(duplicates)} mapids with duplicates:")
        total_duplicates = 0
        for mapid, count in sorted(duplicates.items()):
            logger.info(f"   - {mapid}: {count} copies")
            total_duplicates += count - 1  # -1 because we keep one
        
        logger.info(f"📊 Total duplicates to remove: {total_duplicates}")
        logger.info(f"📊 After cleanup: {len(fountains.data) - total_duplicates} fountains")
    else:
        logger.info("✅ No duplicates found!")

if __name__ == "__main__":
    import sys
    
    if "--summary" in sys.argv:
        show_duplicate_summary()
    else:
        cleanup_duplicate_fountains()
