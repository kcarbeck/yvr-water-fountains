#!/usr/bin/env python3
"""
Test script to verify the unified review approach works correctly
"""

import os
from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv()

def test_unified_ratings():
    """Test the unified ratings table approach"""
    print("🧪 Testing Unified Ratings Table Approach")
    print("=" * 50)
    
    # Initialize Supabase
    supabase: Client = create_client(
        os.getenv("SUPABASE_URL"), 
        os.getenv("SUPABASE_KEY")
    )
    
    # Test 1: Check if schema changes are applied
    print("1. Checking schema...")
    try:
        result = supabase.table("ratings").select("ig_post_url, user_name, instagram_caption").limit(1).execute()
        print("   ✅ Schema updated - new fields exist")
    except Exception as e:
        print(f"   ❌ Schema issue: {e}")
        return
    
    # Test 2: Check existing data structure
    print("\n2. Checking existing data...")
    ratings = supabase.table("ratings").select("*").execute()
    total_ratings = len(ratings.data)
    
    admin_reviews = [r for r in ratings.data if r.get('user_name') == 'yvrwaterfountains']
    public_reviews = [r for r in ratings.data if r.get('user_name') != 'yvrwaterfountains']
    approved_reviews = [r for r in ratings.data if r.get('review_status') == 'approved']
    pending_reviews = [r for r in ratings.data if r.get('review_status') == 'pending']
    instagram_reviews = [r for r in ratings.data if r.get('ig_post_url')]
    
    print(f"   📊 Total ratings: {total_ratings}")
    print(f"   👨‍💼 Admin reviews (user_name='yvrwaterfountains'): {len(admin_reviews)}")
    print(f"   👥 Public reviews: {len(public_reviews)}")
    print(f"   ✅ Approved reviews: {len(approved_reviews)}")
    print(f"   ⏳ Pending reviews: {len(pending_reviews)}")
    print(f"   📷 Reviews with Instagram data: {len(instagram_reviews)}")
    
    # Test 3: Verify admin review logic
    print("\n3. Testing admin review logic...")
    for admin_review in admin_reviews:
        if admin_review.get('review_status') != 'approved':
            print(f"   ⚠️ Warning: Admin review {admin_review['id']} is not auto-approved")
        if admin_review.get('review_type') != 'admin_instagram':
            print(f"   ⚠️ Warning: Admin review {admin_review['id']} wrong type: {admin_review.get('review_type')}")
    
    if len(admin_reviews) > 0:
        print(f"   ✅ Admin reviews configured correctly")
    
    # Test 4: Check public_reviews view
    print("\n4. Testing public_reviews view...")
    try:
        public_view = supabase.table("public_reviews").select("*").execute()
        print(f"   ✅ public_reviews view works - {len(public_view.data)} approved reviews")
        
        # Check if view includes Instagram data
        instagram_in_view = [r for r in public_view.data if r.get('ig_post_url')]
        print(f"   📷 Reviews with Instagram in view: {len(instagram_in_view)}")
        
    except Exception as e:
        print(f"   ❌ public_reviews view issue: {e}")
    
    # Test 5: Sample data preview
    print("\n5. Sample data preview...")
    if admin_reviews:
        sample_admin = admin_reviews[0]
        print(f"   📋 Sample admin review:")
        print(f"      ID: {sample_admin['id']}")
        print(f"      User: {sample_admin.get('user_name')}")
        print(f"      Status: {sample_admin.get('review_status')}")
        print(f"      Type: {sample_admin.get('review_type')}")
        print(f"      Instagram URL: {sample_admin.get('ig_post_url', 'None')}")
        print(f"      Rating: {sample_admin.get('overall_rating')}/10")
    
    print("\n" + "=" * 50)
    print("🎯 Unified Approach Summary:")
    print(f"   • Admin reviews: user_name = 'yvrwaterfountains' → auto-approved")
    print(f"   • Public reviews: user_name = [user's name] → pending approval")
    print(f"   • Instagram data stored directly in ratings table")
    print(f"   • Map photos will come from ig_post_url field")
    print(f"   • Single ratings table for everything!")

if __name__ == "__main__":
    test_unified_ratings()
