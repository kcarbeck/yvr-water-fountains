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
-- Direct inserts into reviews are admin-only; the public adds reviews
-- and reports only through submit_public_review() and submit_report().
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
  ('read fountain_overview_view',    'anon', 'yes'), ('read fountain_overview_view',    'user', 'yes'), ('read fountain_overview_view',    'admin', 'yes'),
  ('submit public review (form open)',      'anon', 'yes'), ('submit public review (form open)',      'user', 'yes'), ('submit public review (form open)',      'admin', 'yes'),
  ('submit public review (form closed)',    'anon', 'no'),  ('submit public review (form closed)',    'user', 'no'),  ('submit public review (form closed)',    'admin', 'no'),
  ('submit public review (honeypot filled)', 'anon', 'no'), ('submit public review (honeypot filled)', 'user', 'no'), ('submit public review (honeypot filled)', 'admin', 'no'),
  ('read created_by column',         'anon', 'no'),  ('read created_by column',         'user', 'yes'), ('read created_by column',         'admin', 'yes'),
  ('read settings',                  'anon', 'yes'), ('read settings',                  'user', 'yes'), ('read settings',                  'admin', 'yes'),
  ('write settings',                 'anon', 'no'),  ('write settings',                 'user', 'no'),  ('write settings',                 'admin', 'yes'),
  ('submit report',                  'anon', 'yes'), ('submit report',                  'user', 'yes'), ('submit report',                  'admin', 'yes'),
  ('read reports',                   'anon', 'no'),  ('read reports',                   'user', 'no'),  ('read reports',                   'admin', 'yes'),
  ('insert report directly',         'anon', 'no'),  ('insert report directly',         'user', 'no'),  ('insert report directly',         'admin', 'no'),
  ('update reports',                 'anon', 'no'),  ('update reports',                 'user', 'no'),  ('update reports',                 'admin', 'yes'),
  ('read public_average_rating',     'anon', 'yes'), ('read public_average_rating',     'user', 'yes'), ('read public_average_rating',     'admin', 'yes'),
  ('pending review changes the map', 'anon', 'no'),  ('pending review changes the map', 'user', 'no'),  ('pending review changes the map', 'admin', 'no'),
  ('read fountain_reviews_view',     'anon', 'yes'), ('read fountain_reviews_view',     'user', 'yes'), ('read fountain_reviews_view',     'admin', 'yes'),
  ('pending review in fountain_reviews_view', 'anon', 'no'), ('pending review in fountain_reviews_view', 'user', 'no'), ('pending review in fountain_reviews_view', 'admin', 'no'),
  ('read review detail columns',     'anon', 'yes'), ('read review detail columns',     'user', 'yes'), ('read review detail columns',     'admin', 'yes'),
  ('write fountain detail columns',  'anon', 'no'),  ('write fountain detail columns',  'user', 'no'),  ('write fountain detail columns',  'admin', 'yes'),
  ('submit public review with details', 'anon', 'yes'), ('submit public review with details', 'user', 'yes'), ('submit public review with details', 'admin', 'yes');

create temp table rls_results (test text, who text, actual text, detail text);
grant all on rls_settings, rls_expected, rls_results to anon, authenticated;

