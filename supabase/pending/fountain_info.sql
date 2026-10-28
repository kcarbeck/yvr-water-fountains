-- =====================================================================
-- Fountain info and review dates: database side
-- =====================================================================
-- What the map's fountain info needs before it can be built. Nothing on
-- the site changes until the map and review pages are updated.
--
--   1. three "what the reviewer saw" columns on reviews, and the same
--      anti_freeze column on fountains; an open maintenance issue on
--      fountains (issue_reported_at, issue_note)
--   2. the latest review is the one with the newest visit date, not the
--      newest approval time (fountain_latest_review_view and the two
--      latest-rating lookups in fountain_overview_view)
--   3. new overview columns: latest_visit_date, anti_freeze,
--      issue_reported_at, issue_note
--   4. fountain_reviews_view: every approved review of a fountain, for
--      the "all visits" list (never reviewer_email or created_by)
--   5. submit_public_review() takes the three details
--
-- Rollback: supabase/rollbacks/rollback_fountain_info.sql
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. columns
-- ---------------------------------------------------------------------
-- null = unknown, true = yes, false = no, on both tables.
-- The fountain's columns are what the map shows. A review's columns are
-- what that reviewer saw: an admin's answers are also written to the
-- fountain by the review page; a visitor's are applied by an admin when
-- the review is approved.
--
-- An issue is something out of the ordinary that needs maintenance (no
-- water, low pressure, leaking, dirty). It is not a seasonal shut-off
-- (anti_freeze, operational_status and season_note cover that) and not
-- a permanent closure (operational_status = 'closed'). An admin opens an
-- issue by applying a report, with a short note written by the admin,
-- and clears it by setting both columns back to null. Nothing clears it
-- automatically.
alter table public.fountains
  add column anti_freeze       boolean,   -- expected to stay on through the winter
  add column issue_reported_at date,      -- null = no open issue
  add column issue_note        text,      -- short, written by an admin, e.g. "no water"
  add constraint fountains_issue_note_length check (btrim(issue_note) <> '' and length(issue_note) <= 120),
  add constraint fountains_issue_note_needs_date check (issue_note is null or issue_reported_at is not null);

alter table public.reviews
  add column has_bottle_filler        boolean,
  add column is_wheelchair_accessible boolean,
  add column anti_freeze              boolean;

-- reviews is readable column by column (reviewer_email is hidden), so
-- the new columns need their own grant. Insert and update on reviews
-- are table-wide for signed-in users, and fountains is table-wide too.
grant select (has_bottle_filler, is_wheelchair_accessible, anti_freeze) on public.reviews to anon, authenticated;


-- ---------------------------------------------------------------------
-- 2 and 3. latest review by visit date; new overview columns
-- ---------------------------------------------------------------------
-- A review's date is its visit date. reviewed_at only says when an
-- admin approved it (a March visit can be approved in October).
-- Both views keep every existing column in place; new ones go last.
create or replace view public.fountain_latest_review_view
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
  r.created_at,
  coalesce(r.visit_date, r.reviewed_at::date, r.created_at::date) as visit_date
from public.fountains f
left join lateral (
  select r.id, r.review_text, r.rating, r.instagram_url, r.instagram_image_url,
         r.instagram_caption, r.author_type, r.reviewer_name,
         r.reviewed_at, r.visit_date, r.created_at
  from public.reviews r
  where r.fountain_id = f.id
    and r.status = 'approved'
  order by coalesce(r.visit_date, r.reviewed_at::date, r.created_at::date) desc, r.created_at desc
  limit 1
) r on true;

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
  f.is_indoor,
  ratings.admin_average_rating,
  ratings.public_average_rating,
  ratings.public_review_count,
  latest_admin.rating as latest_admin_rating,
  latest_public.rating as latest_public_rating,
  greatest(f.last_verified_at, ratings.last_rated_visit_date) as last_seen_working_at,
  -- new from here
  latest.visit_date as latest_visit_date,
  f.anti_freeze,
  f.issue_reported_at,
  f.issue_note
from public.fountains f
left join public.cities c on c.id = f.city_id
left join public.sources s on s.id = f.source_id
left join public.fountain_ratings_view ratings on ratings.fountain_id = f.id
left join public.fountain_latest_review_view latest on latest.fountain_id = f.id
-- latest rated review of each kind, same order as fountain_latest_review_view
left join lateral (
  select r.rating
  from public.reviews r
  where r.fountain_id = f.id and r.status = 'approved'
    and r.author_type = 'admin' and r.rating is not null
  order by coalesce(r.visit_date, r.reviewed_at::date, r.created_at::date) desc, r.created_at desc
  limit 1
) latest_admin on true
left join lateral (
  select r.rating
  from public.reviews r
  where r.fountain_id = f.id and r.status = 'approved'
    and r.author_type = 'public' and r.rating is not null
  order by coalesce(r.visit_date, r.reviewed_at::date, r.created_at::date) desc, r.created_at desc
  limit 1
) latest_public on true;


-- ---------------------------------------------------------------------
-- 4. every approved review of a fountain, for the "all visits" list
-- ---------------------------------------------------------------------
-- Columns are named one by one so reviewer_email and created_by can
-- never reach the public. The page sorts by visit_date.
create view public.fountain_reviews_view
with (security_invoker = true) as
select
  r.id,
  r.fountain_id,
  r.author_type,
  r.reviewer_name,
  r.rating,
  r.review_text,
  r.instagram_url,
  coalesce(r.visit_date, r.reviewed_at::date, r.created_at::date) as visit_date,
  r.has_bottle_filler,
  r.is_wheelchair_accessible,
  r.anti_freeze,
  r.created_at
from public.reviews r
where r.status = 'approved';

revoke all on public.fountain_reviews_view from anon, authenticated;
grant select on public.fountain_reviews_view to anon, authenticated;


-- ---------------------------------------------------------------------
-- 5. submit_public_review(): the three details, optional
-- ---------------------------------------------------------------------
-- Postgres treats a changed argument list as a second function, so the
-- old one is dropped first. The new arguments come last, so every
-- existing call still works. The body is otherwise unchanged.
drop function public.submit_public_review(uuid, numeric, text, text, date, text);

create function public.submit_public_review(
  p_fountain_id   uuid,
  p_rating        numeric,
  p_review_text   text default null,
  p_reviewer_name text default null,
  p_visit_date    date default null,
  p_website       text default null,      -- hidden honeypot field; people leave it blank
  p_has_bottle_filler        boolean default null,
  p_is_wheelchair_accessible boolean default null,
  p_anti_freeze              boolean default null
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
  -- sender happens to be signed in. The details stay on the review until
  -- an admin applies them to the fountain.
  insert into public.reviews (fountain_id, author_type, status, rating, review_text, reviewer_name, visit_date, created_by,
                              has_bottle_filler, is_wheelchair_accessible, anti_freeze)
  values (p_fountain_id, 'public', 'pending', p_rating, v_text, v_name, v_date, null,
          p_has_bottle_filler, p_is_wheelchair_accessible, p_anti_freeze);

  return true;
end;
$$;

revoke execute on function public.submit_public_review(uuid, numeric, text, text, date, text, boolean, boolean, boolean) from public;
grant execute on function public.submit_public_review(uuid, numeric, text, text, date, text, boolean, boolean, boolean) to anon, authenticated;
