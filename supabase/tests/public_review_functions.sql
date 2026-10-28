-- =====================================================================
-- submit_public_review() and submit_report(): does each check refuse
-- what it should, with the message the page expects?
-- Runs every call as anon (a visitor who is not logged in) and prints
-- PASS/FAIL per case.
--
-- Safe to run on production: the form is switched on and every call is
-- made inside this transaction, and the file ends in ROLLBACK.
-- =====================================================================

begin;

-- the form must be open for everything except the "closed" case
update public.settings set value = 'true' where key = 'public_reviews_open';

create temp table fn_cases (n int, test text, call text, expected text);
grant all on fn_cases to anon;

-- %1$s = a fountain id, filled in below. expected = 'ok' or the error message.
insert into fn_cases values
  ( 1, 'valid review',               'submit_public_review(%1$L, 7.5, ''Cold and strong'', ''Sam'', current_date - 1)', 'ok'),
  ( 2, 'valid review, only rating',  'submit_public_review(%1$L, 0)',                                         'ok'),
  ( 3, 'rating above 10',            'submit_public_review(%1$L, 10.5)',                                      'bad_rating'),
  ( 4, 'rating below 0',             'submit_public_review(%1$L, -1)',                                        'bad_rating'),
  ( 5, 'rating not a half point',    'submit_public_review(%1$L, 7.3)',                                       'bad_rating'),
  ( 6, 'no rating',                  'submit_public_review(%1$L, null)',                                      'bad_rating'),
  ( 7, 'unknown fountain',           'submit_public_review(gen_random_uuid(), 5)',                            'fountain_not_found'),
  ( 8, 'text over 500 characters',   'submit_public_review(%1$L, 5, repeat(''a'', 501))',                     'text_too_long'),
  ( 9, 'link in text (http)',        'submit_public_review(%1$L, 5, ''see HTTPS://spam.example'')',           'link_in_text'),
  (10, 'link in text (www.)',        'submit_public_review(%1$L, 5, ''see www.spam.example'')',               'link_in_text'),
  (11, 'name over 40 characters',    'submit_public_review(%1$L, 5, null, repeat(''n'', 41))',                'name_too_long'),
  (12, 'visit date in the future',   'submit_public_review(%1$L, 5, null, null, current_date + 1)',           'bad_visit_date'),
  (13, 'visit date before 2020',     'submit_public_review(%1$L, 5, null, null, date ''2019-12-31'')',        'bad_visit_date'),
  (14, 'honeypot filled',            'submit_public_review(%1$L, 5, null, null, null, ''x'')',                'rejected'),
  (15, '4th review, same fountain',  'submit_public_review(%1$L, 5)',                                         'too_many_for_fountain'),
  (16, 'valid report',               'submit_report(%1$L, ''not_working'', ''No water'')',                    'ok'),
  (17, 'missing fountain with pin',  'submit_report(null, ''missing_fountain'', null, 49.28, -123.12)',       'ok'),
  (18, 'missing fountain, no pin',   'submit_report(null, ''missing_fountain'')',                             'pin_needed'),
  (19, 'report, unknown kind',       'submit_report(%1$L, ''broken'')',                                       'bad_kind'),
  (20, 'report, no fountain',        'submit_report(null, ''not_working'')',                                  'fountain_not_found'),
  (21, 'report, honeypot filled',    'submit_report(%1$L, ''other'', null, null, null, null, ''x'')',         'rejected'),
  (22, 'HTML in review text',        'submit_public_review(%1$L, 5, ''<img src=x>'')',                        'bad_characters'),
  (23, 'HTML in reviewer name',      'submit_public_review(%1$L, 5, null, ''<b>Sam</b>'')',                   'bad_characters'),
  (24, 'report, unknown fountain',   'submit_report(gen_random_uuid(), ''other'')',                           'fountain_not_found'),
  (25, 'report, pin outside area',   'submit_report(null, ''missing_fountain'', null, 45.5, -73.6)',          'bad_pin'),
  (26, 'report, half a pin',         'submit_report(null, ''other'', null, 49.28, null)',                     'bad_pin'),
  (27, 'report text over 500',       'submit_report(%1$L, ''other'', repeat(''a'', 501))',                    'text_too_long'),
  (28, 'report, HTML in details',    'submit_report(%1$L, ''other'', ''<script>'')',                          'bad_characters'),
  (29, 'form closed',                'submit_public_review(%1$L, 5)',                                         'reviews_closed');


