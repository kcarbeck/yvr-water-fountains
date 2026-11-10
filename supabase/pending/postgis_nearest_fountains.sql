-- =====================================================================
-- PostGIS and nearest_fountains(lat, lon, how_many)
-- ---------------------------------------------------------------------
-- Adds the PostGIS extension and one function that lists the fountains
-- closest to a point (not those closed for good), with the distance in
-- metres and the mean rating of approved visits. how_many is kept between
-- 1 and 50; a missing argument or a point off the globe gives no rows.
--
--   select * from public.nearest_fountains(49.2734, -123.1038, 5);
--
-- Points are built from latitude/longitude when the function runs, so the
-- fountains table does not change. geography (not geometry) gives metres
-- without choosing a projection. With about 450 fountains no spatial index
-- is needed.
--
-- Rollback: supabase/rollbacks/rollback_postgis_nearest_fountains.sql
-- =====================================================================

create extension if not exists postgis with schema extensions;

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
strict                 -- any null argument: no rows
set search_path = ''
as $$
  with here as (
    select extensions.st_setsrid(extensions.st_makepoint(lon, lat), 4326)::extensions.geography as point
  )
  select d.id, d.external_id, d.name, d.neighbourhood,
         round(d.metres)::integer as distance_m,
         r.average_rating
  from (
    select f.*,
           extensions.st_distance(
             extensions.st_setsrid(extensions.st_makepoint(f.longitude, f.latitude), 4326)::extensions.geography,
             here.point) as metres
    from public.fountains f
    cross join here
    where f.operational_status <> 'closed'        -- closed for good: not useful nearby
      and lat between -90 and 90 and lon between -180 and 180
  ) d
  left join public.fountain_ratings_view r on r.fountain_id = d.id
  order by d.metres, d.id                         -- exact distance; id breaks ties
  limit least(greatest(how_many, 1), 50);
$$;

grant execute on function public.nearest_fountains(double precision, double precision, integer) to anon, authenticated;
