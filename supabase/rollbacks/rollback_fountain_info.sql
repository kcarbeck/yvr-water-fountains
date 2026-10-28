-- =====================================================================
-- ROLLBACK for supabase/pending/fountain_info.sql
-- Puts the two views back exactly as the migrations left them
-- (fountain_latest_review_view from 20261021173926, the overview from
-- 20261027000642), removes the all-visits view, restores the old
-- submit_public_review() and drops the new columns.
-- Answers stored in the dropped review and fountain columns are lost:
-- export them first if any exist.
-- =====================================================================
begin;

drop view public.fountain_reviews_view;

-- the overview reads the latest-review view, so it goes first
drop view public.fountain_overview_view;
drop view public.fountain_latest_review_view;

create view public.fountain_latest_review_view
with (security_invoker = true) as
select
  f.id as fountain_id,
  r.id as review_id,
  r.review_text,
  r.rating,
  r.instagram_url,
  r.instagram_image_url,
  r.instagram_caption,
  r.author_type,
  r.reviewer_name,
  coalesce(r.reviewed_at, r.visit_date::timestamptz, r.created_at) as reviewed_at,
  r.created_at
from public.fountains f
left join lateral (
  select r.id, r.review_text, r.rating, r.instagram_url, r.instagram_image_url,
         r.instagram_caption, r.author_type, r.reviewer_name,
         r.reviewed_at, r.visit_date, r.created_at
  from public.reviews r
  where r.fountain_id = f.id
    and r.status = 'approved'
  order by coalesce(r.reviewed_at, r.visit_date::timestamptz, r.created_at) desc
  limit 1
) r on true;

create view public.fountain_overview_view
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
  f.is_indoor,
  ratings.admin_average_rating,
  ratings.public_average_rating,
  ratings.public_review_count,
  latest_admin.rating as latest_admin_rating,
  latest_public.rating as latest_public_rating,
  greatest(f.last_verified_at, ratings.last_rated_visit_date) as last_seen_working_at
from public.fountains f
left join public.cities c on c.id = f.city_id
left join public.sources s on s.id = f.source_id
left join public.fountain_ratings_view ratings on ratings.fountain_id = f.id
left join public.fountain_latest_review_view latest on latest.fountain_id = f.id
left join lateral (
  select r.rating
  from public.reviews r
  where r.fountain_id = f.id and r.status = 'approved'
    and r.author_type = 'admin' and r.rating is not null
  order by coalesce(r.reviewed_at, r.visit_date::timestamptz, r.created_at) desc
  limit 1
) latest_admin on true
left join lateral (
  select r.rating
  from public.reviews r
  where r.fountain_id = f.id and r.status = 'approved'
    and r.author_type = 'public' and r.rating is not null
  order by coalesce(r.reviewed_at, r.visit_date::timestamptz, r.created_at) desc
  limit 1
) latest_public on true;

-- grants exactly as the views had them before
revoke all on public.fountain_latest_review_view, public.fountain_overview_view from anon, authenticated;
grant select on public.fountain_latest_review_view, public.fountain_overview_view to anon, authenticated;
grant all on public.fountain_latest_review_view, public.fountain_overview_view to service_role;

-- the old submit_public_review(), as migration 20261027000642 created it
drop function public.submit_public_review(uuid, numeric, text, text, date, text, boolean, boolean, boolean);

create function public.submit_public_review(
  p_fountain_id   uuid,
  p_rating        numeric,
  p_review_text   text default null,
  p_reviewer_name text default null,
  p_visit_date    date default null,
  p_website       text default null      -- hidden honeypot field; people leave it blank
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  max_text_length   constant int := 500;
  max_name_length   constant int := 40;
  max_per_fountain  constant int := 3;    -- public reviews per fountain per hour
  max_overall       constant int := 30;   -- public reviews per hour, all fountains
  v_today date := (now() at time zone 'America/Vancouver')::date;
  v_text  text := nullif(btrim(p_review_text), '');
  v_name  text := nullif(btrim(p_reviewer_name), '');
  v_date  date := coalesce(p_visit_date, v_today);
begin
  if coalesce((select s.value from public.settings s where s.key = 'public_reviews_open'), 'false') <> 'true' then
    raise exception 'reviews_closed';
  end if;
  if coalesce(btrim(p_website), '') <> '' then
    raise exception 'rejected';
  end if;
  if not exists (select 1 from public.fountains f where f.id = p_fountain_id) then
    raise exception 'fountain_not_found';
  end if;
  -- 0 to 10 in steps of 0.5
  if p_rating is null or p_rating < 0 or p_rating > 10 or p_rating * 2 <> trunc(p_rating * 2) then
    raise exception 'bad_rating';
  end if;
  if length(v_text) > max_text_length then
    raise exception 'text_too_long';
  end if;
  -- cheap spam filter: no web links in the text
  if v_text ilike '%http%' or v_text ilike '%www.%' then
    raise exception 'link_in_text';
  end if;
  if length(v_name) > max_name_length then
    raise exception 'name_too_long';
  end if;
  -- no HTML in anything shown on the map
  if v_text ~ '[<>]' or v_name ~ '[<>]' then
    raise exception 'bad_characters';
  end if;
  if v_date > v_today or v_date < date '2020-01-01' then
    raise exception 'bad_visit_date';
  end if;

  -- one submission at a time, so two at once cannot both slip under a cap
  perform pg_advisory_xact_lock(hashtext('submit_public_review'));
  if (select count(*) from public.reviews r
      where r.fountain_id = p_fountain_id and r.author_type = 'public'
        and r.created_at > now() - interval '1 hour') >= max_per_fountain then
    raise exception 'too_many_for_fountain';
  end if;
  if (select count(*) from public.reviews r
      where r.author_type = 'public' and r.created_at > now() - interval '1 hour') >= max_overall then
    raise exception 'too_many_overall';
  end if;

  -- created_by stays blank: public reviews are anonymous even if the
  -- sender happens to be signed in
  insert into public.reviews (fountain_id, author_type, status, rating, review_text, reviewer_name, visit_date, created_by)
  values (p_fountain_id, 'public', 'pending', p_rating, v_text, v_name, v_date, null);

  return true;
end;
$$;

revoke execute on function public.submit_public_review(uuid, numeric, text, text, date, text) from public;
grant execute on function public.submit_public_review(uuid, numeric, text, text, date, text) to anon, authenticated;

-- dropping the columns also drops their column grants
alter table public.reviews
  drop column has_bottle_filler,
  drop column is_wheelchair_accessible,
  drop column anti_freeze;

-- the two issue_note check constraints go with their columns
alter table public.fountains
  drop column anti_freeze,
  drop column issue_reported_at,
  drop column issue_note;

commit;
