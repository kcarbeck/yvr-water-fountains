create extension if not exists postgis;

create table fountains (
  id uuid primary key default gen_random_uuid(),
  name text,
  location_note text,
  maintainer text,
  in_operation text,
  pet_friendly text,
  photo_name text,
  geo_local_area text,
  lat float8,
  lon float8,
  location geometry(Point, 4326),
  original_mapid text
);

create table ratings (
  id uuid primary key default gen_random_uuid(),
  fountain_id uuid references fountains(id),
  ig_post_url text,
  rating float,
  flow int,
  temp int,
  drainage int,
  caption text,
  visited boolean,
  visit_date date
);