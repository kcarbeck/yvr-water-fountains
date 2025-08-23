#!/usr/bin/env python3
"""
Helper script for managing fountain ratings and Instagram posts
"""

import os
from supabase import create_client, Client
from dotenv import load_dotenv
from datetime import datetime, date
from typing import Optional
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

class RatingManager:
    def __init__(self):
        self.supabase: Client = create_client(
            os.getenv("SUPABASE_URL"), 
            os.getenv("SUPABASE_KEY")
        )
    
    def find_fountain_by_mapid(self, mapid: str) -> Optional[str]:
        """Find fountain UUID by original mapid"""
        result = self.supabase.table("fountains").select("id").eq("original_mapid", mapid).execute()
        
        if result.data:
            return result.data[0]["id"]
        else:
            logger.error(f"Fountain with mapid {mapid} not found")
            return None
    
    def add_rating(self, 
                   fountain_mapid: str,
                   overall_rating: float,
                   water_quality: int = None,
                   flow_pressure: int = None,
                   temperature: int = None,
                   drainage: int = None,
                   accessibility: int = None,
                   notes: str = None,
                   visited: bool = True,
                   visit_date: date = None,
                   instagram_url: str = None,
                   instagram_caption: str = None) -> bool:
        """Add a new rating for a fountain"""
        
        # Find fountain
        fountain_id = self.find_fountain_by_mapid(fountain_mapid)
        if not fountain_id:
            return False
        
        # Default visit date to today
        if visit_date is None and visited:
            visit_date = date.today()
        
        # Create rating record
        rating_data = {
            "fountain_id": fountain_id,
            "overall_rating": overall_rating,
            "water_quality": water_quality,
            "flow_pressure": flow_pressure,
            "temperature": temperature,
            "drainage": drainage,
            "accessibility": accessibility,
            "notes": notes,
            "visited": visited,
            "visit_date": visit_date.isoformat() if visit_date else None
        }
        
        try:
            # Insert rating
            rating_result = self.supabase.table("ratings").insert(rating_data).execute()
            rating_id = rating_result.data[0]["id"]
            logger.info(f"Added rating {rating_id} for fountain {fountain_mapid}")
            
            # Add Instagram post if provided
            if instagram_url:
                instagram_data = {
                    "fountain_id": fountain_id,
                    "rating_id": rating_id,
                    "post_url": instagram_url,
                    "caption": instagram_caption or notes,
                    "date_posted": visit_date.isoformat() if visit_date else None
                }
                
                self.supabase.table("instagram_posts").insert(instagram_data).execute()
                logger.info(f"Added Instagram post for fountain {fountain_mapid}")
            
            return True
            
        except Exception as e:
            logger.error(f"Error adding rating: {e}")
            return False
    
    def get_fountain_ratings(self, fountain_mapid: str):
        """Get all ratings for a fountain"""
        fountain_id = self.find_fountain_by_mapid(fountain_mapid)
        if not fountain_id:
            return None
        
        result = self.supabase.table("ratings").select("*").eq("fountain_id", fountain_id).order("visit_date", desc=True).execute()
        return result.data
    
    def update_fountain_status(self, fountain_mapid: str, in_operation: bool, notes: str = None):
        """Update operational status of a fountain"""
        fountain_id = self.find_fountain_by_mapid(fountain_mapid)
        if not fountain_id:
            return False
        
        update_data = {"in_operation": in_operation}
        if notes:
            # You might want to add a notes field to fountains table for operational notes
            pass
        
        try:
            self.supabase.table("fountains").update(update_data).eq("id", fountain_id).execute()
            logger.info(f"Updated fountain {fountain_mapid} operational status to {in_operation}")
            return True
        except Exception as e:
            logger.error(f"Error updating fountain status: {e}")
            return False
    
    def search_fountains(self, city: str = None, in_operation: bool = None, min_rating: float = None):
        """Search fountains with filters"""
        query = self.supabase.table("fountain_details").select("*")
        
        if city:
            query = query.eq("city_name", city)
        if in_operation is not None:
            query = query.eq("in_operation", in_operation)
        if min_rating:
            query = query.gte("avg_rating", min_rating)
        
        result = query.execute()
        return result.data

# Convenience functions for command line usage
def add_rating_quick(mapid: str, rating: float, notes: str = "", instagram_url: str = ""):
    """Quick rating add for command line"""
    rm = RatingManager()
    return rm.add_rating(
        fountain_mapid=mapid,
        overall_rating=rating,
        notes=notes,
        instagram_url=instagram_url if instagram_url else None
    )

def search_fountains_quick(city: str = None):
    """Quick fountain search"""
    rm = RatingManager()
    fountains = rm.search_fountains(city=city)
    
    print(f"\nFound {len(fountains)} fountains:")
    for f in fountains[:10]:  # Show first 10
        rating_info = f"(avg: {f['avg_rating']:.1f})" if f['avg_rating'] else "(no ratings)"
        print(f"- {f['original_mapid']}: {f['name']} in {f['city_name']} {rating_info}")
    
    if len(fountains) > 10:
        print(f"... and {len(fountains) - 10} more")

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python rating_helper.py search [city]")
        print("  python rating_helper.py rate MAPID RATING [notes] [instagram_url]")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "search":
        city = sys.argv[2] if len(sys.argv) > 2 else None
        search_fountains_quick(city)
    
    elif command == "rate":
        if len(sys.argv) < 4:
            print("Usage: python rating_helper.py rate MAPID RATING [notes] [instagram_url]")
            sys.exit(1)
        
        mapid = sys.argv[2]
        rating = float(sys.argv[3])
        notes = sys.argv[4] if len(sys.argv) > 4 else ""
        instagram_url = sys.argv[5] if len(sys.argv) > 5 else ""
        
        success = add_rating_quick(mapid, rating, notes, instagram_url)
        if success:
            print(f"✅ Added rating {rating}/10 for fountain {mapid}")
        else:
            print(f"❌ Failed to add rating for fountain {mapid}")
    
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)
