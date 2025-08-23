-- Updated schema v2 that works with existing tables
-- This script modifies existing tables instead of creating new ones

CREATE EXTENSION IF NOT EXISTS postgis;

-- Create new tables that don't exist yet
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
    data_format VARCHAR(50), -- 'csv', 'geojson', 'api'
    last_updated DATE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- First, handle the location_note -> location_description rename safely
DO $$
BEGIN
    -- Check if location_note exists and location_description doesn't
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'fountains' AND column_name = 'location_note')
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'fountains' AND column_name = 'location_description') THEN
        ALTER TABLE fountains RENAME COLUMN location_note TO location_description;
    END IF;
END $$;

-- Fix the id column to have proper UUID default if it doesn't already
DO $$
BEGIN
    -- Check if id column exists and doesn't have a default
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'fountains' AND column_name = 'id' 
        AND column_default IS NULL
    ) THEN
        -- Set UUID default for id column
        ALTER TABLE fountains ALTER COLUMN id SET DEFAULT gen_random_uuid();
    END IF;
END $$;

-- Add new columns to existing fountains table (excluding location_description since it might already exist)
ALTER TABLE fountains 
ADD COLUMN IF NOT EXISTS city_id INTEGER,
ADD COLUMN IF NOT EXISTS source_dataset_id INTEGER,
ADD COLUMN IF NOT EXISTS location_description TEXT,
ADD COLUMN IF NOT EXISTS detailed_location TEXT,
ADD COLUMN IF NOT EXISTS type TEXT,
ADD COLUMN IF NOT EXISTS operational_season VARCHAR(50),
ADD COLUMN IF NOT EXISTS accessibility_features TEXT,
ADD COLUMN IF NOT EXISTS neighborhood TEXT,
ADD COLUMN IF NOT EXISTS original_mapid TEXT,
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Convert pet_friendly to boolean only if it's currently text, but keep operational_season as text for dynamic checking
DO $$
DECLARE
    pet_friendly_type TEXT;
BEGIN
    -- Check the current data type of pet_friendly column
    SELECT data_type INTO pet_friendly_type
    FROM information_schema.columns 
    WHERE table_name = 'fountains' AND column_name = 'pet_friendly';
    
    -- Only convert if it's currently text/varchar
    IF pet_friendly_type IN ('text', 'character varying', 'varchar', 'character') THEN
        -- Add temporary boolean column
        ALTER TABLE fountains ADD COLUMN IF NOT EXISTS pet_friendly_bool BOOLEAN;
        
        -- Update pet_friendly to boolean
        UPDATE fountains SET 
        pet_friendly_bool = CASE 
            WHEN UPPER(TRIM(pet_friendly)) = 'Y' THEN true
            WHEN UPPER(TRIM(pet_friendly)) = 'N' THEN false
            WHEN pet_friendly IS NULL OR TRIM(pet_friendly) = '' THEN false -- Default to false for empty/null
            ELSE false
        END;
        
        -- Drop old pet_friendly column and rename boolean one
        ALTER TABLE fountains DROP COLUMN pet_friendly;
        ALTER TABLE fountains RENAME COLUMN pet_friendly_bool TO pet_friendly;
    ELSE
        -- If it's already boolean, just add the column if it doesn't exist
        ALTER TABLE fountains ADD COLUMN IF NOT EXISTS pet_friendly BOOLEAN DEFAULT false;
    END IF;
END $$;

-- Add constraints to existing fountains table (with proper error handling)
DO $$ 
BEGIN
    -- Add lat/lon check constraint
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fountains_lat_lon_check'
    ) THEN
        ALTER TABLE fountains 
        ADD CONSTRAINT fountains_lat_lon_check 
        CHECK (lat BETWEEN -90 AND 90 AND lon BETWEEN -180 AND 180);
    END IF;
    
    -- Add city foreign key constraint
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fk_fountains_city'
    ) THEN
        ALTER TABLE fountains 
        ADD CONSTRAINT fk_fountains_city 
        FOREIGN KEY (city_id) REFERENCES cities(id);
    END IF;
    
    -- Add source dataset foreign key constraint
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fk_fountains_source'
    ) THEN
        ALTER TABLE fountains 
        ADD CONSTRAINT fk_fountains_source 
        FOREIGN KEY (source_dataset_id) REFERENCES source_datasets(id);
    END IF;
