-- Simple fix: Just add UUID default to id column
-- This is all we need to make the ETL work

ALTER TABLE fountains ALTER COLUMN id SET DEFAULT gen_random_uuid();

-- Add original_mapid column if it doesn't exist
ALTER TABLE fountains ADD COLUMN IF NOT EXISTS original_mapid TEXT;

SELECT 'UUID default and original_mapid column added successfully!' as status;
