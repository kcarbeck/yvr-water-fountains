-- =====================================================================
-- Public reviews and reports: database side
-- =====================================================================
-- Adds what the review page needs before it can be built. Nothing on
-- the site changes: the public form stays closed until the
-- public_reviews_open setting is switched on.
--
--   1. settings table with one switch, public_reviews_open (off)
--   2. reviews.created_by: which admin added a review
--   3. submit_public_review(): the only way the public adds a review.
--      Reviews land as pending; nothing reaches the map until an admin
--      approves it. Direct inserts into reviews stay admin-only.
--   4. reports table and submit_report(): "not working", "wrong spot",
--      "missing fountain" and similar, readable only by admins
--   5. new rating columns on the map views, from approved reviews only
--   6. index for the hourly caps and the admin queue
--
-- Rollback: supabase/rollbacks/rollback_20261027000642_public_reviews.sql
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. settings: switches an admin can flip without a deploy
-- ---------------------------------------------------------------------
create table public.settings (
  key   text primary key,
  value text not null
);

insert into public.settings (key, value) values ('public_reviews_open', 'false');

alter table public.settings enable row level security;
create policy settings_select on public.settings for select using (true);
create policy settings_insert on public.settings for insert with check ((select public.is_admin()));
create policy settings_update on public.settings for update using ((select public.is_admin())) with check ((select public.is_admin()));
create policy settings_delete on public.settings for delete using ((select public.is_admin()));

-- the public only reads; writes are further limited to admins by RLS
revoke all on public.settings from anon, authenticated;
grant select on public.settings to anon;
grant select, insert, update, delete on public.settings to authenticated;


-- ---------------------------------------------------------------------
-- 2. who added each review
-- ---------------------------------------------------------------------
-- Filled automatically from the login. Existing reviews stay blank.
alter table public.reviews
  add column created_by uuid default auth.uid() references auth.users (id) on delete set null;

-- Signed-in users only. Admins and other signed-in users share the
-- authenticated role, so a column grant cannot single out admins; with
-- sign-ups off, every signed-in user is an invited admin.
grant select (created_by) on public.reviews to authenticated;


-- ---------------------------------------------------------------------
-- 3. submit_public_review(): the public review form calls this
-- ---------------------------------------------------------------------
-- Runs as the owner (security definer) so it can insert past the
-- admin-only insert policy, but only ever inserts a pending public
-- review. Each refusal raises an error whose message the page turns
-- into a plain sentence. Limits are set at the top of the body.
-- Dates are Vancouver dates, not the database's UTC date.
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


-- ---------------------------------------------------------------------
-- 4. reports from the public
-- ---------------------------------------------------------------------
create table public.reports (
  id            uuid primary key default gen_random_uuid(),
  fountain_id   uuid references public.fountains (id) on delete set null,   -- blank for a missing fountain
  kind          text not null check (kind in ('not_working', 'winter_off', 'working_again',
                                              'wrong_location', 'missing_fountain', 'other')),
  details       text check (length(details) <= 500),
  latitude      double precision check (latitude between -90 and 90),      -- pin for a missing fountain
  longitude     double precision check (longitude between -180 and 180),
  reporter_name text check (length(reporter_name) <= 40),
  status        text not null default 'open' check (status in ('open', 'done')),
  created_at    timestamptz not null default now()
);

-- admins read and close reports; nobody inserts directly (only through
-- submit_report below) and nobody deletes through the API
alter table public.reports enable row level security;
create policy reports_select on public.reports for select using ((select public.is_admin()));
create policy reports_update on public.reports for update using ((select public.is_admin())) with check ((select public.is_admin()));

revoke all on public.reports from anon, authenticated;
grant select, update on public.reports to authenticated;

