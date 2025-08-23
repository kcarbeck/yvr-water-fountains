-- Just add the missing original_mapid column
ALTER TABLE fountains ADD COLUMN IF NOT EXISTS original_mapid TEXT;
