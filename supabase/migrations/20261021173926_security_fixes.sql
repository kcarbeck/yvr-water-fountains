-- =====================================================================
-- 2026-10-06  Security fixes (from the Supabase security advisor)
-- =====================================================================
-- What this fixes:
--   1. is_admin() was recursing forever. It reads the admins table, and
--      the admins table's own policy calls is_admin() again. Any query
--      that touched `reviews` through row level security crashed with
--      "stack depth limit exceeded" (this broke the admin + public forms).
--      Fix: run is_admin() as SECURITY DEFINER so it skips RLS on admins.
--   2. The three map views ran with the view owner's rights, skipping RLS.
--      Fix: security_invoker = true, so they obey the same rules as the
--      tables underneath (the public still only sees approved reviews).
--   3. Functions had no fixed search_path (a classic Postgres hardening).
--   4. Each table had two overlapping SELECT policies. Merged into one
--      policy per action so the rules are easier to read.
--   5. Missing index on reviews.approved_by.
--   6. Public (anon) role had write/truncate grants it never needs.
--   7. (added 2026-10-20 after local testing) reviewer_email and
--      approved_by are hidden from the public API roles, and the latest-
--      review view names its columns instead of using `select *`.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. helper functions
-- ---------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer          -- runs as owner, so it can read admins without RLS
set search_path = ''      -- never resolve names through the caller's path
as $$
  select exists (
    select 1
    from public.admins a
    where a.user_id = (select auth.uid())
  );
$$;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;


-- ---------------------------------------------------------------------
-- 2. views obey RLS of whoever is querying
-- ---------------------------------------------------------------------
-- (added 2026-10-20) The "latest review" view used `select *` on reviews,
-- which includes reviewer_email. Once the views run with the visitor's
-- own rights, and the public can no longer read that column (step 7),
-- `select *` would make the whole map fail. So name the columns instead.
-- The view's output is exactly the same as before.
create or replace view public.fountain_latest_review_view as
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

-- Same problem in the ratings view: count(r.*) reads the whole row,
-- reviewer_email included. count(r.id) gives the same numbers.
create or replace view public.fountain_ratings_view as
select
  f.id as fountain_id,
  round(avg(r.rating)::numeric, 2) as average_rating,
  count(r.id) filter (where r.status = 'approved') as approved_review_count,
  count(r.id) filter (where r.status = 'approved' and r.author_type = 'admin') as admin_review_count
from public.fountains f
left join public.reviews r on r.fountain_id = f.id and r.status = 'approved'
group by f.id;

alter view public.fountain_ratings_view       set (security_invoker = true);
alter view public.fountain_latest_review_view set (security_invoker = true);
alter view public.fountain_overview_view      set (security_invoker = true);


-- ---------------------------------------------------------------------
-- 4. one policy per table per action
--    pattern: everyone can read reference tables; only admins write
-- ---------------------------------------------------------------------

-- cities ---------------------------------------------------------------
drop policy if exists cities_admin_manage   on public.cities;
drop policy if exists cities_select_public  on public.cities;
create policy cities_select on public.cities for select using (true);
create policy cities_insert on public.cities for insert with check ((select public.is_admin()));
create policy cities_update on public.cities for update using ((select public.is_admin())) with check ((select public.is_admin()));
create policy cities_delete on public.cities for delete using ((select public.is_admin()));

-- sources --------------------------------------------------------------
drop policy if exists sources_admin_manage  on public.sources;
drop policy if exists sources_select_public on public.sources;
create policy sources_select on public.sources for select using (true);
create policy sources_insert on public.sources for insert with check ((select public.is_admin()));
create policy sources_update on public.sources for update using ((select public.is_admin())) with check ((select public.is_admin()));
create policy sources_delete on public.sources for delete using ((select public.is_admin()));

-- fountains ------------------------------------------------------------
drop policy if exists fountains_admin_manage  on public.fountains;
drop policy if exists fountains_select_public on public.fountains;
create policy fountains_select on public.fountains for select using (true);
create policy fountains_insert on public.fountains for insert with check ((select public.is_admin()));
create policy fountains_update on public.fountains for update using ((select public.is_admin())) with check ((select public.is_admin()));
create policy fountains_delete on public.fountains for delete using ((select public.is_admin()));

-- admins: you can see your own row; admins can see/manage all ----------
drop policy if exists admins_admin_manage on public.admins;
drop policy if exists admins_read_own     on public.admins;
create policy admins_select on public.admins for select
  using (user_id = (select auth.uid()) or (select public.is_admin()));
create policy admins_insert on public.admins for insert with check ((select public.is_admin()));
create policy admins_update on public.admins for update using ((select public.is_admin())) with check ((select public.is_admin()));
create policy admins_delete on public.admins for delete using ((select public.is_admin()));

-- reviews --------------------------------------------------------------
--   read:   public sees approved reviews; admins see everything
--   insert: public may only add a *pending public* review; admins anything
drop policy if exists reviews_select_public on public.reviews;
drop policy if exists reviews_admin_select  on public.reviews;
drop policy if exists reviews_public_insert on public.reviews;
drop policy if exists reviews_admin_insert  on public.reviews;
drop policy if exists reviews_admin_update  on public.reviews;
drop policy if exists reviews_admin_delete  on public.reviews;
create policy reviews_select on public.reviews for select
  using (status = 'approved' or (select public.is_admin()));
create policy reviews_insert on public.reviews for insert
  with check ((status = 'pending' and author_type = 'public') or (select public.is_admin()));
create policy reviews_update on public.reviews for update using ((select public.is_admin())) with check ((select public.is_admin()));
create policy reviews_delete on public.reviews for delete using ((select public.is_admin()));


-- ---------------------------------------------------------------------
-- 5. index the foreign key
-- ---------------------------------------------------------------------
create index if not exists idx_reviews_approved_by on public.reviews (approved_by);


-- ---------------------------------------------------------------------
-- 6. trim grants: nobody needs TRUNCATE/TRIGGER/REFERENCES via the API,
--    views are read-only, and the anonymous public only ever reads,
--    plus inserts pending reviews.
-- ---------------------------------------------------------------------
revoke truncate, trigger, references on all tables in schema public from anon, authenticated;
revoke insert, update, delete on public.fountain_ratings_view, public.fountain_latest_review_view, public.fountain_overview_view from anon, authenticated;
revoke insert, update, delete on public.cities, public.sources, public.fountains, public.admins from anon;
revoke update, delete on public.reviews from anon;


-- ---------------------------------------------------------------------
-- 7. (added 2026-10-20) private review columns
--    Before this migration nobody could read `reviews` directly (the
--    recursion bug crashed every query). Once it is fixed, anyone could
--    ask the API for approved reviews -- including reviewer_email.
--    Hide the private columns from the public API roles. The column list
--    below is every OTHER column; a new column added later must be
--    granted here too if the website needs to read it.
--    (Admins also lose direct access to emails; none are stored today
--     and the public form is paused. Revisit when it comes back.)
-- ---------------------------------------------------------------------
revoke select on public.reviews from anon, authenticated;
grant select (id, fountain_id, author_type, status, rating, review_text, reviewer_name,
              instagram_url, instagram_image_url, instagram_caption, visit_date,
              reviewed_at, created_at, updated_at)
  on public.reviews to anon, authenticated;
