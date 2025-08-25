#!/usr/bin/env python3
"""
Netlify build script for YVR Water Fountains
This script handles data generation with fallback to static data
"""

import os
import sys
from pathlib import Path

def check_environment():
    """Check if we're running in Netlify environment"""
    is_netlify = os.getenv('NETLIFY') == 'true'
    build_id = os.getenv('BUILD_ID')
    deploy_url = os.getenv('DEPLOY_URL')
    
    print(f"🌐 Build Environment:")
    print(f"   Netlify: {'Yes' if is_netlify else 'No'}")
    if build_id:
        print(f"   Build ID: {build_id}")
    if deploy_url:
        print(f"   Deploy URL: {deploy_url}")
    
    return is_netlify

def check_supabase_credentials():
    """Check if Supabase credentials are available"""
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_KEY")
    
    print(f"🔐 Supabase Credentials:")
    print(f"   URL: {'✅ Available' if supabase_url else '❌ Missing'}")
    print(f"   Key: {'✅ Available' if supabase_key else '❌ Missing'}")
    
    return bool(supabase_url and supabase_key)

def check_static_data():
    """Check if static data files exist"""
    docs_dir = Path(__file__).parent.parent / "docs"
    data_dir = docs_dir / "data"
    
    if not data_dir.exists():
        print("❌ Data directory not found")
        return False
    
    geojson_files = list(data_dir.glob("*.geojson"))
    print(f"📁 Static Data:")
    print(f"   Data directory: {data_dir}")
    print(f"   GeoJSON files: {len(geojson_files)}")
    
    for file in geojson_files:
        size_mb = file.stat().st_size / (1024 * 1024)
        print(f"   - {file.name} ({size_mb:.1f} MB)")
    
    return len(geojson_files) > 0

def run_data_generation():
    """Run the data generation script"""
    print("\n🔄 Running data generation...")
    
    # Import and run the generation function
    sys.path.insert(0, str(Path(__file__).parent))
    
    try:
        from generate_geojson_api import generate_geojson_file
        success = generate_geojson_file()
        
        if success:
            print("✅ Data generation completed successfully")
        else:
            print("❌ Data generation failed")
            
        return success
        
    except Exception as e:
        print(f"❌ Error during data generation: {e}")
        return False

def main():
    """Main build process"""
    print("🚀 Starting Netlify build for YVR Water Fountains")
    print("=" * 60)
    
    # Check environment
    is_netlify = check_environment()
    print()
    
    # Check credentials
    has_supabase = check_supabase_credentials()
    print()
    
    # Check static data
    has_static_data = check_static_data()
    print()
    
    # Determine build strategy
    if has_supabase:
        print("📊 Strategy: Generate fresh data from Supabase")
        success = run_data_generation()
    elif has_static_data:
        print("⚠️  WARNING: Using static data fallback!")
        print("🔧 For production, set SUPABASE_URL and SUPABASE_KEY in Netlify environment variables")
        print("📁 Strategy: Use existing static data (fallback mode)")
        success = run_data_generation()  # Will use fallback internally
    else:
        print("❌ Strategy: Cannot proceed - no data source available")
        print("\nTo fix this issue:")
        print("1. RECOMMENDED: Set SUPABASE_URL and SUPABASE_KEY environment variables in Netlify")
        print("   - Go to Netlify Dashboard > Site Settings > Environment Variables")
        print("   - Add SUPABASE_URL and SUPABASE_KEY from your Supabase project")
        print("2. FALLBACK: Ensure static GeoJSON files exist in docs/data/ directory")
        success = False
    
    print("\n" + "=" * 60)
    if success:
        print("🎉 Build completed successfully!")
        print("✅ Your web app is ready for deployment")
    else:
        print("❌ Build failed!")
        print("🔍 Check the logs above for more details")
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
