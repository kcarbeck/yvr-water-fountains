#!/usr/bin/env python3
"""
Targeted cleanup based on investigation findings
Remove specific problematic fountain types while preserving data
"""

import os
from supabase import create_client, Client
from dotenv import load_dotenv
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

def cleanup_specific_issues():
    """Clean up the specific issues identified"""
    supabase: Client = create_client(
        os.getenv("SUPABASE_URL"), 
        os.getenv("SUPABASE_KEY")
    )
    
    logger.info("🎯 Starting targeted cleanup based on investigation...")
    
    # Get all fountains
    fountains = supabase.table("fountains").select("id, original_mapid, name").execute()
    
    # Categorize problematic fountains
    bby_format_fountains = []  # Wrong BBY format duplicates
    dfeng_fountains = []       # Not in source CSV
    exact_duplicates = []      # DFPB0066 duplicate
    
    for fountain in fountains.data:
        mapid = fountain['original_mapid']
        
        if mapid.startswith('BBY'):
            bby_format_fountains.append(fountain)
        elif mapid.startswith('DFENG'):
            dfeng_fountains.append(fountain)
        elif mapid == 'DFPB0066':
            exact_duplicates.append(fountain)
    
    logger.info(f"🔍 Found issues to clean:")
    logger.info(f"   - BBY format fountains (duplicates): {len(bby_format_fountains)}")
    logger.info(f"   - DFENG fountains (not in CSV): {len(dfeng_fountains)}")
    logger.info(f"   - DFPB0066 duplicates: {len(exact_duplicates)}")
    
    total_to_remove = len(bby_format_fountains) + len(dfeng_fountains) + (len(exact_duplicates) - 1)
    expected_after = len(fountains.data) - total_to_remove
    
    logger.info(f"📊 Total fountains to remove: {total_to_remove}")
    logger.info(f"📊 Expected fountains after cleanup: {expected_after}")
    
    if expected_after != 429:
        logger.warning(f"⚠️ Expected 429 but will have {expected_after}. Double-check the cleanup plan!")
    
    # Show what we'll remove
    print("\n🗑️ Will remove:")
    print(f"   1. All {len(bby_format_fountains)} BBY format fountains (duplicates of numeric Burnaby)")
    print(f"   2. All {len(dfeng_fountains)} DFENG fountains (not in source CSV)")
    print(f"   3. {len(exact_duplicates) - 1} duplicate DFPB0066 (keep 1)")
    
    response = input(f"\n⚠️ This will remove {total_to_remove} fountains. Continue? (yes/no): ")
    if response.lower() not in ['yes', 'y']:
        logger.info("❌ Cleanup cancelled by user")
        return
    
    # Execute cleanup
    removed_count = 0
    
    # 1. Remove BBY format fountains (they're duplicates)
    logger.info("🧹 Removing BBY format fountains...")
    for fountain in bby_format_fountains:
        try:
            # Check if it has ratings first
            ratings = supabase.table("ratings").select("id").eq("fountain_id", fountain['id']).execute()
            if ratings.data:
                logger.warning(f"   ⚠️ BBY fountain {fountain['original_mapid']} has {len(ratings.data)} ratings - skipping")
                continue
            
            supabase.table("fountains").delete().eq("id", fountain['id']).execute()
            removed_count += 1
            logger.debug(f"   🗑️ Removed {fountain['original_mapid']}")
        except Exception as e:
            logger.error(f"   ❌ Error removing {fountain['original_mapid']}: {e}")
    
    # 2. Remove DFENG fountains (not in source CSV)
    logger.info("🧹 Removing DFENG fountains...")
    for fountain in dfeng_fountains:
        try:
            # Check if it has ratings first
            ratings = supabase.table("ratings").select("id").eq("fountain_id", fountain['id']).execute()
            if ratings.data:
                logger.warning(f"   ⚠️ DFENG fountain {fountain['original_mapid']} has {len(ratings.data)} ratings - skipping")
                continue
            
            supabase.table("fountains").delete().eq("id", fountain['id']).execute()
            removed_count += 1
            logger.debug(f"   🗑️ Removed {fountain['original_mapid']}")
        except Exception as e:
            logger.error(f"   ❌ Error removing {fountain['original_mapid']}: {e}")
    
    # 3. Handle DFPB0066 duplicates (keep the one with ratings or most recent)
    if len(exact_duplicates) > 1:
        logger.info("🧹 Cleaning DFPB0066 duplicates...")
        
        # Check which one has ratings
        for fountain in exact_duplicates:
            ratings = supabase.table("ratings").select("id").eq("fountain_id", fountain['id']).execute()
            fountain['rating_count'] = len(ratings.data)
        
        # Sort by rating count, then by creation date
        exact_duplicates.sort(key=lambda x: (x['rating_count'], x.get('created_at', '')), reverse=True)
        
        keep = exact_duplicates[0]
        remove_list = exact_duplicates[1:]
        
        logger.info(f"   Keeping: {keep['id']} ({keep['rating_count']} ratings)")
        
        for fountain in remove_list:
            try:
                if fountain['rating_count'] > 0:
                    # Move ratings to kept fountain
                    supabase.table("ratings").update({
                        "fountain_id": keep['id']
                    }).eq("fountain_id", fountain['id']).execute()
                    logger.info(f"   📋 Moved {fountain['rating_count']} ratings")
                
                supabase.table("fountains").delete().eq("id", fountain['id']).execute()
                removed_count += 1
                logger.info(f"   🗑️ Removed duplicate {fountain['id']}")
            except Exception as e:
                logger.error(f"   ❌ Error removing duplicate: {e}")
    
    # Final verification
    fountains_after = supabase.table("fountains").select("id", count="exact").execute()
    
    logger.info("=" * 50)
    logger.info(f"✅ Targeted cleanup complete!")
    logger.info(f"🗑️ Removed fountains: {removed_count}")
    logger.info(f"⛲ Final fountain count: {fountains_after.count}")
    
    if fountains_after.count == 429:
        logger.info("🎉 Perfect! Database now has exactly 429 fountains as expected!")
    else:
        logger.warning(f"⚠️ Expected 429 but have {fountains_after.count}. May need further investigation.")

if __name__ == "__main__":
    cleanup_specific_issues()
