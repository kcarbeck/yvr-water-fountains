-- =====================================================================
-- RLS test matrix: who can do what?
-- ---------------------------------------------------------------------
-- Tries every action as three kinds of visitor:
--   anon     = someone on the website who is not logged in
--   user     = logged in, but not an admin
--   admin    = logged in and listed in public.admins
-- and prints one row per test with PASS or FAIL.
--
-- Safe to run on production: every write is undone straight away, and
-- the whole file ends in ROLLBACK, so nothing is ever saved.
--
-- SETTINGS: the two test logins. On production, put the real admin's
-- user id in admin_id (find it with: select user_id from public.admins;).
-- user_id_nonadmin can be any uuid that is not an admin.
-- =====================================================================

begin;

create temp table rls_settings as
select '00000000-0000-0000-0000-00000000a0a0'::uuid as admin_id,
       '00000000-0000-0000-0000-00000000b0b0'::uuid as user_id_nonadmin;

-- What each visitor SHOULD be able to do. 'yes' = allowed, 'no' = blocked.
-- Public review form is switched off for now, so anon/user inserts = no.
-- Reviewer emails are hidden from the website's API for everyone,
-- admins included (none are stored; revisit when the form returns).
create temp table rls_expected (test text, who text, expected text);
insert into rls_expected values
  ('read approved reviews',          'anon', 'yes'), ('read approved reviews',          'user', 'yes'), ('read approved reviews',          'admin', 'yes'),
  ('read pending reviews',           'anon', 'no'),  ('read pending reviews',           'user', 'no'),  ('read pending reviews',           'admin', 'yes'),
  ('read reviewer emails',           'anon', 'no'),  ('read reviewer emails',           'user', 'no'),  ('read reviewer emails',           'admin', 'no'),
  ('insert pending public review',   'anon', 'no'),  ('insert pending public review',   'user', 'no'),  ('insert pending public review',   'admin', 'yes'),
  ('insert approved review',         'anon', 'no'),  ('insert approved review',         'user', 'no'),  ('insert approved review',         'admin', 'yes'),
  ('update reviews',                 'anon', 'no'),  ('update reviews',                 'user', 'no'),  ('update reviews',                 'admin', 'yes'),
  ('delete reviews',                 'anon', 'no'),  ('delete reviews',                 'user', 'no'),  ('delete reviews',                 'admin', 'yes'),
  ('read admins table',     'anon', 'no'),  ('read admins table',     'user', 'no'),  ('read admins table',     'admin', 'yes'),
  ('write fountains',                'anon', 'no'),  ('write fountains',                'user', 'no'),  ('write fountains',                'admin', 'yes'),
  ('write cities',                   'anon', 'no'),  ('write cities',                   'user', 'no'),  ('write cities',                   'admin', 'yes'),
  ('write sources',                  'anon', 'no'),  ('write sources',                  'user', 'no'),  ('write sources',                  'admin', 'yes'),
  ('truncate reviews',               'anon', 'no'),  ('truncate reviews',               'user', 'no'),  ('truncate reviews',               'admin', 'no'),
  ('read fountain_overview_view',    'anon', 'yes'), ('read fountain_overview_view',    'user', 'yes'), ('read fountain_overview_view',    'admin', 'yes');

create temp table rls_results (test text, who text, actual text, detail text);
grant all on rls_settings, rls_expected, rls_results to anon, authenticated;


