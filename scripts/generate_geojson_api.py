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

def fallback_to_static_data():
    """Use existing static data when Supabase credentials are not available"""
    docs_dir = Path(__file__).parent.parent / "docs"
    data_dir = docs_dir / "data"
    
    # Check if we have existing processed data
    processed_file = data_dir / "fountains_processed.geojson"
    compact_file = data_dir / "fountains.geojson"
    
    if processed_file.exists():
        print(f"✅ Using existing processed data: {processed_file}")
        
        # Copy to the compact version if it doesn't exist
        if not compact_file.exists():
            try:
                import json
                with open(processed_file, 'r') as f:
                    data = json.load(f)
                with open(compact_file, 'w') as f:
                    json.dump(data, f, separators=(',', ':'), default=str)
                print(f"📁 Created compact version: {compact_file}")
            except Exception as e:
                print(f"⚠️  Warning: Could not create compact version: {e}")
        
        return True
    
    # Check if we have any GeoJSON file to use
    geojson_files = list(data_dir.glob("*.geojson"))
    if geojson_files:
        source_file = geojson_files[0]  # Use the first available
        print(f"✅ Using available data: {source_file}")
        
        # Copy to our expected output files
        try:
            import json
            with open(source_file, 'r') as f:
                data = json.load(f)
            
            # Create both processed and compact versions
            with open(processed_file, 'w') as f:
                json.dump(data, f, indent=2, default=str)
            with open(compact_file, 'w') as f:
                json.dump(data, f, separators=(',', ':'), default=str)
            
            print(f"📁 Created processed version: {processed_file}")
            print(f"📁 Created compact version: {compact_file}")
            return True
            
        except Exception as e:
            print(f"❌ Error processing static data: {e}")
            return False
    
    print("❌ No static data found. Cannot proceed without Supabase credentials.")
    return False

def generate_geojson_file():
    """Generate a static GeoJSON file for the web app"""
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_KEY")
    
    # Check if Supabase credentials are available
    if not supabase_url or not supabase_key:
        print("⚠️  Supabase credentials not found in environment variables")
        print("📁 Checking for existing static data...")
        return fallback_to_static_data()
    
    supabase: Client = create_client(supabase_url, supabase_key)
    
    print("🔄 Generating GeoJSON for web app...")
    
    try:
        # Get fountain data with coordinates from the fountains table
        fountains_result = supabase.table("fountains").select("""
            id, original_mapid, name, lat, lon, neighborhood, location_description, 
            type, maintainer, operational_season, pet_friendly
        """).execute()
        fountains_data = {f['id']: f for f in fountains_result.data}
        
        # Get all ratings for each fountain
        ratings_result = supabase.table("ratings").select("*").execute()
        ratings_by_fountain = {}
        for rating in ratings_result.data:
            fountain_id = rating['fountain_id']
            if fountain_id not in ratings_by_fountain:
                ratings_by_fountain[fountain_id] = []
            ratings_by_fountain[fountain_id].append(rating)
        
        # Get Instagram posts
        instagram_result = supabase.table("instagram_posts").select("*").execute()
        instagram_by_fountain = {}
        for post in instagram_result.data:
            fountain_id = post['fountain_id']
            if fountain_id not in instagram_by_fountain:
                instagram_by_fountain[fountain_id] = []
            instagram_by_fountain[fountain_id].append(post)
        
        print(f"📊 Found {len(fountains_data)} fountains")
        
        # Convert to GeoJSON format
        features = []
        
        for fountain_id, fountain in fountains_data.items():
            # Skip fountains without coordinates
            if not fountain.get('lat') or not fountain.get('lon'):
                continue
                
            # Get ratings and Instagram posts for this fountain
            fountain_ratings = ratings_by_fountain.get(fountain_id, [])
            fountain_instagram = instagram_by_fountain.get(fountain_id, [])
            
            # Get latest rating details
            latest_rating = None
            if fountain_ratings:
                latest_rating = max(fountain_ratings, key=lambda x: x.get('visit_date', '1900-01-01') if x.get('visit_date') else '1900-01-01')
            
            # Format Instagram posts
            instagram_posts = []
            for post in fountain_instagram:
                instagram_posts.append({
                    "url": post['post_url'],
                    "caption": post.get('caption'),
                    "date_posted": post.get('date_posted'),
                    "rating_id": post.get('rating_id')
                })
            
            feature = {
                "type": "Feature",
                "geometry": {
                    "type": "Point",
                    "coordinates": [float(fountain['lon']), float(fountain['lat'])]
                },
                "properties": {
                    "id": fountain.get('original_mapid') or fountain_id,
                    "name": fountain.get('name') or 'Unnamed Fountain',
                    "city": "Vancouver" if fountain.get('original_mapid', '').startswith('DFPB') else "Burnaby",
                    "neighborhood": fountain.get('neighborhood'),
                    "location": fountain.get('location_description'),
                    "type": fountain.get('type'),
                    "maintainer": fountain.get('maintainer'),
                    "operational_season": fountain.get('operational_season'),
                    "currently_operational": fountain.get('currently_operational'),
                    "pet_friendly": fountain.get('pet_friendly'),
                    
                    # Rating summary data
                    "avg_rating": fountain.get('avg_rating'),
                    "rating_count": fountain.get('rating_count'),
                    "last_visited": fountain.get('last_visited'),
                    
                    # Latest rating data (for backward compatibility)
                    "rating": latest_rating.get('overall_rating') if latest_rating else None,
                    "flow": latest_rating.get('flow_pressure') if latest_rating else None,
                    "temp": latest_rating.get('temperature') if latest_rating else None,
                    "drainage": latest_rating.get('drainage') if latest_rating else None,
                    "caption": latest_rating.get('notes') if latest_rating else None,
                    "water_quality": latest_rating.get('water_quality') if latest_rating else None,
                    
                    # Instagram data
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
        supabase_url = os.getenv("SUPABASE_URL")
        supabase_key = os.getenv("SUPABASE_KEY")
        
        if supabase_url and supabase_key:
            # Full setup with Supabase
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
            # Static data mode
            print("\n🎉 Static data ready for deployment!")
            print("\nDeployment mode: Using existing fountain data")
            print("✅ Your web app will work with the current static data")
    else:
        print("\n❌ Failed to generate GeoJSON. Check your database connection or static data files.")
