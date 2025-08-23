#!/usr/bin/env python3
"""
Prepare the project for deployment
- Generate fresh GeoJSON data
- Optimize files for production
- Validate everything is working
"""

import os
import json
import gzip
from pathlib import Path
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

def generate_fresh_data():
    """Generate the latest GeoJSON data"""
    print("🔄 Generating fresh fountain data...")
    
    try:
        from generate_geojson_api import generate_geojson_file
        success = generate_geojson_file()
        
        if success:
            print("✅ GeoJSON data generated successfully")
            return True
        else:
            print("❌ Failed to generate GeoJSON data")
            return False
            
    except Exception as e:
        print(f"❌ Error generating data: {e}")
        return False

def optimize_geojson():
    """Create optimized versions of GeoJSON files"""
    print("⚡ Optimizing GeoJSON files...")
    
    docs_dir = Path(__file__).parent.parent / "docs"
    data_dir = docs_dir / "data"
    
    # Read the main GeoJSON file
    geojson_file = data_dir / "fountains_processed.geojson"
    
    if not geojson_file.exists():
        print("❌ GeoJSON file not found")
        return False
    
    try:
        with open(geojson_file, 'r') as f:
            data = json.load(f)
        
        # Create a minified version
        minified_file = data_dir / "fountains.min.geojson"
        with open(minified_file, 'w') as f:
            json.dump(data, f, separators=(',', ':'))
        
        # Create a gzipped version for even better compression
        gzipped_file = data_dir / "fountains.min.geojson.gz"
        with gzip.open(gzipped_file, 'wt') as f:
            json.dump(data, f, separators=(',', ':'))
        
        # Report file sizes
        original_size = geojson_file.stat().st_size
        minified_size = minified_file.stat().st_size
        gzipped_size = gzipped_file.stat().st_size
        
        print(f"   Original: {original_size:,} bytes")
        print(f"   Minified: {minified_size:,} bytes ({100-minified_size/original_size*100:.1f}% smaller)")
        print(f"   Gzipped:  {gzipped_size:,} bytes ({100-gzipped_size/original_size*100:.1f}% smaller)")
        
        return True
        
    except Exception as e:
        print(f"❌ Error optimizing files: {e}")
        return False

def validate_deployment():
    """Validate that everything is ready for deployment"""
    print("🔍 Validating deployment readiness...")
    
    docs_dir = Path(__file__).parent.parent / "docs"
    
    # Check required files exist
    required_files = [
        docs_dir / "index.html",
        docs_dir / "table.html", 
        docs_dir / "data" / "fountains_processed.geojson"
    ]
    
    missing_files = []
    for file_path in required_files:
        if not file_path.exists():
            missing_files.append(str(file_path))
    
    if missing_files:
        print("❌ Missing required files:")
        for file in missing_files:
            print(f"   - {file}")
        return False
    
    # Check GeoJSON data quality
    try:
        geojson_file = docs_dir / "data" / "fountains_processed.geojson"
        with open(geojson_file, 'r') as f:
            data = json.load(f)
        
        feature_count = len(data.get('features', []))
        
        if feature_count < 400:
            print(f"⚠️  Low fountain count: {feature_count} (expected ~429)")
            return False
        elif feature_count > 500:
            print(f"⚠️  High fountain count: {feature_count} (expected ~429)")
            return False
        else:
            print(f"✅ Fountain count looks good: {feature_count}")
        
        # Check coordinate ranges
        lats = []
        lons = []
        for feature in data['features']:
            coords = feature['geometry']['coordinates']
            lons.append(coords[0])
            lats.append(coords[1])
        
        lat_range = (min(lats), max(lats))
        lon_range = (min(lons), max(lons))
        
        # Vancouver/Burnaby should be roughly in these ranges
        if not (49.0 < lat_range[0] < 49.5 and 49.0 < lat_range[1] < 49.5):
            print(f"⚠️  Latitude range seems off: {lat_range}")
            return False
        
        if not (-123.5 < lon_range[0] < -122.5 and -123.5 < lon_range[1] < -122.5):
            print(f"⚠️  Longitude range seems off: {lon_range}")
            return False
        
        print(f"✅ Coordinates look good: lat {lat_range[0]:.3f} to {lat_range[1]:.3f}, lon {lon_range[0]:.3f} to {lon_range[1]:.3f}")
        
    except Exception as e:
        print(f"❌ Error validating GeoJSON: {e}")
        return False
    
    # Check HTML files have proper titles and structure
    try:
        index_file = docs_dir / "index.html"
        with open(index_file, 'r') as f:
            html_content = f.read()
        
        if "YVR Water Fountains" not in html_content:
            print("⚠️  index.html missing proper title")
        
        if "leaflet" not in html_content.lower():
            print("⚠️  index.html missing Leaflet.js")
        
        if "fountains_processed.geojson" not in html_content:
            print("⚠️  index.html not loading fountain data")
        
        print("✅ HTML files look good")
        
    except Exception as e:
        print(f"❌ Error checking HTML files: {e}")
        return False
    
    return True

def create_robots_txt():
    """Create robots.txt for SEO"""
    docs_dir = Path(__file__).parent.parent / "docs"
    robots_file = docs_dir / "robots.txt"
    
    robots_content = """User-agent: *
Allow: /
Disallow: /data/

Sitemap: https://yvr-water-fountains.netlify.app/sitemap.xml
"""
    
    with open(robots_file, 'w') as f:
        f.write(robots_content)
    
    print("✅ Created robots.txt")

def create_sitemap():
    """Create basic sitemap.xml"""
    docs_dir = Path(__file__).parent.parent / "docs"
    sitemap_file = docs_dir / "sitemap.xml"
    
    sitemap_content = """<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://yvr-water-fountains.netlify.app/</loc>
    <lastmod>2025-01-01</lastmod>
    <priority>1.0</priority>
  </url>
  <url>
    <loc>https://yvr-water-fountains.netlify.app/table.html</loc>
    <lastmod>2025-01-01</lastmod>
    <priority>0.8</priority>
  </url>
</urlset>
"""
    
    with open(sitemap_file, 'w') as f:
        f.write(sitemap_content)
    
    print("✅ Created sitemap.xml")

def main():
    """Main deployment preparation function"""
    print("🚀 PREPARING FOR DEPLOYMENT")
    print("=" * 50)
    
    steps = [
        ("Generate fresh data", generate_fresh_data),
        ("Optimize files", optimize_geojson),
        ("Validate deployment", validate_deployment),
        ("Create robots.txt", create_robots_txt),
        ("Create sitemap", create_sitemap)
    ]
    
    for step_name, step_func in steps:
        print(f"\n📋 {step_name}...")
        try:
            success = step_func()
            if not success and step_func in [generate_fresh_data, validate_deployment]:
                print(f"❌ Critical step '{step_name}' failed. Aborting.")
                return False
        except Exception as e:
            print(f"❌ Error in '{step_name}': {e}")
            if step_func in [generate_fresh_data, validate_deployment]:
                return False
    
    print("\n" + "=" * 50)
    print("🎉 DEPLOYMENT READY!")
    print("\nNext steps:")
    print("1. Commit changes: git add . && git commit -m 'Prepare for deployment'")
    print("2. Push to GitHub: git push origin main")
    print("3. Deploy to Netlify (see DEPLOYMENT.md)")
    print("4. Test live site functionality")
    
    return True

if __name__ == "__main__":
    main()
