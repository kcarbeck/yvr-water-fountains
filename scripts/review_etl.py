#!/usr/bin/env python3
"""
Review-only ETL Pipeline for YVR Water Fountains
This script ONLY handles reviews, ratings, and Instagram posts.
Fountain data is considered static and should not be modified.
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

class ReviewOnlyETL:
    def __init__(self):
        self.supabase: Client = create_client(
            os.getenv("SUPABASE_URL"), 
            os.getenv("SUPABASE_KEY")
        )
        self.project_root = Path(__file__).parent.parent
        
    def migrate_existing_ratings(self):
        """Migrate existing ratings from ratings.csv (one-time setup)"""
        logger.info("Migrating existing ratings from CSV...")
        
        ratings_path = self.project_root / "data" / "ratings.csv"
        if not ratings_path.exists():
            logger.info("No existing ratings file found")
            return
        
        df = pd.read_csv(ratings_path)
        logger.info(f"Found {len(df)} ratings in CSV")
        
        migrated_ratings = []
        migrated_instagram = []
        
        for _, row in df.iterrows():
            # Find fountain by original mapid
            fountain_result = self.supabase.table("fountains").select("id").eq("original_mapid", row["id"]).execute()
            
            if not fountain_result.data:
                logger.warning(f"Could not find fountain with mapid {row['id']}")
                continue
                
            fountain_id = fountain_result.data[0]["id"]
            
            # Check if rating already exists to avoid duplicates
            existing_rating = self.supabase.table("ratings").select("id").eq("fountain_id", fountain_id).execute()
            
            if existing_rating.data:
                logger.info(f"Rating for fountain {row['id']} already exists, skipping")
                continue
            
            # Parse visit date
            visit_date = None
            if pd.notna(row["visit_date"]):
                try:
                    visit_date = pd.to_datetime(row["visit_date"]).date().isoformat()
                except:
                    logger.warning(f"Could not parse date: {row['visit_date']}")
            
            # Create rating record
            rating_data = {
                "fountain_id": fountain_id,
                "overall_rating": float(row["rating"]) if pd.notna(row["rating"]) else None,
                "flow_pressure": int(row["flow"]) if pd.notna(row["flow"]) else None,
                "temperature": int(row["temp"]) if pd.notna(row["temp"]) else None,
                "drainage": int(row["drainage"]) if pd.notna(row["drainage"]) else None,
                "visited": str(row["visited"]).upper() == "YES" if pd.notna(row["visited"]) else False,
                "visit_date": visit_date,
                "notes": row.get("caption", "").strip() or None,
                "review_type": "instagram",  # These are from Instagram
                "review_status": "approved",  # Admin reviews are pre-approved
                "reviewer_name": "YVR Water Fountains",
                "is_verified": True
            }
            
            migrated_ratings.append(rating_data)
            
            # Create Instagram post record if URL exists
            if pd.notna(row["ig_post_url"]) and row["ig_post_url"].strip():
                # Check if Instagram post already exists
                existing_ig = self.supabase.table("instagram_posts").select("id").eq("post_url", row["ig_post_url"]).execute()
                
                if not existing_ig.data:
                    instagram_data = {
                        "fountain_id": fountain_id,
                        "post_url": row["ig_post_url"].strip(),
                        "caption": row.get("caption", "").strip() or None,
                        "date_posted": visit_date
                    }
                    migrated_instagram.append(instagram_data)
        
        # Insert ratings
        if migrated_ratings:
            try:
                result = self.supabase.table("ratings").insert(migrated_ratings).execute()
                logger.info(f"Successfully migrated {len(migrated_ratings)} ratings")
            except Exception as e:
                logger.error(f"Error migrating ratings: {e}")
        
        # Insert Instagram posts
        if migrated_instagram:
            try:
                result = self.supabase.table("instagram_posts").insert(migrated_instagram).execute()
                logger.info(f"Successfully migrated {len(migrated_instagram)} Instagram posts")
            except Exception as e:
                logger.error(f"Error migrating Instagram posts: {e}")
    
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
    
    def run_review_etl(self):
        """Run the review-only ETL pipeline"""
        logger.info("Starting review-only ETL pipeline...")
        logger.info("NOTE: This will NOT modify fountain data, only reviews/ratings")
        
        try:
            # Verify fountain data is stable
            fountain_count = self.verify_fountain_stability()
            
            # Migrate existing ratings (safe to run multiple times)
            self.migrate_existing_ratings()
            
            logger.info("✅ Review ETL pipeline completed successfully!")
            logger.info(f"Final state: {fountain_count} fountains with associated reviews")
            
        except Exception as e:
            logger.error(f"Review ETL pipeline failed: {e}")
            raise

if __name__ == "__main__":
    etl = ReviewOnlyETL()
    etl.run_review_etl()