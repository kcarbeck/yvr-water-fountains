# YVR Water Fountains Review Workflow Guide

## Overview

This guide explains the complete review submission and moderation workflow for the YVR Water Fountains project, including how reviews are submitted, moderated, and published.

## Review Types

### 1. Admin Reviews (Instagram-based)
- **Form**: `admin_review_form.html`
- **Purpose**: Submit reviews with Instagram post integration
- **Status**: Auto-approved (goes directly to database)
- **Features**: Includes Instagram URL, post embedding, and verification

### 2. Public Reviews (User submissions)
- **Form**: `public_review_form.html`
- **Purpose**: Allow public users to submit reviews
- **Status**: Requires moderation (starts as "pending")
- **Features**: Name, email (optional), ratings without Instagram requirement

## Database Tables

### Core Tables

1. **`fountains`** - Main fountain data
   - `id` (UUID, primary key)
   - `name`, `location_note`, `lat`, `lon`
   - `original_mapid` (links to legacy data)
   - `in_operation`, `pet_friendly`

2. **`ratings`** - All review data
   - `id` (UUID, primary key)
   - `fountain_id` (FK to fountains)
   - `overall_rating`, `water_quality`, `flow_pressure`, `temperature`, `drainage`, `accessibility`
   - `notes`, `visit_date`
   - **Moderation fields**:
     - `reviewer_name`, `reviewer_email`
     - `review_status` ('pending', 'approved', 'rejected')
     - `review_type` ('instagram', 'user_submission')
     - `is_verified` (boolean)
     - `moderation_notes`, `approved_by`, `approved_at`

3. **`instagram_posts`** - Instagram integration
   - `id` (UUID, primary key)
   - `fountain_id` (FK to fountains)
   - `rating_id` (FK to ratings)
   - `post_url`, `post_id` (auto-extracted)
   - `caption`, `date_posted`

### Views for Easy Access

1. **`fountain_reviews`** - All approved reviews with Instagram data
2. **`fountain_rating_summary`** - Aggregated ratings per fountain

## Complete Workflow

### Admin Review Submission

1. **Form Submission** (`admin_review_form.html`)
   - Select fountain from interactive map
   - Enter Instagram post URL
   - Provide ratings (1-10 scale)
   - Add visit date and notes

2. **Processing** 
   - Form generates Python command
   - Command: `python scripts/rating_helper.py add_full_rating [args]`
   - Status: **Auto-approved** (`review_status = 'approved'`)
   - Instagram post data saved to `instagram_posts` table

3. **Publication**
   - Immediately available in database views
   - Included in next GeoJSON generation

### Public Review Submission

1. **Form Submission** (`public_review_form.html`)
   - Select fountain from interactive map
   - Enter personal information (name required, email optional)
   - Provide ratings (1-10 scale)
   - Add visit date and notes

2. **Processing**
   - Form generates Python command
   - Command: `python scripts/rating_helper.py add_full_rating [args]`
   - Status: **Pending moderation** (`review_status = 'pending'`)
   - Requires manual approval

3. **Moderation** (`moderation_dashboard.html`)
   - Review appears in "Pending Reviews" tab
   - Moderator can approve or reject
   - Rejection requires reason and optional notes

4. **Publication**
   - Only approved reviews appear in public views
   - Included in next GeoJSON generation

## Internal Team Instructions

### Daily Moderation Tasks

1. **Check Pending Reviews**
   ```bash
   python scripts/rating_helper.py pending
   ```

2. **Approve a Review**
   ```bash
   python scripts/rating_helper.py approve [REVIEW_ID]
   ```

3. **Reject a Review**
   ```bash
   python scripts/rating_helper.py reject [REVIEW_ID] "Reason for rejection"
   ```

### Adding Admin Reviews

1. **Via Form**: Use `admin_review_form.html` (recommended)
2. **Via Command Line**:
   ```bash
   python scripts/rating_helper.py add_full_rating "MAPID" 8 7 9 6 5 8 "Great fountain!" True "2024-12-10" "https://instagram.com/p/ABC123/" "Instagram caption"
   ```