END $$;

-- Update existing ratings table structure
ALTER TABLE ratings 
ADD COLUMN IF NOT EXISTS overall_rating DECIMAL(3,1),
ADD COLUMN IF NOT EXISTS water_quality INTEGER,
ADD COLUMN IF NOT EXISTS flow_pressure INTEGER,
ADD COLUMN IF NOT EXISTS temperature INTEGER,
ADD COLUMN IF NOT EXISTS drainage INTEGER,
ADD COLUMN IF NOT EXISTS accessibility INTEGER,
ADD COLUMN IF NOT EXISTS notes TEXT,
ADD COLUMN IF NOT EXISTS user_name VARCHAR(100) DEFAULT 'default_user',
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Copy existing data to new columns
UPDATE ratings SET 
overall_rating = rating,
flow_pressure = flow,
temperature = temp,
notes = caption
WHERE overall_rating IS NULL;

-- Add constraints to ratings (with proper error handling)
DO $$ 
BEGIN
    -- Add rating constraints one by one
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_overall_rating') THEN
        ALTER TABLE ratings ADD CONSTRAINT check_overall_rating 
        CHECK (overall_rating >= 0 AND overall_rating <= 10);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_water_quality') THEN
        ALTER TABLE ratings ADD CONSTRAINT check_water_quality 
        CHECK (water_quality >= 1 AND water_quality <= 10);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_flow_pressure') THEN
        ALTER TABLE ratings ADD CONSTRAINT check_flow_pressure 
        CHECK (flow_pressure >= 1 AND flow_pressure <= 10);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_temperature') THEN
        ALTER TABLE ratings ADD CONSTRAINT check_temperature 
        CHECK (temperature >= 1 AND temperature <= 10);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_drainage') THEN
        ALTER TABLE ratings ADD CONSTRAINT check_drainage 
        CHECK (drainage >= 1 AND drainage <= 10);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_accessibility') THEN
        ALTER TABLE ratings ADD CONSTRAINT check_accessibility 
        CHECK (accessibility >= 1 AND accessibility <= 10);
    END IF;
END $$;

-- Create instagram_posts table (new) - handle type compatibility
DO $$
DECLARE
    fountain_id_type TEXT;
    rating_id_type TEXT;
BEGIN
    -- Check the actual data type of fountains.id
    SELECT data_type INTO fountain_id_type
    FROM information_schema.columns 
    WHERE table_name = 'fountains' AND column_name = 'id';
    
    -- Check the actual data type of ratings.id  
    SELECT data_type INTO rating_id_type
    FROM information_schema.columns 
    WHERE table_name = 'ratings' AND column_name = 'id';
    
    -- Create table with matching types
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'instagram_posts') THEN
        IF fountain_id_type = 'uuid' AND rating_id_type = 'uuid' THEN
            -- Both are UUID
            EXECUTE 'CREATE TABLE instagram_posts (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                fountain_id UUID REFERENCES fountains(id) ON DELETE CASCADE,
                rating_id UUID REFERENCES ratings(id) ON DELETE SET NULL,
                post_url TEXT UNIQUE NOT NULL,
                caption TEXT,
                date_posted DATE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )';
        ELSIF fountain_id_type = 'text' AND rating_id_type = 'uuid' THEN
            -- Fountains is TEXT, ratings is UUID
            EXECUTE 'CREATE TABLE instagram_posts (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                fountain_id TEXT REFERENCES fountains(id) ON DELETE CASCADE,
                rating_id UUID REFERENCES ratings(id) ON DELETE SET NULL,
                post_url TEXT UNIQUE NOT NULL,
                caption TEXT,
                date_posted DATE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )';
        ELSIF fountain_id_type = 'uuid' AND rating_id_type = 'text' THEN
            -- Fountains is UUID, ratings is TEXT
            EXECUTE 'CREATE TABLE instagram_posts (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                fountain_id UUID REFERENCES fountains(id) ON DELETE CASCADE,
                rating_id TEXT REFERENCES ratings(id) ON DELETE SET NULL,
                post_url TEXT UNIQUE NOT NULL,
                caption TEXT,
                date_posted DATE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )';
        ELSE
            -- Both are TEXT or other type
            EXECUTE 'CREATE TABLE instagram_posts (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                fountain_id TEXT REFERENCES fountains(id) ON DELETE CASCADE,
                rating_id TEXT REFERENCES ratings(id) ON DELETE SET NULL,
                post_url TEXT UNIQUE NOT NULL,
                caption TEXT,
                date_posted DATE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )';
        END IF;
    END IF;
