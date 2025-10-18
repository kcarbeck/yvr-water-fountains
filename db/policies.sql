-- configures row level security for public and admin interactions

create or replace function public.is_admin()
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.admins a
    where a.user_id = auth.uid()
  );
$$;

alter table public.cities enable row level security;
alter table public.sources enable row level security;
alter table public.fountains enable row level security;
alter table public.reviews enable row level security;
alter table public.admins enable row level security;

-- cities policies
create policy cities_select_public on public.cities
for select
using (true);

create policy cities_manage_admin on public.cities
for all
using (public.is_admin())
with check (public.is_admin());

-- sources policies
create policy sources_select_public on public.sources
for select
using (true);

create policy sources_manage_admin on public.sources
for all
using (public.is_admin())
with check (public.is_admin());

-- fountains policies
create policy fountains_select_public on public.fountains
for select
using (coalesce(is_active, true));

create policy fountains_manage_admin on public.fountains
for all
using (public.is_admin())
with check (public.is_admin());

-- reviews policies
create policy reviews_select_public on public.reviews
for select
using (status = 'approved');

create policy reviews_select_admin on public.reviews
for select
using (public.is_admin());

create policy reviews_insert_public on public.reviews
for insert
with check (
  reviewer_type = 'public'
  and coalesce(instagram_url, '') = ''
  and coalesce(instagram_image_url, '') = ''
  and coalesce(instagram_caption, '') = ''
);

create policy reviews_insert_admin on public.reviews
for insert
with check (public.is_admin());

create policy reviews_update_admin on public.reviews
for update
using (public.is_admin())
with check (public.is_admin());

create policy reviews_delete_admin on public.reviews
for delete
using (public.is_admin());

-- admins policies
create policy admins_select_admin on public.admins
for select
using (public.is_admin());

create policy admins_manage_admin on public.admins
for all
using (public.is_admin())
with check (public.is_admin());

-- allow read access for anon and authenticated roles
grant usage on schema public to anon, authenticated;
grant select on public.cities, public.sources, public.fountains_public to anon, authenticated;
grant select on public.approved_reviews, public.fountain_review_stats, public.fountain_latest_review to anon, authenticated;
grant insert on public.reviews to anon;
grant insert, update, delete on public.reviews to authenticated;

grant select, insert, update on public.admins to authenticated;

grant usage on all sequences in schema public to anon, authenticated;
