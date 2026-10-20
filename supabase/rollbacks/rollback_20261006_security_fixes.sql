-- =====================================================================
-- ROLLBACK for supabase/migrations/20261006_security_fixes.sql
-- ---------------------------------------------------------------------
-- Puts the database back EXACTLY as it was on 2026-10-20 before the
-- security fixes, including the recursion bug and the over-wide grants.
-- Only use this if the fix broke something and you need the old state
-- back while we work out why. Run the pause rollback first if that
-- migration was applied too.
--
-- Tested on a local copy: after this file, the table fingerprints
-- (supabase/tests/checksums.sql), policies, grants and view definitions
-- match the pre-fix database.
-- =====================================================================

begin;

-- 1. functions back to their old bodies ---------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
security invoker
as $$
  select exists (
    select 1
    from public.admins a
    where a.user_id = auth.uid()
  );
$$;
alter function public.is_admin() reset search_path;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
alter function public.touch_updated_at() reset search_path;


-- 2. views: old definitions, owner's rights ------------------------------
-- (dropped and recreated because the old latest-review view used select *)
drop view if exists public.fountain_overview_view;
drop view if exists public.fountain_latest_review_view;
drop view if exists public.fountain_ratings_view;

create view public.fountain_ratings_view as
select
  f.id as fountain_id,
  round(avg(r.rating)::numeric, 2) as average_rating,
  count(r.*) filter (where r.status = 'approved') as approved_review_count,
  count(r.*) filter (where r.status = 'approved' and r.author_type = 'admin') as admin_review_count
from public.fountains f
left join public.reviews r on r.fountain_id = f.id and r.status = 'approved'
group by f.id;

create view public.fountain_latest_review_view as
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
  select *
  from public.reviews r
  where r.fountain_id = f.id
    and r.status = 'approved'
  order by coalesce(r.reviewed_at, r.visit_date::timestamptz, r.created_at) desc
  limit 1
) r on true;

create view public.fountain_overview_view as
select
  f.id, f.external_id, f.name, f.neighbourhood, f.location_description,
  f.latitude, f.longitude, f.operational_status, f.season_note, f.pet_friendly,
  f.has_bottle_filler, f.is_wheelchair_accessible, f.last_verified_at,
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
  latest.reviewed_at as latest_reviewed_at
from public.fountains f
left join public.cities c on c.id = f.city_id
left join public.sources s on s.id = f.source_id
left join public.fountain_ratings_view ratings on ratings.fountain_id = f.id
left join public.fountain_latest_review_view latest on latest.fountain_id = f.id;


-- 3. policies: remove the new ones, restore the old ones ------------------
drop policy if exists cities_select on public.cities;
drop policy if exists cities_insert on public.cities;
drop policy if exists cities_update on public.cities;
drop policy if exists cities_delete on public.cities;
drop policy if exists sources_select on public.sources;
drop policy if exists sources_insert on public.sources;
drop policy if exists sources_update on public.sources;
drop policy if exists sources_delete on public.sources;
drop policy if exists fountains_select on public.fountains;
drop policy if exists fountains_insert on public.fountains;
drop policy if exists fountains_update on public.fountains;
drop policy if exists fountains_delete on public.fountains;
drop policy if exists admins_select on public.admins;
drop policy if exists admins_insert on public.admins;
drop policy if exists admins_update on public.admins;
drop policy if exists admins_delete on public.admins;
drop policy if exists reviews_select on public.reviews;
drop policy if exists reviews_insert on public.reviews;
drop policy if exists reviews_update on public.reviews;
drop policy if exists reviews_delete on public.reviews;

create policy cities_select_public on public.cities for select using (true);
create policy cities_admin_manage on public.cities for all using (public.is_admin()) with check (public.is_admin());
create policy sources_select_public on public.sources for select using (true);
create policy sources_admin_manage on public.sources for all using (public.is_admin()) with check (public.is_admin());
create policy fountains_select_public on public.fountains for select using (true);
create policy fountains_admin_manage on public.fountains for all using (public.is_admin()) with check (public.is_admin());
create policy reviews_select_public on public.reviews for select using (status = 'approved');
create policy reviews_admin_select on public.reviews for select using (public.is_admin());
create policy reviews_public_insert on public.reviews for insert with check (status = 'pending' and author_type = 'public');
create policy reviews_admin_insert on public.reviews for insert with check (public.is_admin());
create policy reviews_admin_update on public.reviews for update using (public.is_admin()) with check (public.is_admin());
create policy reviews_admin_delete on public.reviews for delete using (public.is_admin());
create policy admins_admin_manage on public.admins for all using (public.is_admin()) with check (public.is_admin());
create policy admins_read_own on public.admins for select using (user_id = auth.uid());


-- 4. index added by the fix ---------------------------------------------
drop index if exists public.idx_reviews_approved_by;


-- 5. grants: back to Supabase's defaults (all privileges) ------------------
-- (revoking first also clears the column-level grants on reviews)
revoke all on public.reviews from anon, authenticated;
grant all on public.cities, public.sources, public.fountains, public.admins, public.reviews,
             public.fountain_ratings_view, public.fountain_latest_review_view,
             public.fountain_overview_view
  to anon, authenticated;

commit;
