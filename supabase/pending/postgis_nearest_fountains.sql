-- =====================================================================
-- 2026-10-06  Spatial queries with PostGIS
-- =====================================================================
-- Adds:
--   * the PostGIS extension
--   * fountains.geog  — a point built automatically from latitude/longitude
--                       (a "generated column": you never edit it by hand)
--   * a spatial index so distance queries stay fast
--   * nearest_fountains(lat, lon, how_many)   → closest fountains + metres
--   * fountains_within(lat, lon, radius_m)    → every fountain in a radius
--
-- Both functions can be called from the website with
--   supabase.rpc('nearest_fountains', { lat: 49.28, lon: -123.12 })
-- and from SQL with
--   select * from nearest_fountains(49.28, -123.12);
--
-- "geography" (not "geometry") is used so distances come out in metres
-- on the real curved Earth, no projection maths needed.
-- =====================================================================

create extension if not exists postgis with schema extensions;


-- ---------------------------------------------------------------------
-- 1. point column + index
-- ---------------------------------------------------------------------
alter table public.fountains
  add column if not exists geog extensions.geography(Point, 4326)
  generated always as (
    extensions.st_setsrid(extensions.st_makepoint(longitude, latitude), 4326)::extensions.geography
  ) stored;

create index if not exists idx_fountains_geog on public.fountains using gist (geog);


-- ---------------------------------------------------------------------
-- 2. nearest_fountains: the N closest fountains to a point
-- ---------------------------------------------------------------------
create or replace function public.nearest_fountains(
  lat      double precision,
  lon      double precision,
  how_many integer default 5
)
returns table (
  fountain_id    uuid,
  external_id    text,
  name           text,
  neighbourhood  text,
  distance_m     integer,
  average_rating numeric
)
language sql
stable
set search_path = ''
as $$
  select
    f.id,
    f.external_id,
    f.name,
    f.neighbourhood,
    round(extensions.st_distance(
      f.geog,
      extensions.st_setsrid(extensions.st_makepoint(lon, lat), 4326)::extensions.geography
    ))::integer as distance_m,
    r.average_rating
  from public.fountains f
  left join public.fountain_ratings_view r on r.fountain_id = f.id
  where f.operational_status <> 'closed'
  -- "<->" is PostGIS's index-assisted "closest first" operator
  order by f.geog operator(extensions.<->)
           extensions.st_setsrid(extensions.st_makepoint(lon, lat), 4326)::extensions.geography
  limit least(greatest(how_many, 1), 50);   -- between 1 and 50 results
$$;


-- ---------------------------------------------------------------------
-- 3. fountains_within: every fountain within radius_m metres of a point
-- ---------------------------------------------------------------------
create or replace function public.fountains_within(
  lat      double precision,
  lon      double precision,
  radius_m double precision default 500
)
returns table (
  fountain_id   uuid,
  external_id   text,
  name          text,
  neighbourhood text,
  distance_m    integer
)
language sql
stable
set search_path = ''
as $$
  select
    f.id,
    f.external_id,
    f.name,
    f.neighbourhood,
    round(extensions.st_distance(
      f.geog,
      extensions.st_setsrid(extensions.st_makepoint(lon, lat), 4326)::extensions.geography
    ))::integer as distance_m
  from public.fountains f
  where extensions.st_dwithin(
          f.geog,
          extensions.st_setsrid(extensions.st_makepoint(lon, lat), 4326)::extensions.geography,
          least(radius_m, 5000)      -- cap at 5 km
        )
  order by distance_m;
$$;

grant execute on function public.nearest_fountains(double precision, double precision, integer) to anon, authenticated;
grant execute on function public.fountains_within(double precision, double precision, double precision) to anon, authenticated;
