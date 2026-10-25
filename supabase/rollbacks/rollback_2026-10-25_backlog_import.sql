-- =====================================================================
-- ROLLBACK for supabase/data_fixes/2026-10-25_backlog_import.sql
-- Removes the 17 imported reviews (found by their exact post times), then
-- the 11 fountains and the city the import added, if nothing else uses
-- them. Leaves every other review and fountain untouched.
-- =====================================================================
begin;

delete from public.reviews
where author_type = 'admin'
  and reviewed_at in (
  '2026-03-31T05:49:31+00:00',
  '2026-05-31T19:40:42+00:00',
  '2026-06-01T18:11:59+00:00',
  '2026-06-08T22:10:30+00:00',
  '2026-06-29T23:36:52+00:00',
  '2026-08-11T22:59:24+00:00',
  '2026-08-16T20:35:45+00:00',
  '2026-08-24T00:38:16+00:00',
  '2026-08-25T20:44:42+00:00',
  '2026-09-01T03:19:50+00:00',
  '2026-09-06T21:56:27+00:00',
  '2026-09-10T21:21:23+00:00',
  '2026-09-11T19:56:37+00:00',
  '2026-09-17T22:33:56+00:00',
  '2026-10-04T17:26:24+00:00',
  '2026-10-11T07:46:10+00:00',
  '2026-10-25T20:11:46+00:00');

delete from public.fountains f
where f.name in (
  'Costco Downtown (indoor)',
  'UBC AMS Student Nest (indoor)',
  'Orpheum Theatre lobby (indoor)',
  'Vancouver Aquatic Centre (indoor)',
  'VPL Hastings Branch (indoor)',
  'Rice Lake, Lower Seymour Conservation Reserve',
  'Grouse Grind trailhead',
  'Pandora Park - near the courts',
  'Jade Rock, False Creek seawall',
  'Queen Elizabeth Theatre (backstage, not public)',
  'Lower Seymour demonstration forest gazebo')
  and not exists (select 1 from public.reviews r where r.fountain_id = f.id);

delete from public.cities c
where c.name = 'North Vancouver (District)'
  and not exists (select 1 from public.fountains f where f.city_id = c.id);

-- check: all three should be 0
select (select count(*) from public.reviews where author_type = 'admin' and reviewed_at > '2026-03-01') as imported_reviews_left,
       (select count(*) from public.fountains where name in (
  'Costco Downtown (indoor)',
  'UBC AMS Student Nest (indoor)',
  'Orpheum Theatre lobby (indoor)',
  'Vancouver Aquatic Centre (indoor)',
  'VPL Hastings Branch (indoor)',
  'Rice Lake, Lower Seymour Conservation Reserve',
  'Grouse Grind trailhead',
  'Pandora Park - near the courts',
  'Jade Rock, False Creek seawall',
  'Queen Elizabeth Theatre (backstage, not public)',
  'Lower Seymour demonstration forest gazebo')) as imported_fountains_left,
       (select count(*) from public.cities where name = 'North Vancouver (District)') as city_left;

commit;
