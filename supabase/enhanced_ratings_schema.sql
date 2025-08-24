-- Enhanced schema for multi-review system with Instagram integration
-- This builds on the existing schema to support multiple reviews per fountain

-- First ensure the instagram_posts table exists with proper structure
CREATE TABLE IF NOT EXISTS instagram_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fountain_id UUID REFERENCES fountains(id) ON DELETE CASCADE,
    rating_id UUID REFERENCES ratings(id) ON DELETE SET NULL,
    post_url TEXT UNIQUE NOT NULL,
    post_id TEXT, -- Extract Instagram post ID for embedding
    caption TEXT,
    date_posted DATE,
    has_media BOOLEAN DEFAULT true,
    media_count INTEGER DEFAULT 1,
    post_type VARCHAR(20) DEFAULT 'post', -- 'post', 'reel', 'story'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_instagram_posts_fountain_id ON instagram_posts(fountain_id);
CREATE INDEX IF NOT EXISTS idx_instagram_posts_rating_id ON instagram_posts(rating_id);
CREATE INDEX IF NOT EXISTS idx_instagram_posts_date_posted ON instagram_posts(date_posted DESC);

-- Enhance ratings table with additional fields for public reviews
ALTER TABLE ratings 
ADD COLUMN IF NOT EXISTS reviewer_name VARCHAR(100) DEFAULT 'YVR Water Fountains',
ADD COLUMN IF NOT EXISTS reviewer_email VARCHAR(255),
ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT true, -- Admin reviews are auto-verified
ADD COLUMN IF NOT EXISTS review_status VARCHAR(20) DEFAULT 'approved', -- 'pending', 'approved', 'rejected'
ADD COLUMN IF NOT EXISTS review_type VARCHAR(20) DEFAULT 'instagram', -- 'instagram', 'user_submission'
ADD COLUMN IF NOT EXISTS moderation_notes TEXT,
ADD COLUMN IF NOT EXISTS approved_by VARCHAR(100),
ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP;

-- Add indexes for ratings
CREATE INDEX IF NOT EXISTS idx_ratings_fountain_id ON ratings(fountain_id);
CREATE INDEX IF NOT EXISTS idx_ratings_status ON ratings(review_status);
CREATE INDEX IF NOT EXISTS idx_ratings_type ON ratings(review_type);
CREATE INDEX IF NOT EXISTS idx_ratings_visit_date ON ratings(visit_date DESC);

-- Create a view for approved ratings with Instagram data
CREATE OR REPLACE VIEW fountain_reviews AS
SELECT 
    r.id as review_id,
    r.fountain_id,
    f.name as fountain_name,
    f.original_mapid,
    r.overall_rating,
    r.water_quality,
    r.flow_pressure,
    r.temperature,
    r.drainage,
    r.accessibility,
    r.notes,
    r.reviewer_name,
    r.visit_date,
    r.review_type,
    r.created_at,
    -- Instagram post data
    ig.post_url,
    ig.post_id,
    ig.caption as ig_caption,
    ig.has_media,
    ig.media_count,
    ig.post_type
FROM ratings r
LEFT JOIN fountains f ON r.fountain_id = f.id
LEFT JOIN instagram_posts ig ON r.id = ig.rating_id
WHERE r.review_status = 'approved'
ORDER BY r.visit_date DESC, r.created_at DESC;

-- Create aggregated ratings view for fountain summary
CREATE OR REPLACE VIEW fountain_rating_summary AS
SELECT 
    f.id as fountain_id,
    f.original_mapid,
    f.name,
    COUNT(r.id) as total_reviews,
    AVG(r.overall_rating) as avg_overall_rating,
    AVG(r.water_quality) as avg_water_quality,
    AVG(r.flow_pressure) as avg_flow_pressure,
    AVG(r.temperature) as avg_temperature,
    AVG(r.drainage) as avg_drainage,
    AVG(r.accessibility) as avg_accessibility,
    MAX(r.visit_date) as last_reviewed,
    COUNT(ig.id) as instagram_posts_count,
    -- Most recent review details
    (SELECT overall_rating FROM ratings WHERE fountain_id = f.id AND review_status = 'approved' ORDER BY visit_date DESC, created_at DESC LIMIT 1) as latest_rating,
    (SELECT notes FROM ratings WHERE fountain_id = f.id AND review_status = 'approved' ORDER BY visit_date DESC, created_at DESC LIMIT 1) as latest_notes,
    (SELECT reviewer_name FROM ratings WHERE fountain_id = f.id AND review_status = 'approved' ORDER BY visit_date DESC, created_at DESC LIMIT 1) as latest_reviewer
FROM fountains f
LEFT JOIN ratings r ON f.id = r.fountain_id AND r.review_status = 'approved'
LEFT JOIN instagram_posts ig ON r.id = ig.rating_id
GROUP BY f.id, f.original_mapid, f.name;

-- Function to extract Instagram post ID from URL
CREATE OR REPLACE FUNCTION extract_instagram_post_id(post_url TEXT)
RETURNS TEXT AS $$
BEGIN
    -- Extract post ID from Instagram URL patterns
    -- Example: https://www.instagram.com/p/DJpu8cbSfTE/ -> DJpu8cbSfTE
    RETURN (regexp_match(post_url, '/p/([A-Za-z0-9_-]+)/'))[1];
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-extract Instagram post ID when inserting
CREATE OR REPLACE FUNCTION update_instagram_post_id()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.post_url IS NOT NULL AND NEW.post_id IS NULL THEN
        NEW.post_id = extract_instagram_post_id(NEW.post_url);
    END IF;
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_instagram_posts_update_post_id
    BEFORE INSERT OR UPDATE ON instagram_posts
    FOR EACH ROW
    EXECUTE FUNCTION update_instagram_post_id();

-- Create a function to approve a review
CREATE OR REPLACE FUNCTION approve_review(
    review_id UUID,
    approved_by_user VARCHAR(100)
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE ratings 
    SET 
        review_status = 'approved',
        approved_by = approved_by_user,
        approved_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = review_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create a function to reject a review
CREATE OR REPLACE FUNCTION reject_review(
    review_id UUID,
    moderation_notes_text TEXT,
    rejected_by_user VARCHAR(100)
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE ratings 
    SET 
        review_status = 'rejected',
        moderation_notes = moderation_notes_text,
        approved_by = rejected_by_user,
        approved_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = review_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Add RLS (Row Level Security) policies for public access
ALTER TABLE fountain_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE fountain_rating_summary ENABLE ROW LEVEL SECURITY;

-- Allow public read access to approved reviews
CREATE POLICY "Public can view approved reviews" ON fountain_reviews
    FOR SELECT USING (true);

CREATE POLICY "Public can view rating summaries" ON fountain_rating_summary
    FOR SELECT USING (true);

-- Grant permissions for web access
GRANT SELECT ON fountain_reviews TO anon, authenticated;
GRANT SELECT ON fountain_rating_summary TO anon, authenticated;