-- ---------------------------------------------------------------------
-- HELPER CODE: don't normally need editing
-- ---------------------------------------------------------------------
-- For each visitor and test: switch to that visitor, run the SQL, count
-- the rows it touched, then deliberately raise an error so everything
-- (role switch and any write) is rolled back. "yes" = it touched at
-- least one row without an error.
do $$
declare
  v_who      text;
  v_test     text;
  v_sql      text;
  v_rows     bigint;
  v_admin    uuid := (select admin_id from rls_settings);
  v_user     uuid := (select user_id_nonadmin from rls_settings);
  v_fountain uuid := (select id from public.fountains order by id limit 1);
  v_review   uuid := (select id from public.reviews where status = 'approved' order by id limit 1);
  v_city     uuid := (select id from public.cities order by id limit 1);
  v_source   uuid := (select id from public.sources order by id limit 1);
  v_actual   text;
  v_detail   text;
  tests      text[][] := array[
    ['read approved reviews',        'select count(*) from public.reviews where status = ''approved'''],
    ['read pending reviews',         'select count(*) from public.reviews where status = ''pending'''],
    ['read reviewer emails',         'select count(reviewer_email) + count(*) from public.reviews'],
    ['insert pending public review', format('with x as (insert into public.reviews (fountain_id, author_type, status, rating, review_text) values (%L, ''public'', ''pending'', 5, ''rls test'') returning 1) select count(*) from x', v_fountain)],
    ['insert approved review',       format('with x as (insert into public.reviews (fountain_id, author_type, status, rating, review_text) values (%L, ''admin'', ''approved'', 5, ''rls test'') returning 1) select count(*) from x', v_fountain)],
    ['update reviews',               format('with x as (update public.reviews set review_text = review_text where id = %L returning 1) select count(*) from x', v_review)],
    ['delete reviews',               format('with x as (delete from public.reviews where id = %L returning 1) select count(*) from x', v_review)],
    ['read admins table',            'select count(*) from public.admins'],
    ['write fountains',              format('with x as (update public.fountains set name = name where id = %L returning 1) select count(*) from x', v_fountain)],
    ['write cities',                 format('with x as (update public.cities set name = name where id = %L returning 1) select count(*) from x', v_city)],
    ['write sources',                format('with x as (update public.sources set name = name where id = %L returning 1) select count(*) from x', v_source)],
    ['truncate reviews',             'truncate public.reviews'],
    ['read fountain_overview_view',  'select count(*) from public.fountain_overview_view']
  ];
  i int;
begin
  foreach v_who in array array['anon', 'user', 'admin'] loop
    for i in 1 .. array_length(tests, 1) loop
      v_test := tests[i][1];
      v_sql  := tests[i][2];
      begin
        -- become the visitor (only for the duration of this sub-block)
        if v_who = 'anon' then
          perform set_config('request.jwt.claims', '{"role":"anon"}', true);
          execute 'set local role anon';
        else
          perform set_config('request.jwt.claims',
            json_build_object('sub', case when v_who = 'admin' then v_admin else v_user end,
                              'role', 'authenticated')::text, true);
          execute 'set local role authenticated';
        end if;

        if v_sql like 'truncate%' then
          execute v_sql;          -- truncate returns no row count
          v_rows := 1;
        else
          execute v_sql into v_rows;
        end if;
        -- undo everything from this test, but remember the row count
        raise exception 'rls_test_done:%', coalesce(v_rows, 0);
      exception when others then
        if sqlerrm like 'rls_test_done:%' then
          v_rows   := split_part(sqlerrm, ':', 2)::bigint;
          v_actual := case when v_rows > 0 then 'yes' else 'no' end;
          v_detail := v_rows || ' row(s)';
        else
          v_actual := 'no';
          v_detail := left(sqlerrm, 80);
        end if;
      end;
      insert into rls_results values (v_test, v_who, v_actual, v_detail);
    end loop;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- RESULTS
-- ---------------------------------------------------------------------
select e.test,
       e.who,
       e.expected,
       r.actual,
       case when e.expected = r.actual then 'PASS' else 'FAIL' end as result,
       r.detail
from rls_expected e
join rls_results r using (test, who)
order by e.test, array_position(array['anon', 'user', 'admin'], e.who);

select count(*) filter (where e.expected = r.actual)  as passed,
       count(*) filter (where e.expected <> r.actual) as failed
from rls_expected e
join rls_results r using (test, who);

rollback;
