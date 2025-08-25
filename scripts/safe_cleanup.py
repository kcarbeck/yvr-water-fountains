#!/usr/bin/env python3
"""
Safe cleanup of duplicate fountains while preserving ratings
This script handles foreign key constraints properly
"""

import os
from supabase import create_client, Client
from dotenv import load_dotenv
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

def safe_cleanup_duplicates():
    """Safely remove duplicate fountains while preserving ratings"""
    supabase: Client = create_client(
        os.getenv("SUPABASE_URL"), 
        os.getenv("SUPABASE_KEY")
    )
    
    logger.info("🧹 Starting SAFE duplicate fountain cleanup...")
    
    # Get all fountains with their ratings count
    fountains = supabase.table("fountains").select("""
        id, original_mapid, created_at, updated_at,
        ratings!inner(count)
    """).execute()
    
    logger.info(f"📊 Total fountains: {len(fountains.data)}")
    
    # Also get fountains without ratings
    fountains_no_ratings = supabase.table("fountains").select("""
        id, original_mapid, created_at, updated_at
    """).execute()
    
    # Build complete picture
    fountain_ratings = {}
    for fountain in fountains_no_ratings.data:
        # Get rating count for each fountain
        ratings = supabase.table("ratings").select("id").eq("fountain_id", fountain["id"]).execute()
        fountain_ratings[fountain["id"]] = {
            **fountain,
            "rating_count": len(ratings.data)
        }
    
    # Group by original_mapid
    mapid_groups = {}
    for fountain_id, fountain_data in fountain_ratings.items():
        mapid = fountain_data['original_mapid']
        if mapid not in mapid_groups:
            mapid_groups[mapid] = []
        mapid_groups[mapid].append(fountain_data)
    
    # Find duplicates and plan cleanup
    duplicates_found = 0
    merge_plan = []
    
    for mapid, fountain_list in mapid_groups.items():
        if len(fountain_list) > 1:
            duplicates_found += len(fountain_list) - 1
            
            # Sort by: 1) has ratings, 2) most recent update
            fountain_list.sort(key=lambda x: (x['rating_count'], x['updated_at']), reverse=True)
            
            keep = fountain_list[0]
            duplicates = fountain_list[1:]
            
            total_ratings = sum(f['rating_count'] for f in fountain_list)
            
            logger.info(f"🔍 Mapid {mapid}: {len(fountain_list)} copies, {total_ratings} total ratings")
            logger.info(f"    Keeping: {keep['id']} ({keep['rating_count']} ratings)")
            
            merge_plan.append({
                'mapid': mapid,
                'keep': keep,
                'duplicates': duplicates,
                'total_ratings': total_ratings
            })
    
    if not merge_plan:
        logger.info("✅ No duplicates found! Database is clean.")
        return
    
    logger.info(f"📊 Found {duplicates_found} duplicate fountains to clean up")
    
    # Show what will happen
    print("\n🗺️ Cleanup Plan:")
    for plan in merge_plan:
        print(f"  {plan['mapid']}: Keep 1, remove {len(plan['duplicates'])}, preserve {plan['total_ratings']} ratings")
    
    response = input(f"\n⚠️ This will remove {duplicates_found} duplicate fountains. Continue? (yes/no): ")
    if response.lower() not in ['yes', 'y']:
        logger.info("❌ Cleanup cancelled by user")
        return
    
    # Execute cleanup plan
    total_deleted = 0
    total_ratings_moved = 0
    
    for plan in merge_plan:
        mapid = plan['mapid']
        keep_fountain = plan['keep']
        duplicates = plan['duplicates']
        
        logger.info(f"🔄 Processing {mapid}...")
        
        for duplicate in duplicates:
            duplicate_id = duplicate['id']
            rating_count = duplicate['rating_count']
            
            if rating_count > 0:
                # Move ratings to the fountain we're keeping
                logger.info(f"   📋 Moving {rating_count} ratings from duplicate to kept fountain")
                
                try:
                    # Update ratings to point to the kept fountain
                    supabase.table("ratings").update({
                        "fountain_id": keep_fountain['id']
                    }).eq("fountain_id", duplicate_id).execute()
                    
                    total_ratings_moved += rating_count
                    
                except Exception as e:
                    logger.error(f"   ❌ Error moving ratings: {e}")
                    continue
            
            # Now delete the duplicate fountain (safe since ratings moved)
            try:
                supabase.table("fountains").delete().eq("id", duplicate_id).execute()
                total_deleted += 1
                logger.info(f"   🗑️ Deleted duplicate fountain {duplicate_id}")
                
            except Exception as e:
                logger.error(f"   ❌ Error deleting fountain: {e}")
    
    # Final verification
    fountains_after = supabase.table("fountains").select("id", count="exact").execute()
    ratings_after = supabase.table("ratings").select("id", count="exact").execute()
    
    logger.info("=" * 50)
    logger.info(f"✅ Safe cleanup complete!")
    logger.info(f"🗑️ Deleted fountains: {total_deleted}")
    logger.info(f"📋 Ratings preserved: {total_ratings_moved}")
    logger.info(f"⛲ Final fountain count: {fountains_after.count}")
    logger.info(f"⭐ Total ratings: {ratings_after.count}")

