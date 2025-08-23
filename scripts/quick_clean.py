#!/usr/bin/env python3
"""
Quick database cleanup using raw SQL
"""

import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

def quick_clean():
    """Clean database using SQL commands"""
    supabase: Client = create_client(
        os.getenv("SUPABASE_URL"), 
        os.getenv("SUPABASE_KEY")
    )
    
    print("🧹 Quick cleaning database...")
    
    try:
        # Use raw SQL to truncate tables (fastest way)
        supabase.rpc('exec_sql', {'sql': 'TRUNCATE TABLE instagram_posts CASCADE'}).execute()
        print("✅ Cleared Instagram posts")
        
        supabase.rpc('exec_sql', {'sql': 'TRUNCATE TABLE ratings CASCADE'}).execute()
        print("✅ Cleared ratings")
        
        supabase.rpc('exec_sql', {'sql': 'TRUNCATE TABLE fountains CASCADE'}).execute()
        print("✅ Cleared fountains")
        
        print("🎉 Database cleaned!")
        return True
        
    except Exception as e:
        print(f"❌ SQL truncate failed: {e}")
        print("🔄 Falling back to manual deletion...")
        
        # Fallback: delete all records manually
        try:
            # Get counts first
            instagram_count = len(supabase.table("instagram_posts").select("id").execute().data)
            ratings_count = len(supabase.table("ratings").select("id").execute().data)
            fountains_count = len(supabase.table("fountains").select("id").execute().data)
            
            print(f"📊 Found {instagram_count} Instagram posts, {ratings_count} ratings, {fountains_count} fountains")
            
            # Delete with a filter that matches everything
            if instagram_count > 0:
                # Delete posts where id is not null (i.e., all of them)
                supabase.table("instagram_posts").delete().not_.is_("id", "null").execute()
                print(f"✅ Deleted {instagram_count} Instagram posts")
            
            if ratings_count > 0:
                supabase.table("ratings").delete().not_.is_("id", "null").execute()
                print(f"✅ Deleted {ratings_count} ratings")
            
            if fountains_count > 0:
                supabase.table("fountains").delete().not_.is_("id", "null").execute()
                print(f"✅ Deleted {fountains_count} fountains")
            
            return True
            
        except Exception as e2:
            print(f"❌ Manual deletion also failed: {e2}")
            return False

if __name__ == "__main__":
    if quick_clean():
        print("\n🔄 Now running ETL to reload clean data...")
        
        # Run ETL
        from etl_pipeline import FountainETL
        
        etl = FountainETL()
        etl.run_full_etl()
        
        # Verify
        supabase = create_client(os.getenv("SUPABASE_URL"), os.getenv("SUPABASE_KEY"))
        fountains = supabase.table("fountains").select("id").execute()
        
        print(f"\n✅ Reloaded {len(fountains.data)} fountains")
        
        if 400 <= len(fountains.data) <= 450:
            print("🎉 Fountain count looks correct now!")
            print("\nNext steps:")
            print("1. python scripts/generate_geojson_api.py")
            print("2. Refresh your web app")
        else:
            print(f"⚠️  Fountain count ({len(fountains.data)}) still looks off")
    else:
        print("❌ Cleanup failed")
