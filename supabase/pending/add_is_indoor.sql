-- =====================================================================
-- Add an "indoor" label to fountains (decided 2026-10-25)
-- =====================================================================
-- Indoor fountains may be locked or closed outside building hours; the
-- map says "Indoor" so visitors know. Everything else stays as it is.
-- Rollback: supabase/rollbacks/rollback_add_is_indoor.sql
-- =====================================================================

-- 1. The new column. Existing fountains are outdoor (false) unless set.
alter table public.fountains
  add column if not exists is_indoor boolean not null default false;

-- 2. Show it in the view the map reads. The definition is unchanged
--    except for is_indoor, added at the end (Postgres only allows new
--    columns at the end when replacing a view).
create or replace view public.fountain_overview_view
with (security_invoker = true) as
select
  f.id,
  f.external_id,
  f.name,
  f.neighbourhood,
  f.location_description,
  f.latitude,
  f.longitude,
  f.operational_status,
  f.season_note,
  f.pet_friendly,
  f.has_bottle_filler,
  f.is_wheelchair_accessible,
  f.last_verified_at,
  c.name as city_name,
  s.name as source_name,
  ratings.average_rating,
  ratings.approved_review_count,
  ratings.admin_review_count,
  latest.review_id as latest_review_id,
  latest.review_text as latest_review_text,
  latest.rating as latest_review_rating,
  latest.author_type as latest_review_author_type,
  latest.reviewer_name as latest_review_reviewer_name,
  latest.instagram_url as latest_review_instagram_url,
  latest.instagram_image_url as latest_review_instagram_image_url,
  latest.instagram_caption as latest_review_instagram_caption,
  latest.reviewed_at as latest_reviewed_at,
  f.is_indoor
from public.fountains f
left join public.cities c on c.id = f.city_id
left join public.sources s on s.id = f.source_id
left join public.fountain_ratings_view ratings on ratings.fountain_id = f.id
left join public.fountain_latest_review_view latest on latest.fountain_id = f.id;
