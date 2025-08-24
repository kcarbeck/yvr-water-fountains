-- Clean schema for YVR Water Fountains v2
-- Simplified version without redundant migration logic

CREATE EXTENSION IF NOT EXISTS postgis;

-- Core tables
CREATE TABLE IF NOT EXISTS cities (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    province VARCHAR(50) NOT NULL DEFAULT 'BC',
    country VARCHAR(50) NOT NULL DEFAULT 'Canada',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS source_datasets (
    id SERIAL PRIMARY KEY,
    city_name VARCHAR(100) NOT NULL,
    dataset_name VARCHAR(200) NOT NULL,
    source_url TEXT,
    data_format VARCHAR(50),
    last_updated DATE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Main fountains table with proper structure
CREATE TABLE IF NOT EXISTS fountains (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    city_id INTEGER REFERENCES cities(id),
    source_dataset_id INTEGER REFERENCES source_datasets(id),
    name TEXT,
    location_description TEXT,
    detailed_location TEXT,
    neighborhood TEXT,
    type TEXT,
    lat DECIMAL(10, 8) NOT NULL CHECK (lat BETWEEN -90 AND 90),
    lon DECIMAL(11, 8) NOT NULL CHECK (lon BETWEEN -180 AND 180),
    location GEOMETRY(POINT, 4326),
    operational_season VARCHAR(50),
    pet_friendly BOOLEAN DEFAULT false,
    maintainer TEXT,
    original_mapid TEXT,
    accessibility_features TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Ratings table
CREATE TABLE IF NOT EXISTS ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fountain_id UUID REFERENCES fountains(id) ON DELETE CASCADE,
    overall_rating DECIMAL(3,1) CHECK (overall_rating >= 0 AND overall_rating <= 10),
    water_quality INTEGER CHECK (water_quality >= 1 AND water_quality <= 10),
    flow_pressure INTEGER CHECK (flow_pressure >= 1 AND flow_pressure <= 10),
    temperature INTEGER CHECK (temperature >= 1 AND temperature <= 10),
    drainage INTEGER CHECK (drainage >= 1 AND drainage <= 10),
    accessibility INTEGER CHECK (accessibility >= 1 AND accessibility <= 10),
    notes TEXT,
    reviewer_name VARCHAR(100) DEFAULT 'YVR Water Fountains',
    reviewer_email VARCHAR(255),
    visit_date DATE,
    visited BOOLEAN DEFAULT false,
    is_verified BOOLEAN DEFAULT true,
    review_status VARCHAR(20) DEFAULT 'approved' CHECK (review_status IN ('pending', 'approved', 'rejected')),
    review_type VARCHAR(20) DEFAULT 'instagram' CHECK (review_type IN ('instagram', 'user_submission')),
    moderation_notes TEXT,
    approved_by VARCHAR(100),
    approved_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Instagram posts table
CREATE TABLE IF NOT EXISTS instagram_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fountain_id UUID REFERENCES fountains(id) ON DELETE CASCADE,
    rating_id UUID REFERENCES ratings(id) ON DELETE SET NULL,
    post_url TEXT UNIQUE NOT NULL,
    post_id TEXT,
    caption TEXT,
    date_posted DATE,
    has_media BOOLEAN DEFAULT true,
    media_count INTEGER DEFAULT 1,
    post_type VARCHAR(20) DEFAULT 'post' CHECK (post_type IN ('post', 'reel', 'story')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_fountains_city ON fountains(city_id);
CREATE INDEX IF NOT EXISTS idx_fountains_location ON fountains USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_fountains_operational_season ON fountains(operational_season);
CREATE INDEX IF NOT EXISTS idx_ratings_fountain ON ratings(fountain_id);
CREATE INDEX IF NOT EXISTS idx_ratings_visit_date ON ratings(visit_date DESC);
CREATE INDEX IF NOT EXISTS idx_ratings_status ON ratings(review_status);
CREATE INDEX IF NOT EXISTS idx_instagram_fountain ON instagram_posts(fountain_id);
CREATE INDEX IF NOT EXISTS idx_instagram_rating ON instagram_posts(rating_id);

-- Function for operational status checking
CREATE OR REPLACE FUNCTION is_fountain_operational(operational_season TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    IF operational_season IS NULL OR operational_season = '' THEN
        RETURN true;
    END IF;
    
    CASE LOWER(TRIM(operational_season))
        WHEN 'year-round', 'year round' THEN
            RETURN true;
        WHEN 'spring to fall' THEN
            RETURN EXTRACT(MONTH FROM CURRENT_DATE) BETWEEN 3 AND 11;
        WHEN 'may-october' THEN
            RETURN EXTRACT(MONTH FROM CURRENT_DATE) BETWEEN 5 AND 10;
        ELSE
            RETURN true;
    END CASE;
END;
$$ LANGUAGE plpgsql;

-- Function to extract Instagram post ID
CREATE OR REPLACE FUNCTION extract_instagram_post_id(post_url TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN (regexp_match(post_url, '/p/([A-Za-z0-9_-]+)/'))[1];
END;
$$ LANGUAGE plpgsql;

-- Trigger function for updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers
CREATE TRIGGER update_fountains_updated_at BEFORE UPDATE ON fountains 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ratings_updated_at BEFORE UPDATE ON ratings 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_instagram_updated_at BEFORE UPDATE ON instagram_posts 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger for Instagram post ID extraction
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

-- Views
CREATE OR REPLACE VIEW fountain_details AS
SELECT 
    f.id,
    f.name,
    c.name as city_name,
    f.neighborhood,
    f.location_description,
    f.lat,
    f.lon,
    f.operational_season,
    is_fountain_operational(f.operational_season) as currently_operational,
    f.pet_friendly,
    f.maintainer,
    f.original_mapid,
    f.type,
    AVG(r.overall_rating) as avg_rating,
    COUNT(r.id) as rating_count,
    MAX(r.visit_date) as last_visited
FROM fountains f
LEFT JOIN cities c ON f.city_id = c.id
LEFT JOIN ratings r ON f.id = r.fountain_id AND r.review_status = 'approved'
GROUP BY f.id, f.name, c.name, f.neighborhood, f.location_description, 
         f.lat, f.lon, f.operational_season, f.pet_friendly, f.maintainer,
         f.original_mapid, f.type;

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

-- Functions for review moderation
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

-- Insert initial data
INSERT INTO cities (name) 
SELECT * FROM (VALUES ('Vancouver'), ('Burnaby'), ('Richmond'), ('Surrey')) AS v(name)
WHERE NOT EXISTS (SELECT 1 FROM cities WHERE cities.name = v.name);

INSERT INTO source_datasets (city_name, dataset_name, data_format, notes) 
SELECT * FROM (VALUES 
    ('Vancouver', 'Vancouver Parks Open Data', 'csv', 'Official city data'),
    ('Burnaby', 'Burnaby Open Data', 'csv', 'Official city data')
) AS v(city_name, dataset_name, data_format, notes)
WHERE NOT EXISTS (SELECT 1 FROM source_datasets WHERE source_datasets.city_name = v.city_name);

SELECT 'Clean schema setup completed successfully!' as status;