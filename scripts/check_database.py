#!/usr/bin/env python3
"""
Database Status Checker - Quick way to see what's in your Supabase database
Run this before and after ETL to see changes
"""

import os
from supabase import create_client, Client
from dotenv import load_dotenv
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

def check_database():
    """Check current database status"""
    try:
        supabase: Client = create_client(
            os.getenv("SUPABASE_URL"), 
            os.getenv("SUPABASE_KEY")
        )
        
        print("🔍 Database Status Report")
        print("=" * 50)
        
        # Check cities
        try:
            cities = supabase.table("cities").select("*").execute()
            print(f"🏙️  Cities: {len(cities.data)}")
            for city in cities.data:
                print(f"   - {city['name']} (ID: {city['id']})")
        except Exception as e:
            print(f"❌ Error checking cities: {e}")
        
        print()
        
        # Check fountains
        try:
            fountains = supabase.table("fountains").select("original_mapid, city_id, name, lat, lon").execute()
            print(f"⛲ Fountains: {len(fountains.data)}")
            
            # Count by city pattern
            vancouver_count = len([f for f in fountains.data if f["original_mapid"].startswith("DFPB")])
            burnaby_count = len([f for f in fountains.data if f["original_mapid"].isdigit()])  # Burnaby uses numeric COMPKEY
            other_count = len(fountains.data) - vancouver_count - burnaby_count
            
            print(f"   - Vancouver (DFPB*): {vancouver_count}")
            print(f"   - Burnaby (numeric): {burnaby_count}")
            if other_count > 0:
                print(f"   - Other patterns: {other_count}")
            
            # Show sample fountains
            if fountains.data:
                print(f"\n📍 Sample fountains:")
                for fountain in fountains.data[:5]:
                    name = fountain.get('name', 'Unnamed')[:30] + "..." if len(fountain.get('name', '')) > 30 else fountain.get('name', 'Unnamed')
                    print(f"   - {fountain['original_mapid']}: {name}")
                if len(fountains.data) > 5:
                    print(f"   ... and {len(fountains.data) - 5} more")
            
            # Coordinate check
            if fountains.data:
                coords_with_data = [f for f in fountains.data if f.get('lat') and f.get('lon')]
                if coords_with_data:
                    lats = [f['lat'] for f in coords_with_data]
                    lons = [f['lon'] for f in coords_with_data]
                    print(f"\n🗺️  Coordinate ranges:")
                    print(f"   - Latitude: {min(lats):.6f} to {max(lats):.6f}")
                    print(f"   - Longitude: {min(lons):.6f} to {max(lons):.6f}")
                    
                    # Sanity check for Vancouver/Burnaby area
                    if 49.0 <= min(lats) and max(lats) <= 49.5 and -123.5 <= min(lons) and max(lons) <= -122.5:
                        print("   ✅ Coordinates look correct for Vancouver/Burnaby area")
                    else:
                        print("   ⚠️  Coordinates may be outside expected Vancouver/Burnaby area")
                else:
                    print("   ⚠️  No fountains have coordinate data")
            
        except Exception as e:
            print(f"❌ Error checking fountains: {e}")
        
        print()
        
        # Check ratings
        try:
            ratings = supabase.table("ratings").select("id, fountain_id, overall_rating, review_status").execute()
            print(f"⭐ Ratings: {len(ratings.data)}")
            
            if ratings.data:
                status_counts = {}
                for rating in ratings.data:
                    status = rating.get('review_status', 'unknown')
                    status_counts[status] = status_counts.get(status, 0) + 1
                
                for status, count in status_counts.items():
                    print(f"   - {status}: {count}")
        except Exception as e:
            print(f"❌ Error checking ratings: {e}")
        
        # Check Instagram posts
        try:
            instagram = supabase.table("instagram_posts").select("id, fountain_id, post_url").execute()
            print(f"📸 Instagram posts: {len(instagram.data)}")
        except Exception as e:
            print(f"❌ Error checking Instagram posts: {e}")
        
        print("=" * 50)
        print("✅ Database check complete")
        
    except Exception as e:
        print(f"❌ Failed to connect to database: {e}")
        print("Make sure your .env file has correct SUPABASE_URL and SUPABASE_KEY")

if __name__ == "__main__":
    check_database()
