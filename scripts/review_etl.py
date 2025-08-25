#!/usr/bin/env python3
"""
Unified Review ETL Pipeline for YVR Water Fountains
Implements the unified ratings table approach:
- One 'ratings' table for both public and admin reviews
- Admin reviews (reviewer_name = 'yvrwaterfountains') auto-approved with Instagram data
- Public reviews marked as 'pending' for manual approval
- Instagram data stored in ratings table (post_url, instagram_caption fields)
"""

import pandas as pd
import json
from pathlib import Path
from supabase import create_client, Client
from dotenv import load_dotenv
import os
from typing import Dict, List, Optional
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

class UnifiedReviewETL:
    def __init__(self):
        self.supabase: Client = create_client(
            os.getenv("SUPABASE_URL"), 
            os.getenv("SUPABASE_KEY")
        )
        self.project_root = Path(__file__).parent.parent
        
    def migrate_existing_instagram_reviews(self):
        """Migrate existing Instagram reviews from ratings.csv using unified approach"""
        logger.info("🔄 Migrating existing Instagram reviews to unified ratings table...")
        
        ratings_path = self.project_root / "data" / "ratings.csv"
        if not ratings_path.exists():
            logger.info("No existing ratings file found")
            return
        
        df = pd.read_csv(ratings_path)
        logger.info(f"📊 Found {len(df)} Instagram reviews in CSV")
        
        migrated_count = 0
        skipped_count = 0
        
        for _, row in df.iterrows():
            # Find fountain by original mapid
            fountain_result = self.supabase.table("fountains").select("id").eq("original_mapid", row["id"]).execute()
            
            if not fountain_result.data:
                logger.warning(f"⚠️ Could not find fountain with mapid {row['id']}")
                continue
                
            fountain_id = fountain_result.data[0]["id"]
            
            # Check if rating already exists by Instagram URL to avoid duplicates
            instagram_url = row.get("ig_post_url", "").strip()
            if instagram_url:
                existing_rating = self.supabase.table("ratings").select("id").eq("ig_post_url", instagram_url).execute()
                if existing_rating.data:
                    logger.info(f"⏭️ Instagram review for {row['id']} already exists, skipping")
                    skipped_count += 1
                    continue
            
            # Parse visit date
            visit_date = None
            if pd.notna(row["visit_date"]):
                try:
                    visit_date = pd.to_datetime(row["visit_date"]).date().isoformat()
                except:
                    logger.warning(f"⚠️ Could not parse date: {row['visit_date']}")
            
            # Create unified rating record with Instagram data
            rating_data = {
                "fountain_id": fountain_id,
                "overall_rating": float(row["rating"]) if pd.notna(row["rating"]) else None,
                "flow_pressure": int(row["flow"]) if pd.notna(row["flow"]) else None,
                "temperature": int(row["temp"]) if pd.notna(row["temp"]) else None,
                "drainage": int(row["drainage"]) if pd.notna(row["drainage"]) else None,
                "visited": str(row["visited"]).upper() == "YES" if pd.notna(row["visited"]) else False,
                "visit_date": visit_date,
                "notes": row.get("caption", "").strip() or None,
                
                # Instagram-specific fields in ratings table (updated field names)
                "ig_post_url": instagram_url or None,
                "instagram_caption": row.get("caption", "").strip() or None,
                
                # Admin review settings
                "review_type": "admin_instagram",
                "review_status": "approved",  # Admin Instagram reviews auto-approved
                "user_name": "yvrwaterfountains"  # Key identifier for admin reviews
            }
            
            try:
                result = self.supabase.table("ratings").insert(rating_data).execute()
                migrated_count += 1
                logger.info(f"✅ Migrated Instagram review for {row['id']}")
            except Exception as e:
                logger.error(f"❌ Error migrating {row['id']}: {e}")
        
        logger.info(f"✅ Migration complete: {migrated_count} migrated, {skipped_count} skipped")
    
    def verify_fountain_stability(self):
        """Verify that fountain count is stable and reasonable"""
        logger.info("Verifying fountain data stability...")
        
        fountains = self.supabase.table("fountains").select("id", count="exact").execute()
        logger.info(f"Current fountain count: {fountains.count}")
        
        if fountains.count > 450:
            logger.warning(f"⚠️ Fountain count ({fountains.count}) is higher than expected (~430)")
            logger.warning("This suggests there may be duplicates that need cleanup")
        elif fountains.count < 400:
            logger.warning(f"⚠️ Fountain count ({fountains.count}) is lower than expected (~430)")
            logger.warning("This suggests fountain data may be incomplete")
        else:
            logger.info("✅ Fountain count looks appropriate")
        
        # Check for ratings and Instagram posts
        ratings = self.supabase.table("ratings").select("id", count="exact").execute()
        instagram = self.supabase.table("instagram_posts").select("id", count="exact").execute()
        
        logger.info(f"Current ratings: {ratings.count}")
        logger.info(f"Current Instagram posts: {instagram.count}")
        
        return fountains.count
    
    def run_unified_review_etl(self):
        """Run the unified review ETL pipeline"""
        logger.info("🚀 Starting Unified Review ETL Pipeline...")
        logger.info("📋 Implementing unified ratings table approach:")
        logger.info("   - Admin reviews (yvrwaterfountains) → auto-approved with Instagram data")
        logger.info("   - Public reviews → pending status for manual approval")
        logger.info("=" * 60)
        
        try:
            # Verify fountain data is stable
            fountain_count = self.verify_fountain_stability()
            
            # Migrate existing Instagram reviews to unified ratings table
            self.migrate_existing_instagram_reviews()
            
            # Show final statistics
            ratings = self.supabase.table("ratings").select("id, review_type, review_status, user_name").execute()
            admin_count = len([r for r in ratings.data if r.get('user_name') == 'yvrwaterfountains'])
            public_count = len([r for r in ratings.data if r.get('user_name') != 'yvrwaterfountains'])
            approved_count = len([r for r in ratings.data if r.get('review_status') == 'approved'])
            pending_count = len([r for r in ratings.data if r.get('review_status') == 'pending'])
            
            logger.info("=" * 60)
            logger.info("✅ Unified Review ETL completed successfully!")
            logger.info(f"📊 Final state:")
            logger.info(f"   - Fountains: {fountain_count}")
            logger.info(f"   - Total reviews: {len(ratings.data)}")
            logger.info(f"   - Admin reviews (auto-approved): {admin_count}")
            logger.info(f"   - Public reviews: {public_count}")
            logger.info(f"   - Approved reviews: {approved_count}")
            logger.info(f"   - Pending reviews: {pending_count}")
            logger.info("")
            logger.info("🎯 Next steps:")
            logger.info("1. Update review forms to use unified approach")
            logger.info("2. Test public submission → pending status")
            logger.info("3. Test admin submission → auto-approved status")
            logger.info("4. Generate updated GeoJSON files")
            
        except Exception as e:
            logger.error(f"❌ Unified Review ETL failed: {e}")
            raise

if __name__ == "__main__":
    etl = UnifiedReviewETL()
    etl.run_unified_review_etl()