-- Fountains within 15 m of each other: real double fountains, or (more
-- often) different fountains given the same placeholder coordinates in
-- the source data. One row per cluster.
-- Requires supabase/pending/postgis_nearest_fountains.sql (not yet applied).
with pairs as (
  select a.id as id_a, b.id as id_b
  from fountains a
  join fountains b on a.id < b.id and st_dwithin(a.geog, b.geog, 15)
)
select
  round(f.latitude::numeric, 5)  as lat,
  round(f.longitude::numeric, 5) as lon,
  count(*)                       as fountains_here,
  string_agg(coalesce(f.external_id, '(ours)') || ' ' || f.name, ' | ' order by f.name) as which
from fountains f
where f.id in (select id_a from pairs union select id_b from pairs)
group by 1, 2
order by fountains_here desc;
