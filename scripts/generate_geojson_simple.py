#!/usr/bin/env python3
import os
import json
from supabase import create_client
from dotenv import load_dotenv
from pathlib import Path

load_dotenv()

def generate_geojson_file():
    supabase = create_client(
        os.getenv("SUPABASE_URL"), 
        os.getenv("SUPABASE_KEY")
    )
    
    print("🔄 Generating GeoJSON for web app...")
    
    try:
        # Get fountain data
        fountains_result = supabase.table("fountains").select("id, name, lat, lon, original_mapid, location_description, neighborhood, type, maintainer, operational_season, pet_friendly").execute()
        fountains_data = {f['id']: f for f in fountains_result.data}
        
        # Get ratings data
        ratings_result = supabase.table("ratings").select("fountain_id, overall_rating, water_quality, flow_pressure, temperature, accessibility, visit_date, notes, reviewer_name").execute()
        
        # Group ratings by fountain
        ratings_by_fountain = {}
        for rating in ratings_result.data:
            fountain_id = rating['fountain_id']
            if fountain_id not in ratings_by_fountain:
                ratings_by_fountain[fountain_id] = []
            ratings_by_fountain[fountain_id].append(rating)
        
        print(f"📊 Found {len(fountains_data)} fountains")
        print(f"📊 Found {len(ratings_result.data)} ratings")
        
        # Convert to GeoJSON format
        features = []
        
        for fountain_id, fountain in fountains_data.items():
            if not fountain.get('lat') or not fountain.get('lon'):
                continue
                
            fountain_ratings = ratings_by_fountain.get(fountain_id, [])
            
            # Calculate averages
            if fountain_ratings:
                avg_overall = sum(r['overall_rating'] for r in fountain_ratings if r['overall_rating']) / len([r for r in fountain_ratings if r['overall_rating']])
                latest_review = max(fountain_ratings, key=lambda x: x['visit_date'] if x['visit_date'] else '1900-01-01')
                latest_rating = latest_review['overall_rating']
                latest_reviewer = latest_review['reviewer_name']
                latest_notes = latest_review['notes']
            else:
                avg_overall = None
                latest_rating = latest_reviewer = latest_notes = None
            
            feature = {
                "type": "Feature",
                "geometry": {
                    "type": "Point",
                    "coordinates": [float(fountain['lon']), float(fountain['lat'])]
                },
                "properties": {
                    "id": fountain.get('original_mapid'),
                    "name": fountain.get('name') or 'Unnamed Fountain',
                    "location": fountain.get('location_description'),
                    "geo_local_area": fountain.get('neighborhood'),
                    "type": fountain.get('type'),
                    "maintainer": fountain.get('maintainer'),
                    "operational_season": fountain.get('operational_season', 'unknown'),
                    "pet_friendly": "Yes" if fountain.get('pet_friendly') else "No",
                    "avg_rating": round(avg_overall, 1) if avg_overall else None,
                    "rating_count": len(fountain_ratings),
                    "rating": latest_rating,
                    "latest_reviewer": latest_reviewer,
                    "caption": latest_notes
                }
            }
            
            features.append(feature)
        
        # Create GeoJSON structure
        geojson = {
            "type": "FeatureCollection",
            "features": features
        }
        
        # Save to docs/data directory
        docs_dir = Path(__file__).parent.parent / "docs"
        data_dir = docs_dir / "data"
        data_dir.mkdir(exist_ok=True)
        
        output_file = data_dir / "fountains_processed.geojson"
        with open(output_file, 'w') as f:
            json.dump(geojson, f, indent=2)
        
        print(f"✅ GeoJSON file generated successfully: {output_file}")
        print(f"📊 Total features: {len(features)}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error generating GeoJSON: {e}")
        return False

if __name__ == "__main__":
    generate_geojson_file()
