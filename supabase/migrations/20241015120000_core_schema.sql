-- sets up the simplified fountain and review schema with views and rls

create extension if not exists "pgcrypto";

-- table: cities
create table if not exists public.cities (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  created_at timestamptz not null default now()
);

-- table: sources tracks where fountain records originate
create table if not exists public.sources (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  url text,
  created_at timestamptz not null default now()
);

-- table: admins links supabase auth users to elevated permissions
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now()
);

-- helper to make admin checks reusable in row level security
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

-- table: fountains stores core fountain metadata
create table if not exists public.fountains (
  id uuid primary key default gen_random_uuid(),
  external_id text unique,
  city_id uuid references public.cities(id),
  source_id uuid references public.sources(id),
  name text not null,
  neighbourhood text,
  location_description text,
  latitude double precision not null,
  longitude double precision not null,
  operational_status text not null default 'unknown' check (
    operational_status in ('operational', 'seasonal', 'closed', 'unknown')
  ),
  season_note text,
  pet_friendly text not null default 'unknown' check (
    pet_friendly in ('yes', 'no', 'unknown')
  ),
  has_bottle_filler boolean,
  is_wheelchair_accessible boolean,
  last_verified_at date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- table: reviews stores admin and community feedback
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  fountain_id uuid not null references public.fountains(id) on delete cascade,
  author_type text not null default 'public' check (
    author_type in ('public', 'admin')
  ),
  status text not null default 'pending' check (
    status in ('pending', 'approved', 'rejected')
  ),
  rating numeric(4,1) check (rating is null or (rating >= 0 and rating <= 10)),
  water_quality numeric(4,1) check (water_quality is null or (water_quality >= 0 and water_quality <= 10)),
  flow_pressure numeric(4,1) check (flow_pressure is null or (flow_pressure >= 0 and flow_pressure <= 10)),
  temperature numeric(4,1) check (temperature is null or (temperature >= 0 and temperature <= 10)),
  cleanliness numeric(4,1) check (cleanliness is null or (cleanliness >= 0 and cleanliness <= 10)),
  accessibility numeric(4,1) check (accessibility is null or (accessibility >= 0 and accessibility <= 10)),
  review_text text,
  reviewer_name text,
  reviewer_email text,
  instagram_url text,
  instagram_image_url text,
  instagram_caption text,
  visit_date date,
  reviewed_at timestamptz,
  approved_by uuid references public.admins(user_id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- trigger keeps updated_at fresh for mutable tables
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger fountains_touch_updated_at
before update on public.fountains
for each row
execute procedure public.touch_updated_at();

create trigger reviews_touch_updated_at
before update on public.reviews
for each row
execute procedure public.touch_updated_at();

create index if not exists idx_fountains_city on public.fountains(city_id);
create index if not exists idx_fountains_source on public.fountains(source_id);
create index if not exists idx_fountains_location on public.fountains using gist (point(longitude, latitude));

create index if not exists idx_reviews_fountain on public.reviews(fountain_id);
create index if not exists idx_reviews_status on public.reviews(status);
create index if not exists idx_reviews_created on public.reviews(created_at desc);

-- ratings view surfaces per-fountain averages for approved reviews
create or replace view public.fountain_ratings_view as
select
  f.id as fountain_id,
  round(avg(r.rating)::numeric, 2) as average_rating,
  count(r.*) filter (where r.status = 'approved') as approved_review_count,
  count(r.*) filter (
    where r.status = 'approved' and r.author_type = 'admin'
  ) as admin_review_count
from public.fountains f
left join public.reviews r on r.fountain_id = f.id and r.status = 'approved'
group by f.id;

-- latest review view exposes the freshest approved review per fountain
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
  select *
  from public.reviews r
  where r.fountain_id = f.id
    and r.status = 'approved'
  order by coalesce(r.reviewed_at, r.visit_date::timestamptz, r.created_at) desc
  limit 1
) r on true;

-- overview view combines base fountain data with summary metrics
create or replace view public.fountain_overview_view as
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
  latest.reviewed_at as latest_reviewed_at
from public.fountains f
left join public.cities c on c.id = f.city_id
left join public.sources s on s.id = f.source_id
left join public.fountain_ratings_view ratings on ratings.fountain_id = f.id
left join public.fountain_latest_review_view latest on latest.fountain_id = f.id;

-- row level security policies
alter table public.cities enable row level security;
alter table public.sources enable row level security;
alter table public.fountains enable row level security;
alter table public.reviews enable row level security;
alter table public.admins enable row level security;

create policy cities_select_public on public.cities
for select using (true);

create policy cities_admin_manage on public.cities
for all using (public.is_admin())
with check (public.is_admin());

create policy sources_select_public on public.sources
for select using (true);

create policy sources_admin_manage on public.sources
for all using (public.is_admin())
with check (public.is_admin());

create policy fountains_select_public on public.fountains
for select using (true);

create policy fountains_admin_manage on public.fountains
for all using (public.is_admin())
with check (public.is_admin());

create policy reviews_select_public on public.reviews
for select using (status = 'approved');

create policy reviews_admin_select on public.reviews
for select using (public.is_admin());

create policy reviews_public_insert on public.reviews
for insert with check (
  status = 'pending'
  and author_type = 'public'
);

create policy reviews_admin_insert on public.reviews
for insert with check (public.is_admin());

create policy reviews_admin_update on public.reviews
for update using (public.is_admin())
with check (public.is_admin());

create policy reviews_admin_delete on public.reviews
for delete using (public.is_admin());

create policy admins_admin_manage on public.admins
for all using (public.is_admin())
with check (public.is_admin());

-- grant access to anon and authenticated roles
grant usage on schema public to anon, authenticated;
grant select on public.cities, public.sources, public.fountains to anon, authenticated;
grant select on public.fountain_ratings_view, public.fountain_latest_review_view, public.fountain_overview_view to anon, authenticated;
grant insert on public.reviews to anon;
grant insert, update, delete on public.reviews to authenticated;

grant select, insert, update on public.admins to authenticated;

grant usage on all sequences in schema public to anon, authenticated;