def show_fountain_analysis():
    """Show detailed analysis of fountains and their relationships"""
    supabase: Client = create_client(
        os.getenv("SUPABASE_URL"), 
        os.getenv("SUPABASE_KEY")
    )
    
    logger.info("🔍 Analyzing fountain database...")
    
    # Get all fountains
    fountains = supabase.table("fountains").select("id, original_mapid, created_at").execute()
    ratings = supabase.table("ratings").select("id, fountain_id").execute()
    instagram = supabase.table("instagram_posts").select("id, fountain_id").execute()
    
    logger.info(f"📊 Total fountains: {len(fountains.data)}")
    logger.info(f"📊 Total ratings: {len(ratings.data)}")
    logger.info(f"📊 Total Instagram posts: {len(instagram.data)}")
    
    # Analyze ID patterns
    patterns = {}
    for fountain in fountains.data:
        mapid = fountain['original_mapid']
        if mapid.startswith('DFPB'):
            pattern = 'Vancouver (DFPB*)'
        elif mapid.isdigit():
            pattern = 'Burnaby (numeric)'
        elif mapid.startswith('BBY'):
            pattern = 'Burnaby (BBY* - wrong format)'
        else:
            pattern = f'Other ({mapid[:10]}...)'
        
        patterns[pattern] = patterns.get(pattern, 0) + 1
    
    logger.info("\n📊 Fountain ID patterns:")
    for pattern, count in patterns.items():
        logger.info(f"   - {pattern}: {count}")
    
    # Find duplicates
    mapid_counts = {}
    for fountain in fountains.data:
        mapid = fountain['original_mapid']
        mapid_counts[mapid] = mapid_counts.get(mapid, 0) + 1
    
    duplicates = {mapid: count for mapid, count in mapid_counts.items() if count > 1}
    
    if duplicates:
        logger.info(f"\n🚨 Found {len(duplicates)} mapids with duplicates:")
        for mapid, count in sorted(duplicates.items()):
            # Count ratings for this mapid
            total_ratings = 0
            for fountain in fountains.data:
                if fountain['original_mapid'] == mapid:
                    fountain_ratings = [r for r in ratings.data if r['fountain_id'] == fountain['id']]
                    total_ratings += len(fountain_ratings)
            
            logger.info(f"   - {mapid}: {count} copies, {total_ratings} total ratings")
    else:
        logger.info("\n✅ No duplicates found!")

if __name__ == "__main__":
    import sys
    
    if "--analysis" in sys.argv:
        show_fountain_analysis()
    else:
        safe_cleanup_duplicates()
