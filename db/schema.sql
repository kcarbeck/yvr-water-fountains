-- sets up the core tables for fountains, reviews, and admin access

create extension if not exists "pgcrypto";

-- table: cities keeps the list of municipalities covered by the map
create table if not exists public.cities (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

-- table: sources records where each fountain entry originated
create table if not exists public.sources (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  contact_url text,
  created_at timestamptz not null default now()
);

-- table: fountains stores the canonical fountain metadata
create table if not exists public.fountains (
  id uuid primary key default gen_random_uuid(),
  city_id uuid not null references public.cities(id),
  source_id uuid references public.sources(id),
  name text not null,
  neighbourhood text,
  location_description text,
  latitude double precision not null,
  longitude double precision not null,
  operational text not null default 'unknown' check (
    operational in ('operational', 'seasonal', 'unknown')
  ),
  operational_season text,
  pet_friendly text not null default 'unknown' check (
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

-- table: reviews captures public and admin feedback tied to each fountain
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  fountain_id uuid not null references public.fountains(id) on delete cascade,
  reviewer_type text not null default 'public' check (
    reviewer_type in ('public', 'admin')
  ),
  rating integer not null check (rating between 1 and 10),
  title text,
  reviewer_name text,
  body text,
  status text not null default 'pending' check (
    status in ('pending', 'approved', 'rejected')
  ),
  instagram_url text,
  instagram_image_url text,
  instagram_caption text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

-- table: admins lists supabase accounts allowed to moderate content
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null,
  created_at timestamptz not null default now()
);

-- trigger helper to refresh updated_at on fountains
create or replace function public.touch_fountain_updated_at()
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
execute procedure public.touch_fountain_updated_at();

-- trigger helper to enforce reviewer defaults on insert
create or replace function public.reviews_enforce_defaults()
returns trigger
language plpgsql
as $$
begin
  if new.created_by is null then
    new.reviewer_type := 'public';
    new.status := 'pending';
    new.instagram_url := null;
    new.instagram_image_url := null;
    new.instagram_caption := null;
  end if;

  if new.reviewer_type = 'admin' then
    if new.status is null then
      new.status := 'approved';
    end if;
    if new.created_by is null then
      new.created_by := auth.uid();
    end if;
  end if;

  return new;
end;
$$;

create trigger reviews_before_insert_defaults
before insert on public.reviews
for each row
execute procedure public.reviews_enforce_defaults();

-- indexes to speed lookups on foreign keys and active fountains
create index if not exists idx_fountains_city_id on public.fountains(city_id);
create index if not exists idx_fountains_source_id on public.fountains(source_id);
create index if not exists idx_fountains_active on public.fountains(is_active) where is_active = true;
create index if not exists idx_fountains_location on public.fountains using gist (point(longitude, latitude));

create index if not exists idx_reviews_fountain_id on public.reviews(fountain_id);
create index if not exists idx_reviews_status on public.reviews(status);
create index if not exists idx_reviews_created_at on public.reviews(created_at desc);
