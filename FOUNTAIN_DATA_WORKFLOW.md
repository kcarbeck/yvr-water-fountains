# YVR Water Fountains - Data Management Workflow

## Overview
The YVR Water Fountains system now has a **stable fountain database** with a proper review management workflow.

## Database Structure

### Stable Fountain Base (431 records)
- **Source**: 278 Vancouver + 151 Burnaby + 2 duplicates with existing ratings
- **Status**: Static data that should rarely change
- **Management**: One-time setup, no regular updates needed

### Dynamic Review Data
- **Ratings**: User and admin reviews linked to fountain IDs
- **Instagram Posts**: Social media posts linked to fountains and ratings  
- **Status**: Updated regularly as new reviews come in

## Workflows

### 1. Public Review Submission
1. User visits `public_review_form.html`
2. User selects fountain by clicking map or searching by ID
3. User fills out rating form (1-10 scale across multiple criteria)
4. Review submitted with `review_status: "pending"` and `review_type: "user_submission"`
5. Review appears in moderation dashboard for approval

### 2. Admin Instagram Review Submission  
1. Admin visits `admin_review_form.html`
2. Admin selects fountain by clicking map or searching by ID
3. Admin enters Instagram post URL and caption
4. Admin fills out rating form
5. Review submitted with `review_status: "approved"` and `review_type: "instagram"`
6. Review goes live immediately (no moderation needed)

### 3. Review Moderation
1. Moderator visits `moderation_dashboard.html`
2. Pending public reviews are displayed with fountain info and ratings
3. Moderator can approve or reject with reason
4. Approved reviews go live immediately
5. Instagram reviews from admin are pre-approved

## Scripts and Maintenance

### Data Generation
- `generate_geojson_api.py`: Creates web app data from Supabase (431 fountains with reviews)
- Runs automatically on Netlify deployment

### Review Management  
- `review_etl.py`: Handles ONLY reviews/ratings (never touches fountain data)
- Safe to run multiple times
- Use this instead of the old `etl_pipeline.py`

### One-Time Setup (Already Complete)
- ✅ 431 fountains loaded and cleaned
- ✅ Existing ratings migrated
- ✅ Instagram posts linked
- ✅ Review forms updated with map selection

## Key Principles

1. **Fountain Stability**: The ~431 fountain records are static and should not be duplicated
2. **Review Linking**: All new reviews link to existing fountain UUIDs via `fountain_id`
3. **No Fountain Duplication**: ETL processes should never add new fountain records
4. **Foreign Key Integrity**: Reviews properly reference fountains without causing cascade issues

## File Structure

### Web App (docs/)
- `map.html`: Main fountain map
- `public_review_form.html`: Public review submission
- `admin_review_form.html`: Admin Instagram review submission  
- `moderation_dashboard.html`: Review approval interface

### Data Management (scripts/)
- `review_etl.py`: Review-only ETL (recommended)
- `generate_geojson_api.py`: API generation from Supabase
- `etl_pipeline.py`: Full ETL (avoid using - may create duplicates)

### Database Status
- **Fountains**: 431 stable records
- **Ratings**: 12 existing ratings from Instagram reviews
- **Instagram Posts**: 3 posts linked to fountains

## Next Steps

The system is now ready for deployment with:
- ✅ Stable fountain data (431 records)
- ✅ Working review submission forms
- ✅ Map-based fountain selection
- ✅ Moderation dashboard
- ✅ Automatic approval for admin reviews
- ✅ Public review moderation workflow