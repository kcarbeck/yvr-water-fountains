#!/usr/bin/env python3
"""
Quick script to check what data was loaded by the ETL pipeline
"""

import os
from supabase import create_client, Client
from dotenv import load_dotenv
import pandas as pd

load_dotenv()

def check_database_status():
    supabase: Client = create_client(
        os.getenv("SUPABASE_URL"), 
        os.getenv("SUPABASE_KEY")
    )
    
    print("🔍 Checking database status after ETL...")
    print("=" * 50)
    
    # Check cities
    try:
        cities = supabase.table("cities").select("*").execute()
        print(f"✅ Cities: {len(cities.data)} loaded")
        for city in cities.data:
            print(f"   - {city['name']} (ID: {city['id']})")
    except Exception as e:
        print(f"❌ Error checking cities: {e}")
    
    print()
    
    # Check fountains
    try:
        fountains = supabase.table("fountains").select("*").execute()
        print(f"✅ Fountains: {len(fountains.data)} loaded")
        
        # Group by city
        city_counts = {}
        for fountain in fountains.data:
            city_id = fountain.get('city_id')
            city_counts[city_id] = city_counts.get(city_id, 0) + 1
        
        # Get city names
        for city_id, count in city_counts.items():
            city_result = supabase.table("cities").select("name").eq("id", city_id).execute()
            city_name = city_result.data[0]["name"] if city_result.data else f"City ID {city_id}"
            print(f"   - {city_name}: {count} fountains")
        
        # Show sample fountains
        print(f"\n📍 Sample fountains:")
        for fountain in fountains.data[:5]:
            print(f"   - {fountain.get('name', 'Unnamed')} at {fountain.get('lat', 'N/A')}, {fountain.get('lon', 'N/A')}")
            
    except Exception as e:
        print(f"❌ Error checking fountains: {e}")
    
    print()
    
    # Check ratings
    try:
        ratings = supabase.table("ratings").select("*").execute()
        print(f"✅ Ratings: {len(ratings.data)} loaded")
    except Exception as e:
        print(f"❌ Error checking ratings: {e}")
    
    # Check Instagram posts
    try:
        instagram = supabase.table("instagram_posts").select("*").execute()
        print(f"✅ Instagram posts: {len(instagram.data)} loaded")
    except Exception as e:
        print(f"❌ Error checking Instagram posts: {e}")
    
    print()
    print("🗺️ Coordinate range check:")
    
    try:
        # Check coordinate ranges
        fountains_df = pd.DataFrame(fountains.data)
        if len(fountains_df) > 0:
            lat_min, lat_max = fountains_df['lat'].min(), fountains_df['lat'].max()
            lon_min, lon_max = fountains_df['lon'].min(), fountains_df['lon'].max()
            
            print(f"   Latitude range: {lat_min:.6f} to {lat_max:.6f}")
            print(f"   Longitude range: {lon_min:.6f} to {lon_max:.6f}")
            
            # Vancouver area should be roughly:
            # Lat: 49.2 to 49.3, Lon: -123.3 to -122.9
            # Burnaby area should be similar
            
            if 49.0 < lat_min < 49.5 and 49.0 < lat_max < 49.5:
                print("   ✅ Latitudes look correct for Vancouver/Burnaby area")
            else:
                print("   ⚠️  Latitudes seem outside Vancouver/Burnaby area")
                
            if -123.5 < lon_min < -122.5 and -123.5 < lon_max < -122.5:
                print("   ✅ Longitudes look correct for Vancouver/Burnaby area")
            else:
                print("   ⚠️  Longitudes seem outside Vancouver/Burnaby area")
        
    except Exception as e:
        print(f"   ❌ Error checking coordinates: {e}")

if __name__ == "__main__":
    check_database_status()
