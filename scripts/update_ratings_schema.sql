-- Update ratings table to support unified review approach
-- Add Instagram fields directly to ratings table

-- Add Instagram-related columns to ratings table
ALTER TABLE ratings ADD COLUMN IF NOT EXISTS ig_post_url TEXT;
ALTER TABLE ratings ADD COLUMN IF NOT EXISTS instagram_caption TEXT;
ALTER TABLE ratings ADD COLUMN IF NOT EXISTS instagram_post_id TEXT;

-- Add indexes for the new fields
CREATE INDEX IF NOT EXISTS idx_ratings_instagram_url ON ratings(ig_post_url);
CREATE INDEX IF NOT EXISTS idx_ratings_reviewer_name ON ratings(user_name);

-- Update the review status check constraint to ensure proper values
ALTER TABLE ratings DROP CONSTRAINT IF EXISTS ratings_review_status_check;
ALTER TABLE ratings ADD CONSTRAINT ratings_review_status_check 
    CHECK (review_status IN ('pending', 'approved', 'rejected'));

-- Update the review type check constraint 
ALTER TABLE ratings DROP CONSTRAINT IF EXISTS ratings_review_type_check;
ALTER TABLE ratings ADD CONSTRAINT ratings_review_type_check 
    CHECK (review_type IN ('admin_instagram', 'public_submission'));

-- Create a function to extract Instagram post ID from URL
CREATE OR REPLACE FUNCTION extract_instagram_post_id(post_url TEXT)
RETURNS TEXT AS $$
BEGIN
    IF post_url IS NULL OR post_url = '' THEN
        RETURN NULL;
    END IF;
    
    -- Extract post ID from Instagram URL pattern /p/POST_ID/
    RETURN (regexp_match(post_url, '/p/([A-Za-z0-9_-]+)'))[1];
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-populate instagram_post_id when ig_post_url is set
CREATE OR REPLACE FUNCTION update_instagram_post_id()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.ig_post_url IS NOT NULL AND NEW.ig_post_url != '' THEN
        NEW.instagram_post_id = extract_instagram_post_id(NEW.ig_post_url);
    ELSE
        NEW.instagram_post_id = NULL;
    END IF;
    
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for Instagram post ID extraction
DROP TRIGGER IF EXISTS tr_ratings_instagram_post_id ON ratings;
CREATE TRIGGER tr_ratings_instagram_post_id
    BEFORE INSERT OR UPDATE ON ratings
    FOR EACH ROW
    EXECUTE FUNCTION update_instagram_post_id();

-- Create view for approved reviews with Instagram data for the website
CREATE OR REPLACE VIEW public_reviews AS
SELECT 
    r.id,
    r.fountain_id,
    f.original_mapid,
    f.name as fountain_name,
    f.neighborhood,
    f.lat,
    f.lon,
    r.overall_rating,
    r.water_quality,
    r.flow_pressure,
    r.temperature,
    r.drainage,
    r.accessibility,
    r.notes,
    r.user_name,
    r.visit_date,
    r.review_type,
    r.ig_post_url,
    r.instagram_caption,
    r.instagram_post_id,
    r.created_at
FROM ratings r
JOIN fountains f ON r.fountain_id = f.id
WHERE r.review_status = 'approved'
ORDER BY r.visit_date DESC, r.created_at DESC;

SELECT 'Unified ratings schema updated successfully!' as result;
