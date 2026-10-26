-- =====================================================================
-- ROLLBACK for supabase/pending/public_reviews.sql
-- Puts the two views back exactly as they were, then removes the
-- functions, tables, column and index the migration added.
-- Reviews that came in through submit_public_review stay in reviews.
-- Reports are deleted with their table: export them first if any exist.
-- =====================================================================
begin;

-- views: drop the overview first (it reads the ratings view)
drop view public.fountain_overview_view;
drop view public.fountain_ratings_view;

create view public.fountain_ratings_view
with (security_invoker = true) as
select
  f.id as fountain_id,
  round(avg(r.rating)::numeric, 2) as average_rating,
  count(r.id) filter (where r.status = 'approved') as approved_review_count,
  count(r.id) filter (where r.status = 'approved' and r.author_type = 'admin') as admin_review_count
from public.fountains f
left join public.reviews r on r.fountain_id = f.id and r.status = 'approved'
group by f.id;

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
  latest.reviewed_at as latest_reviewed_at,
  f.is_indoor
from public.fountains f
left join public.cities c on c.id = f.city_id
left join public.sources s on s.id = f.source_id
left join public.fountain_ratings_view ratings on ratings.fountain_id = f.id
left join public.fountain_latest_review_view latest on latest.fountain_id = f.id;

-- grants exactly as the views had them before (checked on live 2026-10-26)
revoke all on public.fountain_ratings_view, public.fountain_overview_view from anon, authenticated;
grant select on public.fountain_ratings_view, public.fountain_overview_view to anon, authenticated;
grant all on public.fountain_ratings_view, public.fountain_overview_view to service_role;

drop function public.submit_report(uuid, text, text, double precision, double precision, text, text);
drop function public.submit_public_review(uuid, numeric, text, text, date, text);

drop table public.reports;
drop table public.settings;

drop index public.idx_reviews_fountain_status_created;
alter table public.reviews drop column created_by;   -- also drops its column grant

commit;
