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
                   instagram_caption: str = None,
                   reviewer_name: str = "YVR Water Fountains",
                   reviewer_email: str = None,
                   review_type: str = "instagram") -> bool:
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
            "visit_date": visit_date.isoformat() if visit_date else None,
            "reviewer_name": reviewer_name,
            "reviewer_email": reviewer_email,
            "review_type": review_type,
            "review_status": "approved",  # Admin reviews are auto-approved
            "is_verified": True
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
        """Get all approved ratings for a fountain"""
        fountain_id = self.find_fountain_by_mapid(fountain_mapid)
        if not fountain_id:
            return None
        
        result = self.supabase.table("fountain_reviews").select("*").eq("fountain_id", fountain_id).execute()
        return result.data
    
    def get_fountain_rating_summary(self, fountain_mapid: str):
        """Get rating summary for a fountain"""
        result = self.supabase.table("fountain_rating_summary").select("*").eq("original_mapid", fountain_mapid).execute()
        return result.data[0] if result.data else None
    
    def get_pending_reviews(self):
        """Get all pending reviews for moderation"""
        result = self.supabase.table("ratings").select("""
            *,
            fountains!inner(name, original_mapid)
        """).eq("review_status", "pending").order("created_at", desc=False).execute()
        return result.data
    
    def approve_review(self, review_id: str, approved_by: str = "admin"):
        """Approve a pending review"""
        try:
            result = self.supabase.rpc("approve_review", {
                "review_id": review_id,
                "approved_by_user": approved_by
            }).execute()
            return result.data
        except Exception as e:
            logger.error(f"Error approving review: {e}")
            return False
    
    def reject_review(self, review_id: str, moderation_notes: str, rejected_by: str = "admin"):
        """Reject a pending review"""
        try:
            result = self.supabase.rpc("reject_review", {
                "review_id": review_id,
                "moderation_notes_text": moderation_notes,
                "rejected_by_user": rejected_by
            }).execute()
            return result.data
        except Exception as e:
            logger.error(f"Error rejecting review: {e}")
            return False
    
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

def add_full_rating(mapid: str, overall_rating: float, water_quality: int = None, 
                   flow_pressure: int = None, temperature: int = None, drainage: int = None, 
                   accessibility: int = None, notes: str = "", visited: bool = True, 
                   visit_date: str = None, instagram_url: str = "", instagram_caption: str = ""):
    """Full rating add for admin form"""
    from datetime import datetime, date
    
    rm = RatingManager()
    
    # Convert string date to date object
    parsed_date = None
    if visit_date:
        try:
            parsed_date = datetime.strptime(visit_date, "%Y-%m-%d").date()
        except ValueError:
            print(f"Invalid date format: {visit_date}")
            return False
    
    # Convert None strings to actual None
    def convert_none(val):
        return None if val == "None" or val == "" else int(val)
    
    return rm.add_rating(
        fountain_mapid=mapid,
        overall_rating=overall_rating,
        water_quality=convert_none(water_quality),
        flow_pressure=convert_none(flow_pressure),
        temperature=convert_none(temperature),
        drainage=convert_none(drainage),
        accessibility=convert_none(accessibility),
        notes=notes,
        visited=visited,
        visit_date=parsed_date,
        instagram_url=instagram_url if instagram_url else None,
        instagram_caption=instagram_caption if instagram_caption else None
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
        print("  python rating_helper.py add_full_rating MAPID RATING [water] [flow] [temp] [drain] [access] [notes] [visited] [date] [ig_url] [ig_caption]")
        print("  python rating_helper.py pending  # Show pending reviews")
        print("  python rating_helper.py approve REVIEW_ID")
        print("  python rating_helper.py reject REVIEW_ID [notes]")
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
    
    elif command == "add_full_rating":
        if len(sys.argv) < 4:
            print("Usage: python rating_helper.py add_full_rating MAPID RATING [water] [flow] [temp] [drain] [access] [notes] [visited] [date] [ig_url] [ig_caption]")
            sys.exit(1)
        
        mapid = sys.argv[2]
        rating = float(sys.argv[3])
        water = int(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4] != "None" else None
        flow = int(sys.argv[5]) if len(sys.argv) > 5 and sys.argv[5] != "None" else None
        temp = int(sys.argv[6]) if len(sys.argv) > 6 and sys.argv[6] != "None" else None
        drain = int(sys.argv[7]) if len(sys.argv) > 7 and sys.argv[7] != "None" else None
        access = int(sys.argv[8]) if len(sys.argv) > 8 and sys.argv[8] != "None" else None
        notes = sys.argv[9] if len(sys.argv) > 9 else ""
        visited = sys.argv[10].lower() == "true" if len(sys.argv) > 10 else True
        visit_date = sys.argv[11] if len(sys.argv) > 11 else None
        ig_url = sys.argv[12] if len(sys.argv) > 12 else ""
        ig_caption = sys.argv[13] if len(sys.argv) > 13 else ""
        
        success = add_full_rating(mapid, rating, water, flow, temp, drain, access, notes, visited, visit_date, ig_url, ig_caption)
        if success:
            print(f"✅ Added full rating {rating}/10 for fountain {mapid}")
        else:
            print(f"❌ Failed to add rating for fountain {mapid}")
    
    elif command == "pending":
        rm = RatingManager()
        pending = rm.get_pending_reviews()
        if pending:
            print(f"\nFound {len(pending)} pending reviews:")
            for review in pending:
                print(f"- {review['id']}: {review['fountains']['name']} ({review['fountains']['original_mapid']}) - {review['overall_rating']}/10")
                print(f"  By: {review['reviewer_name']} on {review['visit_date']}")
                if review['notes']:
                    print(f"  Notes: {review['notes'][:100]}...")
                print()
        else:
            print("No pending reviews found.")
    
    elif command == "approve":
        if len(sys.argv) < 3:
            print("Usage: python rating_helper.py approve REVIEW_ID")
            sys.exit(1)
        
        review_id = sys.argv[2]
        rm = RatingManager()
        success = rm.approve_review(review_id)
        if success:
            print(f"✅ Approved review {review_id}")
        else:
            print(f"❌ Failed to approve review {review_id}")
    
    elif command == "reject":
        if len(sys.argv) < 3:
            print("Usage: python rating_helper.py reject REVIEW_ID [notes]")
            sys.exit(1)
        
        review_id = sys.argv[2]
        moderation_notes = sys.argv[3] if len(sys.argv) > 3 else "Review rejected"
        rm = RatingManager()
        success = rm.reject_review(review_id, moderation_notes)
        if success:
            print(f"✅ Rejected review {review_id}")
        else:
            print(f"❌ Failed to reject review {review_id}")
    
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)
