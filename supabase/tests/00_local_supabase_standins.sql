-- =====================================================================
-- Local test database only. NEVER run this on Supabase.
-- ---------------------------------------------------------------------
-- A plain Postgres + PostGIS database is missing the pieces Supabase
-- adds for you. This file creates small stand-ins so the real migration
-- files can be tested locally:
--   * the API roles: anon (not logged in), authenticated (logged in),
--     service_role (server-side key, skips row level security)
--   * auth.users and auth.uid() (who is logged in)
--   * the "extensions" schema where Supabase installs PostGIS
--   * Supabase's default grants (API roles get table access; RLS
--     policies then decide which rows they actually see)
--
-- How to "log in" during a test (inside a transaction):
--   set local role authenticated;
--   set local request.jwt.claims = '{"sub":"<user uuid>","role":"authenticated"}';
-- =====================================================================

-- API roles ------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon')          then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role')  then create role service_role nologin bypassrls; end if;
end $$;

-- auth schema: users table + auth.uid() --------------------------------
create schema if not exists auth;
create table if not exists auth.users (
  id    uuid primary key,
  email text
);

-- same logic as Supabase: read the user id from the JWT claims
create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(
    coalesce(
      current_setting('request.jwt.claim.sub', true),
      current_setting('request.jwt.claims', true)::jsonb ->> 'sub'
    ), ''
  )::uuid;
$$;

grant usage on schema auth to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;

-- extensions schema (Supabase keeps PostGIS here) -----------------------
create schema if not exists extensions;
grant usage on schema extensions to anon, authenticated, service_role;
create extension if not exists pgcrypto with schema extensions;

-- Supabase's default grants on the public schema ------------------------
grant usage on schema public to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables    to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;

-- the core schema calls gen_random_uuid(); make it findable
do $$
begin
  execute format('alter database %I set search_path = public, extensions', current_database());
  execute format('alter database %I set timezone = %L', current_database(), 'UTC');   -- same as Supabase
end $$;
