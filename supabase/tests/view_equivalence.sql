-- =====================================================================
-- What the public map sees: fountain_overview_view, read as `anon`
-- (a visitor who is not logged in). Run before and after a change; the
-- numbers must match, apart from changes the fix is meant to make.
-- Safe on production (read-only, ends in ROLLBACK).
-- =====================================================================
begin;
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';

select count(*)                                   as n_rows,
       count(average_rating)                      as n_rated,
       sum(average_rating)                        as sum_average_rating,
       sum(approved_review_count)                 as n_approved_reviews_shown,
       count(distinct latest_review_instagram_url) as n_distinct_ig_urls,
       md5(string_agg(distinct latest_review_instagram_url collate "C", '|'
                      order by latest_review_instagram_url collate "C")) as ig_url_set_md5
from public.fountain_overview_view;

rollback;