END $$;

-- Migrate Instagram data from ratings table
INSERT INTO instagram_posts (fountain_id, rating_id, post_url, caption)
SELECT fountain_id, id, ig_post_url, caption
FROM ratings 
WHERE ig_post_url IS NOT NULL 
AND ig_post_url != ''
AND NOT EXISTS (SELECT 1 FROM instagram_posts WHERE post_url = ratings.ig_post_url);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_fountains_city ON fountains(city_id);
CREATE INDEX IF NOT EXISTS idx_fountains_location ON fountains USING GIST(location);
-- Note: in_operation column doesn't exist anymore, using operational_season instead
-- CREATE INDEX IF NOT EXISTS idx_fountains_in_operation ON fountains(in_operation);
CREATE INDEX IF NOT EXISTS idx_fountains_operational_season ON fountains(operational_season);
CREATE INDEX IF NOT EXISTS idx_ratings_fountain ON ratings(fountain_id);
CREATE INDEX IF NOT EXISTS idx_ratings_visit_date ON ratings(visit_date);
CREATE INDEX IF NOT EXISTS idx_instagram_fountain ON instagram_posts(fountain_id);

-- Create trigger for updating updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS update_fountains_updated_at ON fountains;
DROP TRIGGER IF EXISTS update_ratings_updated_at ON ratings;
DROP TRIGGER IF EXISTS update_instagram_updated_at ON instagram_posts;

-- Create new triggers
CREATE TRIGGER update_fountains_updated_at BEFORE UPDATE ON fountains 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ratings_updated_at BEFORE UPDATE ON ratings 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_instagram_updated_at BEFORE UPDATE ON instagram_posts 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert initial cities (only if they don't exist)
INSERT INTO cities (name) 
SELECT * FROM (VALUES ('Vancouver'), ('Burnaby'), ('Richmond'), ('Surrey')) AS v(name)
WHERE NOT EXISTS (SELECT 1 FROM cities WHERE cities.name = v.name);

-- Insert initial source datasets
INSERT INTO source_datasets (city_name, dataset_name, data_format, notes) 
SELECT * FROM (VALUES 
    ('Vancouver', 'Legacy Data Migration', 'legacy', 'Data migrated from v1 schema'),
    ('Burnaby', 'Legacy Data Migration', 'legacy', 'Data migrated from v1 schema')
) AS v(city_name, dataset_name, data_format, notes)
WHERE NOT EXISTS (SELECT 1 FROM source_datasets WHERE source_datasets.city_name = v.city_name);

-- Update city_id for existing fountains based on geo_local_area
-- Update city_id and operational_season for existing fountains
-- Update city_id and operational_season for existing fountains
-- First check if geo_local_area and in_operation columns exist
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'fountains' AND column_name = 'geo_local_area') THEN
        UPDATE fountains SET 
        city_id = (
            CASE 
                WHEN geo_local_area ILIKE '%burnaby%' THEN (SELECT id FROM cities WHERE name = 'Burnaby')
                WHEN geo_local_area ILIKE '%richmond%' THEN (SELECT id FROM cities WHERE name = 'Richmond')
                WHEN geo_local_area ILIKE '%surrey%' THEN (SELECT id FROM cities WHERE name = 'Surrey')
                ELSE (SELECT id FROM cities WHERE name = 'Vancouver')
            END
        ),
        neighborhood = geo_local_area
        WHERE city_id IS NULL OR neighborhood IS NULL;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'fountains' AND column_name = 'in_operation') THEN
        UPDATE fountains SET 
        operational_season = CASE 
            WHEN LOWER(TRIM(in_operation)) = 'spring to fall' THEN 'spring to fall'
            WHEN LOWER(TRIM(in_operation)) = 'year-round' THEN 'year-round'
            WHEN LOWER(TRIM(in_operation)) = 'year round' THEN 'year-round'
            WHEN LOWER(TRIM(in_operation)) = 'may-october' THEN 'May-October'
            ELSE 'year-round' -- Default for empty or other values
        END
        WHERE operational_season IS NULL;
    END IF;
