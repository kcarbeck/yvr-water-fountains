#!/usr/bin/env python3
"""
Clean database and reload fountain data properly
"""

import os
from supabase import create_client, Client
from dotenv import load_dotenv
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

def clean_database():
    """Clean all fountain and related data"""
    supabase: Client = create_client(
        os.getenv("SUPABASE_URL"), 
        os.getenv("SUPABASE_KEY")
    )
    
    logger.info("🧹 Cleaning database...")
    
    try:
        # Delete in proper order (respecting foreign keys)
        
        # 1. Delete Instagram posts first (get all, then delete)
        posts = supabase.table("instagram_posts").select("id").execute()
        if posts.data:
            for post in posts.data:
                supabase.table("instagram_posts").delete().eq("id", post["id"]).execute()
        logger.info(f"Deleted {len(posts.data) if posts.data else 0} Instagram posts")
        
        # 2. Delete ratings
        ratings = supabase.table("ratings").select("id").execute()
        if ratings.data:
            for rating in ratings.data:
                supabase.table("ratings").delete().eq("id", rating["id"]).execute()
        logger.info(f"Deleted {len(ratings.data) if ratings.data else 0} ratings")
        
        # 3. Delete fountains
        fountains = supabase.table("fountains").select("id").execute()
        if fountains.data:
            for fountain in fountains.data:
                supabase.table("fountains").delete().eq("id", fountain["id"]).execute()
        logger.info(f"Deleted {len(fountains.data) if fountains.data else 0} fountains")
        
        # 4. Reset source datasets (optional - keep for tracking)
        # result = supabase.table("source_datasets").delete().neq("id", "non-existent").execute()
        # logger.info(f"Deleted {len(result.data) if result.data else 0} source datasets")
        
        logger.info("✅ Database cleaned successfully")
        return True
        
    except Exception as e:
        logger.error(f"❌ Error cleaning database: {e}")
        return False

def reload_data():
    """Reload data using the ETL pipeline"""
    logger.info("🔄 Reloading data...")
    
    # Import and run the ETL
    try:
        from etl_pipeline import FountainETL
        
        etl = FountainETL()
        etl.run_full_etl()
        
        logger.info("✅ Data reloaded successfully")
        return True
        
    except Exception as e:
        logger.error(f"❌ Error reloading data: {e}")
        return False

def verify_clean_data():
    """Verify the data is clean after reload"""
    supabase: Client = create_client(
        os.getenv("SUPABASE_URL"), 
        os.getenv("SUPABASE_KEY")
    )
    
    logger.info("🔍 Verifying clean data...")
    
    # Count fountains
    fountains = supabase.table("fountains").select("id").execute()
    fountain_count = len(fountains.data)
    
    # Count unique mapids
    unique_mapids = supabase.table("fountains").select("original_mapid").execute()
    mapid_set = set()
    for f in unique_mapids.data:
        if f.get('original_mapid'):
            mapid_set.add(f['original_mapid'])
    
    logger.info(f"📊 Total fountains: {fountain_count}")
    logger.info(f"📊 Unique mapids: {len(mapid_set)}")
    
    # Check for duplicates
    if fountain_count > 450:
        logger.warning(f"⚠️  Still too many fountains ({fountain_count}), expected ~427")
        return False
    elif fountain_count < 400:
        logger.warning(f"⚠️  Too few fountains ({fountain_count}), expected ~427")
        return False
    else:
        logger.info("✅ Fountain count looks good")
        return True

if __name__ == "__main__":
    print("🚨 CLEANING AND RELOADING FOUNTAIN DATABASE")
    print("This will delete all existing fountain data and reload from CSV files.")
    
    response = input("Are you sure you want to proceed? (yes/no): ")
    
    if response.lower() in ['yes', 'y']:
        # Step 1: Clean
        if clean_database():
            # Step 2: Reload
            if reload_data():
                # Step 3: Verify
                if verify_clean_data():
                    print("\n🎉 Database cleaned and reloaded successfully!")
                    print("Next steps:")
                    print("1. python scripts/generate_geojson_api.py")
                    print("2. Refresh your web app at http://localhost:8000")
                else:
                    print("\n⚠️  Data verification failed - please check manually")
            else:
                print("\n❌ Failed to reload data")
        else:
            print("\n❌ Failed to clean database")
    else:
        print("❌ Operation cancelled")
