-- step-by-step guide (run inside the supabase sql editor)
-- 1. take a manual backup or export of the existing tables before making changes.
-- 2. run this script to copy data into the new normalized layout.
-- 3. run db/schema.sql, db/views.sql, and db/policies.sql to recreate triggers, views, and rls.
-- 4. verify the row counts printed at the end, then drop the *_legacy tables when satisfied.

begin;

-- drop derived views so renames succeed without dependency errors
drop view if exists public.fountain_overview_view;
drop view if exists public.fountains_public;
drop view if exists public.fountain_latest_review;
drop view if exists public.fountain_review_stats;
drop view if exists public.approved_reviews;

-- create fresh tables with the target structure
create table if not exists public.cities_new (
  id uuid primary key,
  name text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.sources_new (
  id uuid primary key,
  name text not null unique,
  contact_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.fountains_new (
  id uuid primary key,
  city_id uuid not null,
  source_id uuid,
  name text not null,
  neighbourhood text,
  location_description text,
  latitude double precision not null,
  longitude double precision not null,
  operational text not null check (
    operational in ('operational', 'seasonal', 'unknown')
  ),
  operational_season text,
  pet_friendly text not null check (
    pet_friendly in ('y', 'n', 'unknown')
  ),
  has_bottle_filler boolean,
  is_wheelchair_accessible boolean,
  last_verified_at date,
  external_id text unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.reviews_new (
  id uuid primary key,
  fountain_id uuid not null references public.fountains_new(id) on delete cascade,
  reviewer_type text not null check (
    reviewer_type in ('public', 'admin')
  ),
  rating integer not null check (rating between 1 and 10),
  title text,
  reviewer_name text,
  body text,
  status text not null check (
    status in ('pending', 'approved', 'rejected')
  ),
  instagram_url text,
  instagram_image_url text,
  instagram_caption text,
  created_by uuid,
  created_at timestamptz not null default now()
);

create table if not exists public.admins_new (
  user_id uuid primary key,
  email text unique not null,
  created_at timestamptz not null default now()
);

-- seed cities and sources
insert into public.cities_new (id, name, created_at)
select distinct on (c.id)
  c.id,
  trim(c.name),
  coalesce(c.created_at, now())
from public.cities c
where c.id is not null
on conflict (id) do nothing;

insert into public.cities_new (id, name)
select gen_random_uuid(), 'Unknown City'
where not exists (
  select 1 from public.cities_new where lower(name) = 'unknown city'
);

insert into public.sources_new (id, name, contact_url, created_at)
select distinct on (s.id)
  s.id,
  trim(s.name),
  s.url,
  coalesce(s.created_at, now())
from public.sources s
where s.id is not null
on conflict (id) do nothing;

insert into public.sources_new (id, name)
select gen_random_uuid(), 'Unknown Source'
where not exists (
  select 1 from public.sources_new where lower(name) = 'unknown source'
);

-- copy fountain rows with normalization
with city_defaults as (
  select id from public.cities_new where lower(name) = 'unknown city' limit 1
), source_defaults as (
  select id from public.sources_new where lower(name) = 'unknown source' limit 1
)
insert into public.fountains_new (
  id,
  city_id,
  source_id,
  name,
  neighbourhood,
  location_description,
  latitude,
  longitude,
  operational,
  operational_season,
  pet_friendly,
  has_bottle_filler,
  is_wheelchair_accessible,
  last_verified_at,
  external_id,
  is_active,
  created_at,
  updated_at
)
select
  coalesce(f.id, gen_random_uuid()),
  coalesce(f.city_id, (select id from city_defaults)),
  coalesce(f.source_id, (select id from source_defaults)),
  coalesce(nullif(trim(f.name), ''), 'Unnamed Fountain'),
  f.neighbourhood,
  f.location_description,
  f.latitude::double precision,
  f.longitude::double precision,
  case
    when lower(f.operational_status) in ('operational', 'open') then 'operational'
    when lower(f.operational_status) like 'season%' then 'seasonal'
    when lower(f.operational_status) in ('seasonal', 'seasonal operation') then 'seasonal'
    when lower(f.operational_status) in ('closed', 'inactive', 'out of service') then 'unknown'
    when lower(f.operational_status) = 'unknown' then 'unknown'
    else 'unknown'
  end,
  nullif(trim(f.season_note), ''),
  case
    when f.pet_friendly in ('y', 'n', 'unknown') then f.pet_friendly
    when lower(f.pet_friendly) like 'y%' then 'y'
    when lower(f.pet_friendly) like 'n%' then 'n'
    when f.pet_friendly = true then 'y'
    when f.pet_friendly = false then 'n'
    else 'unknown'
  end,
  f.has_bottle_filler,
  f.is_wheelchair_accessible,
  f.last_verified_at,
  f.external_id,
  coalesce(f.is_active, true),
  coalesce(f.created_at, now()),
  coalesce(f.updated_at, now())
from public.fountains f;

-- copy review rows with normalization
insert into public.reviews_new (
  id,
  fountain_id,
  reviewer_type,
  rating,
  title,
  reviewer_name,
  body,
  status,
  instagram_url,
  instagram_image_url,
  instagram_caption,
  created_by,
  created_at
)
select
  coalesce(r.id, gen_random_uuid()),
  coalesce(r.fountain_id, f_new.id),
  case
    when lower(coalesce(r.author_type, r.reviewer_type)) = 'admin' then 'admin'
    else 'public'
  end,
  greatest(1, least(10, round(coalesce(r.rating, 5))::int)),
  null,
  nullif(trim(r.reviewer_name), ''),
  coalesce(nullif(trim(r.review_text), ''), nullif(trim(r.instagram_caption), '')),
  case
    when lower(r.status) = 'approved' then 'approved'
    when lower(r.status) = 'rejected' then 'rejected'
    else 'pending'
  end,
  r.instagram_url,
  r.instagram_image_url,
  r.instagram_caption,
  null,
  coalesce(r.created_at, now())
from public.reviews r
left join public.fountains_new f_new on f_new.id = r.fountain_id;

-- copy admin rows
insert into public.admins_new (user_id, email, created_at)
select a.user_id, trim(a.email), coalesce(a.created_at, now())
from public.admins a;

-- rename old tables out of the way
alter table public.reviews rename to reviews_legacy;
alter table public.fountains rename to fountains_legacy;
alter table public.sources rename to sources_legacy;
alter table public.cities rename to cities_legacy;
alter table public.admins rename to admins_legacy;

-- promote new tables into place
alter table public.cities_new rename to cities;
alter table public.sources_new rename to sources;
alter table public.fountains_new rename to fountains;
alter table public.reviews_new rename to reviews;
alter table public.admins_new rename to admins;

commit;

-- verification helpers
select 'cities count' as label, count(*) from public.cities;
select 'sources count' as label, count(*) from public.sources;
select 'fountains count' as label, count(*) from public.fountains;
select 'reviews count' as label, count(*) from public.reviews;
select 'admins count' as label, count(*) from public.admins;
