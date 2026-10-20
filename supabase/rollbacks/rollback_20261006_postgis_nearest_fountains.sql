-- =====================================================================
-- ROLLBACK for supabase/migrations/20261006_postgis_nearest_fountains.sql
-- Removes the two distance functions, the geog column (and its index),
-- and the PostGIS extension. No fountain data is lost: geog was only ever
-- calculated from latitude/longitude, which stay untouched.
-- =====================================================================
begin;

drop function if exists public.nearest_fountains(double precision, double precision, integer);
drop function if exists public.fountains_within(double precision, double precision, double precision);

drop index if exists public.idx_fountains_geog;
alter table public.fountains drop column if exists geog;

drop extension if exists postgis;

commit;
