-- =====================================================================
-- ROLLBACK for supabase/pending/postgis_nearest_fountains.sql
-- Removes nearest_fountains() and the PostGIS extension. No data is
-- touched: the function only reads latitude and longitude.
-- =====================================================================
begin;

drop function if exists public.nearest_fountains(double precision, double precision, integer);
drop extension if exists postgis;

commit;