END $$;

-- Update source_dataset_id for existing fountains
UPDATE fountains SET source_dataset_id = (
    SELECT id FROM source_datasets 
    WHERE city_name = (SELECT name FROM cities WHERE id = fountains.city_id)
    LIMIT 1
) WHERE source_dataset_id IS NULL;

-- Create function to check if fountain is currently operational based on season
CREATE OR REPLACE FUNCTION is_fountain_operational(operational_season TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    IF operational_season IS NULL OR operational_season = '' THEN
        RETURN true; -- Default to operational
    END IF;
    
    CASE LOWER(TRIM(operational_season))
        WHEN 'year-round', 'year round' THEN
            RETURN true;
        WHEN 'spring to fall' THEN
            -- Roughly March 1 to November 30 (spring to fall in Vancouver)
            RETURN EXTRACT(MONTH FROM CURRENT_DATE) BETWEEN 3 AND 11;
        WHEN 'may-october' THEN
            -- May 1 to October 31
            RETURN EXTRACT(MONTH FROM CURRENT_DATE) BETWEEN 5 AND 10;
        ELSE
            RETURN true; -- Default to operational for unknown seasons
    END CASE;
END;
$$ LANGUAGE plpgsql;

-- Create views for easier querying with dynamic operational status
-- Build view dynamically based on existing columns
DO $$
DECLARE
    has_original_mapid BOOLEAN;
    has_type BOOLEAN;
    view_sql TEXT;
BEGIN
    -- Check which columns exist
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'fountains' AND column_name = 'original_mapid'
    ) INTO has_original_mapid;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'fountains' AND column_name = 'type'
    ) INTO has_type;
    
    -- Build the view SQL dynamically
    view_sql := 'CREATE OR REPLACE VIEW fountain_details AS
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
        f.maintainer';
    
    -- Add optional columns if they exist
    IF has_original_mapid THEN
        view_sql := view_sql || ',
        f.original_mapid';
    END IF;
    
    IF has_type THEN
        view_sql := view_sql || ',
        f.type';
    END IF;
    
    -- Add the rest of the view
    view_sql := view_sql || ',
        AVG(r.overall_rating) as avg_rating,
        COUNT(r.id) as rating_count,
        MAX(r.visit_date) as last_visited
    FROM fountains f
    LEFT JOIN cities c ON f.city_id = c.id
    LEFT JOIN ratings r ON f.id = r.fountain_id
    GROUP BY f.id, f.name, c.name, f.neighborhood, f.location_description, f.lat, f.lon, f.operational_season, f.pet_friendly, f.maintainer';
    
    -- Add optional columns to GROUP BY if they exist
    IF has_original_mapid THEN
        view_sql := view_sql || ', f.original_mapid';
    END IF;
    
    IF has_type THEN
        view_sql := view_sql || ', f.type';
    END IF;
    
    -- Execute the dynamic view creation
    EXECUTE view_sql;
END $$;

CREATE OR REPLACE VIEW latest_ratings AS
SELECT DISTINCT ON (r.fountain_id)
    r.fountain_id,
    r.overall_rating,
    r.water_quality,
    r.flow_pressure,
    r.temperature,
    r.drainage,
    r.notes,
    r.visit_date,
    f.name as fountain_name,
    c.name as city_name,
    f.operational_season,
    is_fountain_operational(f.operational_season) as currently_operational
FROM ratings r
JOIN fountains f ON r.fountain_id = f.id
JOIN cities c ON f.city_id = c.id
ORDER BY r.fountain_id, r.visit_date DESC;

-- Clean up old columns that are no longer needed (optional)
-- Uncomment these if you want to remove the old columns completely:
-- ALTER TABLE ratings DROP COLUMN IF EXISTS rating;
-- ALTER TABLE ratings DROP COLUMN IF EXISTS flow;
-- ALTER TABLE ratings DROP COLUMN IF EXISTS temp;
-- ALTER TABLE ratings DROP COLUMN IF EXISTS caption;
-- ALTER TABLE ratings DROP COLUMN IF EXISTS ig_post_url;

SELECT 'Schema update completed successfully!' as status;
