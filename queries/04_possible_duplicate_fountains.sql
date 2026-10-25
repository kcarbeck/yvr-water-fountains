-- Fountains that sit within 15 m of each other — either real double
-- fountains, or (more often) the source data giving several different
-- fountains the same placeholder coordinates. Needs PostGIS (geog column).
-- One row per cluster.
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