-- ---------------------------------------------------------------------
-- HELPER CODE: don't normally need editing
-- ---------------------------------------------------------------------
-- Calls are kept (not undone) so that case 15 sees the two valid
-- reviews from cases 1-2 plus one more, and hits the cap of 3.
-- The last check sends a review while signed in and looks at the row
-- written: it must be a pending public review with no created_by.
create temp table fn_results (n int, actual text);
grant all on fn_results to anon;

do $$
declare
  v_fountain uuid := (select f.id from public.fountains f
                      where not exists (select 1 from public.reviews r where r.fountain_id = f.id)
                      order by f.id limit 1);
  -- a second fountain for the last check (the first has hit its cap)
  v_other    uuid := (select f.id from public.fountains f
                      where not exists (select 1 from public.reviews r where r.fountain_id = f.id)
                      order by f.id offset 1 limit 1);
  c record;
  v_actual text;
begin
  for c in select * from fn_cases order by n loop
    if c.test = 'form closed' then
      update public.settings set value = 'false' where key = 'public_reviews_open';
    end if;
    -- case 15 needs a third review first (cases 1-2 were the first two)
    if c.n = 15 then
      perform public.submit_public_review(v_fountain, 5);
    end if;
    begin
      perform set_config('request.jwt.claims', '{"role":"anon"}', true);
      set local role anon;
      execute 'select public.' || format(c.call, v_fountain);
      v_actual := 'ok';
      reset role;
    exception when others then
      reset role;
      v_actual := sqlerrm;
    end;
    insert into fn_results values (c.n, v_actual);
  end loop;

  update public.settings set value = 'true' where key = 'public_reviews_open';
  perform set_config('request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-00000000c0c0","role":"authenticated"}', true);
  set local role authenticated;
  perform public.submit_public_review(v_other, 6, 'row check', null, null, null);
  reset role;
  insert into fn_results
  select 30, case when author_type = 'public' and status = 'pending' and created_by is null
                  then 'ok' else 'wrong row' end
  from public.reviews where review_text = 'row check';

  -- the three details land on the review row, and only there
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  set local role anon;
  perform public.submit_public_review(v_other, 6, 'details check', null, null, null, true, false, null);
  reset role;
  insert into fn_results
  select 31, case when r.has_bottle_filler is true and r.is_wheelchair_accessible is false and r.anti_freeze is null
                   and f.has_bottle_filler is null and f.is_wheelchair_accessible is null and f.anti_freeze is null
                  then 'ok' else 'wrong row' end
  from public.reviews r join public.fountains f on f.id = r.fountain_id
  where r.review_text = 'details check';
end $$;

insert into fn_cases values (30, 'signed-in sender: row is pending, public, no created_by', null, 'ok');
insert into fn_cases values (31, 'details stored on the review, fountain untouched', null, 'ok');

-- ---------------------------------------------------------------------
-- RESULTS
-- ---------------------------------------------------------------------
select c.n, c.test, c.expected, r.actual,
       case when c.expected = r.actual then 'PASS' else 'FAIL' end as result
from fn_cases c join fn_results r using (n)
order by c.n;

select count(*) filter (where c.expected = r.actual)  as passed,
       count(*) filter (where c.expected <> r.actual) as failed
from fn_cases c join fn_results r using (n);

rollback;