### Publishing Updates

After approving reviews, update the public data:

1. **Generate Updated GeoJSON**
   ```bash
   python scripts/generate_geojson_api.py
   ```

2. **Deploy to Production** (if using Netlify)
   ```bash
   python scripts/deploy_prep.py
   ```

## Instagram Integration

### How Instagram Posts Are Linked

1. **Admin reviews** can include Instagram URLs
2. **Post ID extraction**: Automatic from URL pattern `/p/[POST_ID]/`
3. **Storage**: Separate `instagram_posts` table linked to reviews
4. **Display**: Posts can be embedded in frontend using post ID

### Instagram Post Fields

- `post_url`: Full Instagram URL
- `post_id`: Extracted ID (e.g., "DJpu8cbSfTE")
- `caption`: Either from Instagram or review notes
- `date_posted`: Visit date
- `has_media`: Always true for Instagram posts
- `post_type`: 'post', 'reel', or 'story'

## Current System Gaps & Improvements Needed

### 🚨 Critical Issues

1. **No Direct Database Submission**: Forms generate Python commands instead of submitting directly
2. **No Real Moderation Dashboard**: Dashboard shows mock data only
3. **Manual Publication**: No automated pipeline from approval to publication

### 🔧 Required Fixes

1. **Backend API Integration**
   - Add Supabase configuration to forms
   - Implement direct database submission
   - Add proper error handling

2. **Real Moderation Dashboard**
   - Connect to actual Supabase data
   - Implement real approve/reject functionality
   - Add proper authentication

3. **Automated Publication Pipeline**
   - Trigger GeoJSON regeneration on approval
   - Implement webhook or scheduled updates

### 📋 Immediate Action Items

For the internal team to make the system fully functional:

1. **Set up Supabase credentials**
   - Add `SUPABASE_URL` and `SUPABASE_ANON_KEY` to forms
   - Test database connectivity

2. **Update form JavaScript**
   - Replace Python command generation with direct API calls
   - Add proper form validation and feedback

3. **Connect moderation dashboard**
   - Link to real pending reviews from database
   - Implement approve/reject API calls

4. **Set up publication pipeline**
   - Create automated script to regenerate data files
   - Schedule or trigger on moderation actions

## Environment Setup

### Required Environment Variables

```bash
SUPABASE_URL=your_supabase_project_url
SUPABASE_KEY=your_supabase_anon_key
```

### Database Schema

Ensure the enhanced schema is applied:
```bash
# Apply the enhanced ratings schema
psql -f supabase/enhanced_ratings_schema.sql
```

## Testing the Workflow

### Test Public Review Submission

1. Open `public_review_form.html`
2. Select a fountain
3. Fill required fields
4. Submit and verify command generation

### Test Admin Review Submission

1. Open `admin_review_form.html`
2. Select a fountain
3. Add Instagram URL
4. Fill ratings and submit

### Test Moderation

1. Open `moderation_dashboard.html`
2. Check pending reviews section
3. Test approve/reject buttons (currently mock)

## File Structure Reference

```
yvr-water-fountains/
├── admin_review_form.html          # Admin Instagram review form
├── public_review_form.html         # Public user review form
├── moderation_dashboard.html       # Review moderation interface
├── docs/
│   ├── admin_review_form.html      # Deployed admin form
│   ├── public_review_form.html     # Deployed public form
│   ├── moderation_dashboard.html   # Deployed moderation dashboard
│   └── data/
│       └── fountains_processed.geojson  # Published fountain data
├── scripts/
│   ├── rating_helper.py            # Review management script
│   ├── generate_geojson_api.py     # Data publication script
│   └── deploy_prep.py              # Deployment preparation
└── supabase/
    ├── enhanced_ratings_schema.sql # Full database schema
    └── schema.sql                  # Basic schema
```

---

*Last updated: December 2024*
*For questions or issues, contact the development team.*
