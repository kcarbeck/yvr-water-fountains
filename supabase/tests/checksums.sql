-- =====================================================================
-- Fingerprints of each table, to prove two databases hold identical
-- data (e.g. live vs. the local test copy, or before vs. after a
-- rollback). Run the same file on both and compare the md5 values.
-- reviewer_email is left out so the output never shows personal data.
-- Timestamps are printed in UTC so both sides format them the same.
-- =====================================================================
set timezone = 'UTC';

select 'cities' as tbl, count(*) as n, md5(coalesce(json_agg(t order by t.id)::text, '')) as md5
from public.cities t
union all
select 'sources', count(*), md5(coalesce(json_agg(t order by t.id)::text, ''))
from public.sources t
union all
select 'fountains', count(*), md5(coalesce(json_agg(t order by t.id)::text, ''))
from (select id, external_id, city_id, source_id, name, neighbourhood, location_description,
             latitude, longitude, operational_status, season_note, pet_friendly,
             has_bottle_filler, is_wheelchair_accessible, last_verified_at, created_at, updated_at
      from public.fountains) t
union all
select 'reviews', count(*), md5(coalesce(json_agg(t order by t.id)::text, ''))
from (select id, fountain_id, author_type, status, rating, review_text, reviewer_name,
             instagram_url, instagram_image_url, instagram_caption, visit_date, reviewed_at,
             approved_by, created_at, updated_at
      from public.reviews) t
order by 1;
