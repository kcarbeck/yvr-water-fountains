#!/usr/bin/env python3
"""
Generate GeoJSON API endpoint for the web app
This script exports fountain data from Supabase in GeoJSON format
"""

import os
import json
from supabase import create_client, Client
from dotenv import load_dotenv
from pathlib import Path

load_dotenv()

def generate_geojson_file():
    """Generate a static GeoJSON file for the web app"""
    supabase: Client = create_client(
        os.getenv("SUPABASE_URL"), 
        os.getenv("SUPABASE_KEY")
    )
    
    print("🔄 Generating GeoJSON for web app...")
    
    try:
        # Get fountain data with coordinates
        fountains_result = supabase.table("fountains").select("""
            id, name, lat, lon, original_mapid, location_description, 
            detailed_location, neighborhood, type, maintainer, 
            in_operation, operational_season, pet_friendly, 
            accessibility_features, photo_name
        """).execute()
        fountains_data = {f['id']: f for f in fountains_result.data}
        
        # Get rating summaries
        ratings_result = supabase.table("fountain_rating_summary").select("*").execute()
        ratings_data = {r['fountain_id']: r for r in ratings_result.data}
        
        # Get all reviews for each fountain with Instagram data
        reviews_result = supabase.table("fountain_reviews").select("*").execute()
        reviews_by_fountain = {}
        for review in reviews_result.data:
            fountain_id = review['fountain_id']
            if fountain_id not in reviews_by_fountain:
                reviews_by_fountain[fountain_id] = []
            reviews_by_fountain[fountain_id].append(review)
        
        print(f"📊 Found {len(fountains_data)} fountains")
        
        # Convert to GeoJSON format
        features = []
        
        for fountain_id, fountain in fountains_data.items():
            # Skip fountains without coordinates
            if not fountain.get('lat') or not fountain.get('lon'):
                continue
                
            # Get rating data for this fountain
            rating_data = ratings_data.get(fountain_id, {})
            fountain_reviews = reviews_by_fountain.get(fountain_id, [])
            
            # Get Instagram posts from reviews
            instagram_posts = []
            for review in fountain_reviews:
                if review.get('post_url'):
                    instagram_posts.append({
                        "url": review['post_url'],
                        "post_id": review.get('post_id'),
                        "caption": review.get('ig_caption'),
                        "date_posted": review.get('visit_date'),
                        "rating": review.get('overall_rating'),
                        "reviewer": review.get('reviewer_name')
                    })
            
            feature = {
                "type": "Feature",
                "geometry": {
                    "type": "Point",
                    "coordinates": [float(fountain['lon']), float(fountain['lat'])]
                },
                "properties": {
                    "id": fountain.get('original_mapid'),
                    "fountain_id": fountain_id,
                    "name": fountain.get('name') or 'Unnamed Fountain',
                    "location": fountain.get('location_description'),
                    "detailed_location": fountain.get('detailed_location'),
                    "geo_local_area": fountain.get('neighborhood'),
                    "type": fountain.get('type'),
                    "maintainer": fountain.get('maintainer'),
                    "in_operation": format_operation_status(fountain),
                    "pet_friendly": "Yes" if fountain.get('pet_friendly') else "No",
                    "accessibility_features": fountain.get('accessibility_features'),
                    "photo_name": fountain.get('photo_name'),
                    
                    # Rating summary data
                    "avg_rating": rating_data.get('avg_overall_rating'),
                    "avg_water_quality": rating_data.get('avg_water_quality'),
                    "avg_flow_pressure": rating_data.get('avg_flow_pressure'),
                    "avg_temperature": rating_data.get('avg_temperature'),
                    "avg_drainage": rating_data.get('avg_drainage'),
                    "avg_accessibility": rating_data.get('avg_accessibility'),
                    "rating_count": rating_data.get('total_reviews', 0),
                    "last_reviewed": rating_data.get('last_reviewed'),
                    
                    # Latest review data (for backward compatibility)
                    "rating": rating_data.get('latest_rating'),
                    "flow": rating_data.get('latest_flow'),
                    "temp": rating_data.get('latest_temp'),
                    "drainage": rating_data.get('latest_drainage'),
                    "caption": rating_data.get('latest_notes'),
                    "latest_reviewer": rating_data.get('latest_reviewer'),
                    
                    # Reviews and Instagram data
                    "reviews": fountain_reviews,
                    "instagram_posts": instagram_posts,
                    "has_instagram": len(instagram_posts) > 0,
                    "instagram_count": len(instagram_posts)
                }
            }
            
            features.append(feature)
        
        geojson = {
            "type": "FeatureCollection",
            "features": features
        }
        
        # Save to docs directory for web app
        docs_dir = Path(__file__).parent.parent / "docs"
        data_dir = docs_dir / "data"
        data_dir.mkdir(exist_ok=True)
        
        output_file = data_dir / "fountains_processed.geojson"
        
        with open(output_file, 'w') as f:
            json.dump(geojson, f, indent=2, default=str)
        
        print(f"✅ Generated GeoJSON with {len(features)} fountains")
        print(f"📁 Saved to: {output_file}")
        
        # Also save a compact version for production
        compact_file = data_dir / "fountains.geojson"
        with open(compact_file, 'w') as f:
            json.dump(geojson, f, separators=(',', ':'), default=str)
        
        print(f"📁 Compact version: {compact_file}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error generating GeoJSON: {e}")
        return False

def format_operation_status(fountain):
    """Format the operational status for display"""
    if fountain.get('in_operation') is None:
        return "—"
    elif fountain.get('in_operation'):
        season = fountain.get('operational_season')
        if season:
            return season.title()
        else:
            return "Operational"
    else:
        return "Not operational"

def create_simple_api_server():
    """Create a simple Python HTTP server for local testing"""
    server_code = '''#!/usr/bin/env python3
"""
Simple HTTP server for local development
Serves the docs directory with CORS headers
"""

import http.server
import socketserver
import os
from pathlib import Path

class CORSHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

if __name__ == "__main__":
    PORT = 8000
    docs_dir = Path(__file__).parent.parent / "docs"
    
    os.chdir(docs_dir)
    
    with socketserver.TCPServer(("", PORT), CORSHTTPRequestHandler) as httpd:
        print(f"🌐 Serving docs at http://localhost:{PORT}")
        print(f"📂 Directory: {docs_dir}")
        print("Press Ctrl+C to stop")
        httpd.serve_forever()
'''
    
    server_file = Path(__file__).parent / "serve_docs.py"
    with open(server_file, 'w') as f:
        f.write(server_code)
    
    print(f"📝 Created local server script: {server_file}")
    print("   Run with: python scripts/serve_docs.py")

if __name__ == "__main__":
    success = generate_geojson_file()
    
    if success:
        create_simple_api_server()
        print("\n🎉 Ready to test your web app!")
        print("\nNext steps:")
        print("1. Run the schema update in Supabase dashboard:")
        print("   supabase/schema_v2_updated.sql")
        print("2. Re-run ETL if needed:")
        print("   python scripts/etl_pipeline.py")
        print("3. Start local server:")
        print("   python scripts/serve_docs.py")
        print("4. Open: http://localhost:8000")
    else:
        print("\n❌ Failed to generate GeoJSON. Check your database connection.")
