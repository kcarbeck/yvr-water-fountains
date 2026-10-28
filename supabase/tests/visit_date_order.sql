-- =====================================================================
-- The latest review is the newest VISIT, not the newest approval, and an
-- open maintenance issue stays open until an admin clears it, even after
-- a later rated visit. Adds three reviews to one fountain, reads the
-- views, prints PASS/FAIL per check.
-- Safe on production: ends in ROLLBACK.
-- =====================================================================
begin;

create temp table vd_results (test text, result text);

do $$
declare
  -- a fountain with no reviews, so only the three below count
  v_fountain uuid := (select f.id from public.fountains f
                      where not exists (select 1 from public.reviews r where r.fountain_id = f.id)
                      order by f.id limit 1);
  v record;
begin
  -- two public visits: the older one approved today, the newer one
  -- approved on the day; then an admin visit newer than both
  insert into public.reviews (fountain_id, author_type, status, rating, review_text, visit_date, reviewed_at)
  values (v_fountain, 'public', 'approved', 3, 'older public visit, approved later', date '2025-06-01', now()),
         (v_fountain, 'public', 'approved', 5, 'newer public visit',                 date '2025-09-01', timestamptz '2025-09-01 12:00+00'),
         (v_fountain, 'admin',  'approved', 9, 'newest visit',                      date '2026-01-05', timestamptz '2026-01-05 12:00+00');

  select * into v from public.fountain_overview_view where id = v_fountain;
  insert into vd_results values
    ('latest rating is the newest visit',   case when v.latest_review_rating = 9 then 'PASS' else 'FAIL (' || coalesce(v.latest_review_rating::text, 'null') || ')' end),
    ('latest_visit_date is the newest visit', case when v.latest_visit_date = date '2026-01-05' then 'PASS' else 'FAIL (' || coalesce(v.latest_visit_date::text, 'null') || ')' end),
    ('latest public rating is the newest public visit, not the latest approval', case when v.latest_public_rating = 5 then 'PASS' else 'FAIL (' || coalesce(v.latest_public_rating::text, 'null') || ')' end),
    ('average and count unchanged by order', case when v.average_rating = 5.67 and v.approved_review_count = 3 then 'PASS' else 'FAIL' end),
    ('no issue when nothing is reported',   case when v.issue_reported_at is null and v.issue_note is null then 'PASS' else 'FAIL' end);

  insert into vd_results
  select 'all-visits view lists the newest visit first',
         case when (select rating from public.fountain_reviews_view where fountain_id = v_fountain
                    order by visit_date desc limit 1) = 9 then 'PASS' else 'FAIL' end;

  -- an issue applied before the newest visit stays open: only an admin clears it
  update public.fountains set issue_reported_at = date '2025-12-01', issue_note = 'no water' where id = v_fountain;
  insert into vd_results
  select 'issue stays open after a later rated visit',
         case when issue_reported_at = date '2025-12-01' and issue_note = 'no water' then 'PASS' else 'FAIL' end
  from public.fountain_overview_view where id = v_fountain;

  -- a seasonal or closed status is not an issue
  update public.fountains set issue_reported_at = null, issue_note = null, operational_status = 'seasonal' where id = v_fountain;
  insert into vd_results
  select 'seasonal status is not an issue',
         case when issue_reported_at is null then 'PASS' else 'FAIL' end
  from public.fountain_overview_view where id = v_fountain;

  -- a note needs a date
  begin
    update public.fountains set issue_note = 'leaking' where id = v_fountain;
    insert into vd_results values ('a note without a date is refused', 'FAIL');
  exception when check_violation then
    insert into vd_results values ('a note without a date is refused', 'PASS');
  end;
end $$;

select * from vd_results;
select count(*) filter (where result = 'PASS') as passed,
       count(*) filter (where result <> 'PASS') as failed
from vd_results;

rollback;
