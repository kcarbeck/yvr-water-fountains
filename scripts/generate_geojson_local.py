#!/usr/bin/env python3
"""
Generate GeoJSON for deployment using local data files only
This avoids database connection issues and ensures clean data
"""

import json
import csv
import gzip
from pathlib import Path

def generate_geojson_from_local():
    """Generate GeoJSON using local data files"""
    
    project_dir = Path(__file__).parent.parent
    data_dir = project_dir / "data"
    docs_dir = project_dir / "docs"
    docs_data_dir = docs_dir / "data"
    docs_data_dir.mkdir(exist_ok=True)
    
    print("🔄 Generating GeoJSON from local data files...")
    
    try:
        # Load existing processed fountain data
        fountain_file = data_dir / "fountains_processed.geojson"
        if not fountain_file.exists():
            print(f"❌ Fountain data file not found: {fountain_file}")
            return False
            
        with open(fountain_file, 'r') as f:
            fountain_data = json.load(f)
        
        print(f"📊 Loaded {len(fountain_data['features'])} fountains from local data")
        
        # Load ratings data if available
        ratings_file = data_dir / "ratings.csv"
        ratings_by_id = {}
        
        if ratings_file.exists():
            with open(ratings_file, 'r') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    fountain_id = row['id']
                    ratings_by_id[fountain_id] = {
                        'rating': row.get('rating', ''),
                        'flow': row.get('flow', ''),
                        'temp': row.get('temp', ''),
                        'drainage': row.get('drainage', ''),
                        'caption': row.get('caption', ''),
                        'visited': row.get('visited', ''),
                        'visit_date': row.get('visit_date', ''),
                        'ig_post_url': row.get('ig_post_url', '')
                    }
            print(f"📊 Loaded ratings for {len(ratings_by_id)} fountains")
        else:
            print("⚠️  No ratings file found, proceeding without ratings")
        
        # Process and clean fountain data
        clean_features = []
        seen_ids = set()
        
        for feature in fountain_data['features']:
            fountain_id = feature['properties']['id']
            
            # Skip duplicates
            if fountain_id in seen_ids:
                print(f"⚠️  Skipping duplicate fountain: {fountain_id}")
                continue
            seen_ids.add(fountain_id)
            
            # Add rating data if available
            if fountain_id in ratings_by_id:
                rating_data = ratings_by_id[fountain_id]
                feature['properties'].update({
                    'rating': rating_data.get('rating', ''),
                    'flow': rating_data.get('flow', ''),
                    'temp': rating_data.get('temp', ''),
                    'drainage': rating_data.get('drainage', ''),
                    'caption': rating_data.get('caption', ''),
                    'visited': rating_data.get('visited', ''),
                    'visit_date': rating_data.get('visit_date', ''),
                    'ig_post_url': rating_data.get('ig_post_url', ''),
                    'photo_url': f"https://www.instagram.com/p/{rating_data.get('ig_post_url', '').split('/')[-2] if '/p/' in rating_data.get('ig_post_url', '') else ''}/media/?size=m" if rating_data.get('ig_post_url') else ''
                })
            
            clean_features.append(feature)
        
        # Create final GeoJSON
        final_geojson = {
            "type": "FeatureCollection",
            "features": clean_features
        }
        
        # Save to docs directory
        output_file = docs_data_dir / "fountains_processed.geojson"
        with open(output_file, 'w') as f:
            json.dump(final_geojson, f, indent=2)
        
        # Create minified version
        min_file = docs_data_dir / "fountains.min.geojson"
        with open(min_file, 'w') as f:
            json.dump(final_geojson, f, separators=(',', ':'))
        
        # Create gzipped version for even better performance
        gzip_file = docs_data_dir / "fountains.min.geojson.gz"
        with gzip.open(gzip_file, 'wt', encoding='utf-8') as f:
            json.dump(final_geojson, f, separators=(',', ':'))
        
        print(f"✅ Generated clean GeoJSON with {len(clean_features)} fountains")
        print(f"📁 Saved to: {output_file}")
        print(f"📁 Minified: {min_file}")
        print(f"📁 Compressed: {gzip_file}")
        
        # Also copy to main data directory for consistency
        main_output = data_dir / "fountains_processed.geojson"
        with open(main_output, 'w') as f:
            json.dump(final_geojson, f, indent=2)
        
        return True
        
    except Exception as e:
        print(f"❌ Error generating GeoJSON: {e}")
        return False

if __name__ == "__main__":
    success = generate_geojson_from_local()
    
    if success:
        print("\n🎉 Local GeoJSON generation complete!")
        print("\nFiles ready for deployment:")
        print("- docs/data/fountains_processed.geojson")
        print("- docs/data/fountains.min.geojson")
        print("- docs/data/fountains.min.geojson.gz")
    else:
        print("\n❌ Failed to generate GeoJSON from local files")