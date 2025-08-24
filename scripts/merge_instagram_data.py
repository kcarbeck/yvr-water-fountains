#!/usr/bin/env python3
"""
Merge Instagram ratings data with existing GeoJSON file
This script adds Instagram review data to the fountains_processed.geojson file
"""

import json
import csv
from pathlib import Path

def merge_instagram_data():
    """Merge Instagram ratings data with the existing GeoJSON file"""
    
    # Paths
    project_dir = Path(__file__).parent.parent
    raw_geojson_file = project_dir / "data" / "fountains_raw.geojson"
    ratings_file = project_dir / "data" / "ratings.csv"
    
    print("🔄 Merging Instagram data with raw GeoJSON...")
    
    # Load raw GeoJSON (which has proper mapid fields)
    with open(raw_geojson_file, 'r') as f:
        geojson_data = json.load(f)
    
    # Load ratings data
    ratings_by_id = {}
    with open(ratings_file, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            fountain_id = row['id']
            if fountain_id not in ratings_by_id:
                ratings_by_id[fountain_id] = []
            
            ratings_by_id[fountain_id].append({
                "url": row['ig_post_url'],
                "post_id": row['ig_post_url'].split('/p/')[-1].split('/')[0] if '/p/' in row['ig_post_url'] else None,
                "caption": row['caption'],
                "date_posted": row['visit_date'],
                "rating": float(row['rating']) if row['rating'] else None,
                "flow": float(row['flow']) if row['flow'] else None,
                "temp": float(row['temp']) if row['temp'] else None,
                "drainage": float(row['drainage']) if row['drainage'] else None,
                "reviewer": "yvr fountain oracle"
            })
    
    print(f"📊 Found {len(ratings_by_id)} fountains with Instagram reviews")
    
    # Update GeoJSON features with Instagram data
    updated_features = 0
    total_features = len(geojson_data['features'])
    
    for feature in geojson_data['features']:
        properties = feature['properties']
        mapid = properties.get('mapid')
        
        # Set the ID properly for all fountains
        if mapid:
            properties['id'] = mapid
        
        # Determine city based on coordinates
        if 'geometry' in feature and 'coordinates' in feature['geometry']:
            lon, lat = feature['geometry']['coordinates']
            # Based on actual data: Longitude range: -123.2224 to -123.0241
            # Vancouver roughly: -123.2224 to -123.1 (western areas)
            # Burnaby roughly: -123.1 to -123.0241 (eastern areas)
            if lon < -123.1:
                properties['city'] = 'Vancouver'
            else:
                properties['city'] = 'Burnaby'
        else:
            properties['city'] = 'Vancouver'  # Default if no coordinates
        
        # Add Instagram data if available
        if mapid and mapid in ratings_by_id:
            reviews = ratings_by_id[mapid]
            
            # Calculate average ratings
            ratings = [r['rating'] for r in reviews if r['rating'] is not None]
            flows = [r['flow'] for r in reviews if r['flow'] is not None]
            temps = [r['temp'] for r in reviews if r['temp'] is not None]
            drainages = [r['drainage'] for r in reviews if r['drainage'] is not None]
            
            # Update properties with Instagram data
            properties.update({
                "instagram_posts": reviews,
                "has_instagram": True,
                "instagram_count": len(reviews),
                "avg_rating": sum(ratings) / len(ratings) if ratings else None,
                "rating_count": len(reviews),
                "latest_reviewer": reviews[0]['reviewer'] if reviews else None,
                
                # Latest review data
                "rating": reviews[0]['rating'] if reviews else None,
                "flow": reviews[0]['flow'] if reviews else None,
                "temp": reviews[0]['temp'] if reviews else None,
                "drainage": reviews[0]['drainage'] if reviews else None,
                "caption": reviews[0]['caption'] if reviews else None,
                
                # Additional Instagram-specific fields
                "last_visited": reviews[0]['date_posted'] if reviews else None
            })
            
            updated_features += 1
            print(f"  ✅ Updated {mapid}: {properties.get('name', 'Unnamed')}")
        else:
            # Set default values for fountains without Instagram data
            properties.update({
                "instagram_posts": [],
                "has_instagram": False,
                "instagram_count": 0,
                "avg_rating": None,
                "rating_count": 0,
                "rating": None,
                "flow": None,
                "temp": None,
                "drainage": None,
                "caption": None,
                "latest_reviewer": None,
                "last_visited": None
            })
    
    print(f"✅ Updated {updated_features} features with Instagram data")
    print(f"📊 Total fountains: {total_features}")
    
    # Save updated GeoJSON to docs directory
    docs_dir = project_dir / "docs" / "data"
    docs_dir.mkdir(exist_ok=True)
    
    output_file = docs_dir / "fountains_with_instagram.geojson"
    with open(output_file, 'w') as f:
        json.dump(geojson_data, f, indent=2, default=str)
    
    print(f"📁 Saved updated GeoJSON to: {output_file}")
    
    # Also update the main processed file
    main_file = docs_dir / "fountains_processed.geojson"
    with open(main_file, 'w') as f:
        json.dump(geojson_data, f, indent=2, default=str)
    
    print(f"📁 Updated main file: {main_file}")
    
    return True

if __name__ == "__main__":
    success = merge_instagram_data()
    if success:
        print("\n🎉 Instagram data merged successfully!")
        print("Now you can see Instagram reviews in the map interface.")
        print("All original fountains are preserved with proper IDs.")
    else:
        print("\n❌ Failed to merge Instagram data.")
