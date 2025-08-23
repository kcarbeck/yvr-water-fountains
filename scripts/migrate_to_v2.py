#!/usr/bin/env python3
"""
Migration script to transition from old schema to new normalized schema
Run this to migrate existing data to the new structure
"""

import os
from supabase import create_client, Client
from dotenv import load_dotenv
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

def backup_existing_data(supabase: Client):
    """Backup existing data before migration"""
    logger.info("Backing up existing data...")
    
    # Backup fountains
    fountains = supabase.table("fountains").select("*").execute()
    ratings = supabase.table("ratings").select("*").execute()
    
    # Save to files for safety
    import json
    from pathlib import Path
    
    backup_dir = Path(__file__).parent.parent / "backups"
    backup_dir.mkdir(exist_ok=True)
    
    with open(backup_dir / "fountains_backup.json", "w") as f:
        json.dump(fountains.data, f, indent=2, default=str)
    
    with open(backup_dir / "ratings_backup.json", "w") as f:
        json.dump(ratings.data, f, indent=2, default=str)
    
    logger.info(f"Backed up {len(fountains.data)} fountains and {len(ratings.data)} ratings")

def run_migration():
    """Run the complete migration process"""
    supabase: Client = create_client(
        os.getenv("SUPABASE_URL"), 
        os.getenv("SUPABASE_KEY")
    )
    
    try:
        # 1. Backup existing data
        backup_existing_data(supabase)
        
        # 2. Apply new schema
        logger.info("Applying new schema...")
        
        schema_path = Path(__file__).parent.parent / "supabase" / "schema_v2.sql"
        with open(schema_path) as f:
            schema_sql = f.read()
        
        # Note: You'll need to run the schema SQL manually in Supabase dashboard
        # or use a proper migration tool. This is a placeholder for the process.
        logger.info("Please run the schema_v2.sql file in your Supabase dashboard")
        logger.info("Then run the ETL pipeline to load the new data structure")
        
        return True
        
    except Exception as e:
        logger.error(f"Migration failed: {e}")
        return False

if __name__ == "__main__":
    from pathlib import Path
    
    success = run_migration()
    if success:
        logger.info("Migration preparation completed!")
        logger.info("Next steps:")
        logger.info("1. Run schema_v2.sql in Supabase dashboard")
        logger.info("2. Run: python scripts/etl_pipeline.py")
        logger.info("3. Test your application with new structure")
    else:
        logger.error("Migration failed - check logs above")
