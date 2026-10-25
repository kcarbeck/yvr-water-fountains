-- =====================================================================
-- Fingerprint of the access rules and views in the public schema:
-- policies, table + column grants, view definitions and options,
-- function settings, indexes. Used to prove a rollback really restores
-- the earlier state: run before, change, roll back, run again, compare.
-- Read-only.
-- =====================================================================
select 'policies' as part, md5(string_agg(x, E'\n' order by x collate "C")) as md5, count(*) as n
from (select tablename || '|' || policyname || '|' || cmd || '|' || array_to_string(roles, ',') || '|' ||
             coalesce(qual, '') || '|' || coalesce(with_check, '') as x
      from pg_policies where schemaname = 'public') t
union all
select 'table grants', md5(string_agg(x, E'\n' order by x collate "C")), count(*)
from (select grantee || '|' || table_name || '|' || privilege_type as x
      from information_schema.role_table_grants
      where table_schema = 'public' and grantee in ('anon', 'authenticated')) t
union all
select 'column grants', md5(coalesce(string_agg(x, E'\n' order by x collate "C"), '')), count(*)
from (select grantee || '|' || table_name || '|' || column_name || '|' || privilege_type as x
      from information_schema.column_privileges
      where table_schema = 'public' and grantee in ('anon', 'authenticated')) t
union all
select 'views', md5(string_agg(x, E'\n' order by x collate "C")), count(*)
from (select c.relname || '|' || pg_get_viewdef(c.oid, true) || '|' || coalesce(array_to_string(c.reloptions, ','), '') as x
      from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind = 'v') t
union all
select 'functions', md5(string_agg(x, E'\n' order by x collate "C")), count(*)
from (select p.proname || '|' || p.prosecdef || '|' || coalesce(array_to_string(p.proconfig, ','), '') || '|' || p.prosrc as x
      from pg_proc p where p.pronamespace = 'public'::regnamespace) t
union all
select 'indexes', md5(string_agg(x, E'\n' order by x collate "C")), count(*)
from (select indexdef as x from pg_indexes where schemaname = 'public') t
order by 1;
