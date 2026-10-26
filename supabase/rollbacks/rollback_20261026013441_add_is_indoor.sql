-- =====================================================================
-- ROLLBACK for supabase/migrations/20261026013441_add_is_indoor.sql
-- Puts fountain_overview_view back exactly as it was, then drops the
-- column. Roll back the 2026-10-25 backlog import and the 2026-10-06
-- data fix first: both set is_indoor.
-- =====================================================================
begin;

drop view public.fountain_overview_view;

create view public.fountain_overview_view
with (security_invoker = true) as
select
  f.id, f.external_id, f.name, f.neighbourhood, f.location_description,
  f.latitude, f.longitude, f.operational_status, f.season_note, f.pet_friendly,
  f.has_bottle_filler, f.is_wheelchair_accessible, f.last_verified_at,
  c.name as city_name,
  s.name as source_name,
  ratings.average_rating, ratings.approved_review_count, ratings.admin_review_count,
  latest.review_id as latest_review_id,
  latest.review_text as latest_review_text,
  latest.rating as latest_review_rating,
  latest.author_type as latest_review_author_type,
  latest.reviewer_name as latest_review_reviewer_name,
  latest.instagram_url as latest_review_instagram_url,
  latest.instagram_image_url as latest_review_instagram_image_url,
  latest.instagram_caption as latest_review_instagram_caption,
  latest.reviewed_at as latest_reviewed_at
from public.fountains f
left join public.cities c on c.id = f.city_id
left join public.sources s on s.id = f.source_id
left join public.fountain_ratings_view ratings on ratings.fountain_id = f.id
left join public.fountain_latest_review_view latest on latest.fountain_id = f.id;

-- grants exactly as the view had them before (checked on live 2026-10-25):
-- visitors and logged-in users can only read; service_role keeps full rights
revoke all on public.fountain_overview_view from anon, authenticated;
grant select on public.fountain_overview_view to anon, authenticated;
grant all on public.fountain_overview_view to service_role;

alter table public.fountains drop column if exists is_indoor;

commit;