-- one report so the read/update report tests have a row to touch
insert into public.reports (kind, details) values ('other', 'rls test');
-- and one pending review, which the all-visits view must never show
insert into public.reviews (fountain_id, author_type, status, rating, review_text)
select id, 'public', 'pending', 5, 'rls test pending' from public.fountains order by id limit 1;


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
    ['read fountain_overview_view',  'select count(*) from public.fountain_overview_view'],
    ['submit public review (form open)',       format('select count(*) from (select public.submit_public_review(%L, 7.5, ''rls test'') as ok) x where ok', v_fountain)],
    ['submit public review (form closed)',     format('select count(*) from (select public.submit_public_review(%L, 7.5, ''rls test'') as ok) x where ok', v_fountain)],
    ['submit public review (honeypot filled)', format('select count(*) from (select public.submit_public_review(%L, 7.5, ''rls test'', null, null, ''spam'') as ok) x where ok', v_fountain)],
    ['read created_by column',       'select count(created_by) + count(*) from public.reviews'],
    ['read settings',                'select count(*) from public.settings'],
    ['write settings',               'with x as (update public.settings set value = value where key = ''public_reviews_open'' returning 1) select count(*) from x'],
    ['submit report',                format('select count(*) from (select public.submit_report(%L, ''not_working'', ''rls test'') as ok) x where ok', v_fountain)],
    ['read reports',                 'select count(*) from public.reports'],
    ['insert report directly',       format('with x as (insert into public.reports (fountain_id, kind) values (%L, ''other'') returning 1) select count(*) from x', v_fountain)],
    ['update reports',               'with x as (update public.reports set status = status returning 1) select count(*) from x'],
    ['read public_average_rating',   'select count(*) from (select public_average_rating from public.fountain_overview_view) x'],
    ['read fountain_reviews_view',    'select count(*) from public.fountain_reviews_view'],
    ['pending review in fountain_reviews_view', 'select count(*) from public.fountain_reviews_view where review_text = ''rls test pending'''],
    ['read review detail columns',    'select count(has_bottle_filler) + count(is_wheelchair_accessible) + count(anti_freeze) + count(*) from public.reviews'],
    ['write fountain detail columns', format('with x as (update public.fountains set anti_freeze = anti_freeze, status_reported_at = status_reported_at where id = %L returning 1) select count(*) from x', v_fountain)],
    ['submit public review with details', format('select count(*) from (select public.submit_public_review(%L, 7.5, ''rls test'', null, null, null, true, false, null) as ok) x where ok', v_fountain)]
  ];
  i int;
begin
  foreach v_who in array array['anon', 'user', 'admin'] loop
    for i in 1 .. array_length(tests, 1) loop
      v_test := tests[i][1];
      v_sql  := tests[i][2];
      begin
        -- the review-form tests set the switch first (undone with the test)
        if v_test like 'submit public review%' then
          update public.settings
          set value = case when v_test like '%(form closed)' then 'false' else 'true' end
          where key = 'public_reviews_open';
        end if;

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

-- A pending review must not change the map view or the all-visits view
-- for anyone, admins included (they can read pending reviews). For each
-- visitor: read both views, add pending reviews as the owner, read them
-- again, compare. "yes" = a view changed.
do $$
declare
  v_who     text;
  v_before  text;
  v_after   text;
  v_admin   uuid := (select admin_id from rls_settings);
  v_user    uuid := (select user_id_nonadmin from rls_settings);
  -- one fountain with approved reviews and one with none
  v_rated   uuid := (select fountain_id from public.reviews where status = 'approved' order by fountain_id limit 1);
  v_unrated uuid := (select f.id from public.fountains f
                     where not exists (select 1 from public.reviews r where r.fountain_id = f.id)
                     order by f.id limit 1);
  v_actual  text;
  v_detail  text;
begin
  foreach v_who in array array['anon', 'user', 'admin'] loop
    begin
      perform set_config('request.jwt.claims',
        case when v_who = 'anon' then '{"role":"anon"}'
             else json_build_object('sub', case when v_who = 'admin' then v_admin else v_user end,
                                    'role', 'authenticated')::text end, true);
      execute case when v_who = 'anon' then 'set local role anon' else 'set local role authenticated' end;
      select md5(json_agg(o order by o.id)::text)
             || (select md5(coalesce(json_agg(v order by v.id)::text, '')) from public.fountain_reviews_view v)
      into v_before from public.fountain_overview_view o;

      reset role;
      insert into public.reviews (fountain_id, author_type, status, rating, visit_date, reviewed_at, created_by)
      values (v_rated,   'public', 'pending', 0, current_date, now(), null),
             (v_rated,   'admin',  'pending', 0, current_date, now(), null),
             (v_unrated, 'public', 'pending', 0, current_date, now(), null);

      execute case when v_who = 'anon' then 'set local role anon' else 'set local role authenticated' end;
      select md5(json_agg(o order by o.id)::text)
             || (select md5(coalesce(json_agg(v order by v.id)::text, '')) from public.fountain_reviews_view v)
      into v_after from public.fountain_overview_view o;
      raise exception 'rls_test_done:%', case when v_before = v_after then 0 else 1 end;
    exception when others then
      if sqlerrm like 'rls_test_done:%' then
        v_actual := case when split_part(sqlerrm, ':', 2) = '1' then 'yes' else 'no' end;
        v_detail := case when v_actual = 'yes' then 'view changed' else 'view unchanged' end;
      else
        v_actual := 'error';
        v_detail := left(sqlerrm, 80);
      end if;
    end;
    insert into rls_results values ('pending review changes the map', v_who, v_actual, v_detail);
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