create function public.submit_report(
  p_fountain_id   uuid,
  p_kind          text,
  p_details       text default null,
  p_latitude      double precision default null,
  p_longitude     double precision default null,
  p_reporter_name text default null,
  p_website       text default null      -- hidden honeypot field
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  max_text_length constant int := 500;
  max_name_length constant int := 40;
  max_overall     constant int := 30;   -- reports per hour, all fountains
  v_details text := nullif(btrim(p_details), '');
  v_name    text := nullif(btrim(p_reporter_name), '');
begin
  if coalesce(btrim(p_website), '') <> '' then
    raise exception 'rejected';
  end if;
  if p_kind is null or p_kind not in ('not_working', 'winter_off', 'working_again',
                                      'wrong_location', 'missing_fountain', 'other') then
    raise exception 'bad_kind';
  end if;
  -- a missing fountain needs a pin; every other kind is about a fountain on the map
  if p_kind = 'missing_fountain' and (p_latitude is null or p_longitude is null) then
    raise exception 'pin_needed';
  end if;
  if (p_fountain_id is null and p_kind not in ('missing_fountain', 'other'))
     or (p_fountain_id is not null and not exists (select 1 from public.fountains f where f.id = p_fountain_id)) then
    raise exception 'fountain_not_found';
  end if;
  -- a pin must be complete and inside Metro Vancouver (the map's area)
  if (p_latitude is null) <> (p_longitude is null)
     or p_latitude not between 49.0 and 49.6
     or p_longitude not between -123.5 and -122.4 then
    raise exception 'bad_pin';
  end if;
  if length(v_details) > max_text_length then
    raise exception 'text_too_long';
  end if;
  if length(v_name) > max_name_length then
    raise exception 'name_too_long';
  end if;
  if v_details ~ '[<>]' or v_name ~ '[<>]' then
    raise exception 'bad_characters';
  end if;

  perform pg_advisory_xact_lock(hashtext('submit_report'));
  if (select count(*) from public.reports r where r.created_at > now() - interval '1 hour') >= max_overall then
    raise exception 'too_many_overall';
  end if;

  insert into public.reports (fountain_id, kind, details, latitude, longitude, reporter_name)
  values (p_fountain_id, p_kind, v_details, p_latitude, p_longitude, v_name);

  return true;
end;
$$;

revoke execute on function public.submit_report(uuid, text, text, double precision, double precision, text, text) from public;
grant execute on function public.submit_report(uuid, text, text, double precision, double precision, text, text) to anon, authenticated;


-- ---------------------------------------------------------------------
-- 5. rating columns for the map: ours, the public's, latest of each
-- ---------------------------------------------------------------------
-- Every new number comes from approved reviews only: the averages from
-- the existing join (status = 'approved' is in the join condition), the
-- latest ratings from lateral joins that filter the same way. Admins can
-- read pending reviews, so a filter anywhere else would leak pending
-- ratings onto an admin's map. Columns are added at the end, so nothing
-- existing moves.
create or replace view public.fountain_ratings_view
with (security_invoker = true) as
select
  f.id as fountain_id,
  round(avg(r.rating)::numeric, 2) as average_rating,
  count(r.id) filter (where r.status = 'approved') as approved_review_count,
  count(r.id) filter (where r.status = 'approved' and r.author_type = 'admin') as admin_review_count,
  round(avg(r.rating) filter (where r.author_type = 'admin')::numeric, 2) as admin_average_rating,
  round(avg(r.rating) filter (where r.author_type = 'public')::numeric, 2) as public_average_rating,
  count(r.id) filter (where r.status = 'approved' and r.author_type = 'public') as public_review_count,
  -- a rated review means someone saw the fountain working that day
  max(coalesce(r.visit_date, r.reviewed_at::date, r.created_at::date)) filter (where r.rating is not null) as last_rated_visit_date
from public.fountains f
left join public.reviews r on r.fountain_id = f.id and r.status = 'approved'
group by f.id;

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
  greatest(f.last_verified_at, ratings.last_rated_visit_date) as last_seen_working_at
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


-- ---------------------------------------------------------------------
-- 6. keeps the hourly-cap counts and the admin queue cheap
-- ---------------------------------------------------------------------
create index idx_reviews_fountain_status_created on public.reviews (fountain_id, status, created_at);
