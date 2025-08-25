-- Schema Updates for YVR Water Fountains
-- Run these updates to improve performance and add missing indexes

-- Add index on original_mapid for faster lookups during ETL
CREATE INDEX IF NOT EXISTS idx_fountains_original_mapid ON fountains(original_mapid);

-- Add unique constraint on original_mapid to prevent duplicates
ALTER TABLE fountains ADD CONSTRAINT unique_original_mapid UNIQUE (original_mapid);

-- Add index on reviewer email for user lookups
CREATE INDEX IF NOT EXISTS idx_ratings_reviewer_email ON ratings(reviewer_email);

-- Add index on created_at for better ordering
CREATE INDEX IF NOT EXISTS idx_ratings_created_at ON ratings(created_at DESC);

-- Ensure the geometry field is properly indexed
UPDATE fountains SET location = ST_SetSRID(ST_MakePoint(lon, lat), 4326) WHERE location IS NULL;

-- Add check to ensure lat/lon are within reasonable bounds for Vancouver/Burnaby
-- Note: This constraint is applied after coordinate conversion
-- Uncomment after running initial ETL:
-- ALTER TABLE fountains ADD CONSTRAINT check_reasonable_coordinates 
--     CHECK (lat BETWEEN 49.0 AND 49.5 AND lon BETWEEN -123.5 AND -122.5);

-- Create view for active fountains with ratings
CREATE OR REPLACE VIEW active_fountains_with_ratings AS
SELECT 
    f.*,
    COUNT(r.id) as rating_count,
    AVG(r.overall_rating) as avg_rating,
    MAX(r.visit_date) as last_visited,
    is_fountain_operational(f.operational_season) as currently_operational
FROM fountains f
LEFT JOIN ratings r ON f.id = r.fountain_id AND r.review_status = 'approved'
GROUP BY f.id;

SELECT 'Schema updates completed successfully!' as result;
