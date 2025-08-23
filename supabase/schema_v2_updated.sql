-- Updated schema with fields that the ETL is trying to insert
-- Run this to add missing columns to your existing tables

-- Add missing columns to fountains table
ALTER TABLE fountains 
ADD COLUMN IF NOT EXISTS neighborhood VARCHAR(200),
ADD COLUMN IF NOT EXISTS type VARCHAR(100),
ADD COLUMN IF NOT EXISTS accessibility_features TEXT;

-- Update the fountain_details view to include new fields
DROP VIEW IF EXISTS fountain_details;

CREATE VIEW fountain_details AS
SELECT 
    f.id,
    f.name,
    c.name as city_name,
    f.location_description,
    f.detailed_location,
    f.neighborhood,
    f.type,
    f.lat,
    f.lon,
    f.in_operation,
    f.operational_season,
    f.pet_friendly,
    f.accessibility_features,
    f.maintainer,
    f.original_mapid,
    f.photo_name,
    AVG(r.overall_rating) as avg_rating,
    COUNT(r.id) as rating_count,
    MAX(r.visit_date) as last_visited,
    -- Get latest rating details
    (SELECT overall_rating FROM ratings WHERE fountain_id = f.id ORDER BY visit_date DESC LIMIT 1) as latest_rating,
    (SELECT flow_pressure FROM ratings WHERE fountain_id = f.id ORDER BY visit_date DESC LIMIT 1) as latest_flow,
    (SELECT temperature FROM ratings WHERE fountain_id = f.id ORDER BY visit_date DESC LIMIT 1) as latest_temp,
    (SELECT drainage FROM ratings WHERE fountain_id = f.id ORDER BY visit_date DESC LIMIT 1) as latest_drainage,
    (SELECT notes FROM ratings WHERE fountain_id = f.id ORDER BY visit_date DESC LIMIT 1) as latest_notes
FROM fountains f
LEFT JOIN cities c ON f.city_id = c.id
LEFT JOIN ratings r ON f.id = r.fountain_id
GROUP BY f.id, c.name;

-- Create an API-friendly view for the web app
CREATE OR REPLACE VIEW fountains_geojson AS
SELECT 
    json_build_object(
        'type', 'FeatureCollection',
        'features', json_agg(
            json_build_object(
                'type', 'Feature',
                'geometry', json_build_object(
                    'type', 'Point',
                    'coordinates', json_build_array(lon, lat)
                ),
                'properties', json_build_object(
                    'id', original_mapid,
                    'name', name,
                    'location', location_description,
                    'detailed_location', detailed_location,
                    'geo_local_area', neighborhood,
                    'city', city_name,
                    'type', type,
                    'maintainer', maintainer,
                    'in_operation', 
                        CASE 
                            WHEN in_operation IS NULL THEN '—'
                            WHEN in_operation THEN operational_season 
                            ELSE 'Not operational'
                        END,
                    'pet_friendly', 
                        CASE 
                            WHEN pet_friendly THEN 'Yes'
                            ELSE 'No'
                        END,
                    'accessibility_features', accessibility_features,
                    'rating', latest_rating,
                    'flow', latest_flow,
                    'temp', latest_temp,
                    'drainage', latest_drainage,
                    'caption', latest_notes,
                    'photo_name', photo_name
                )
            )
        )
    ) as geojson
FROM fountain_details
WHERE lat IS NOT NULL AND lon IS NOT NULL;
