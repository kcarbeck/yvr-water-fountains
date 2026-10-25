-- =====================================================================
-- 2026-10-25  Backlog import: 17 Instagram posts from 30 Mar to 25 Oct 2026
-- =====================================================================
-- Source: the official Instagram data export of 2026-10-25 (captions and
-- post times copied exactly). Every fountain match and every pin was
-- confirmed by Katherine in the to-do doc and on the "Backlog pin check"
-- page. Two posts are skipped: the Montreal review (not in Vancouver) and
-- a story that is not a review.
--
-- Needs, in this order:
--   1. supabase/pending/add_is_indoor.sql
--   2. supabase/data_fixes/2026-10-06_review_link_fixes.sql (adds the
--      "@yvrwaterfountains field observation" source used below)
-- Rollback: supabase/rollbacks/rollback_2026-10-25_backlog_import.sql
--
-- Safe to run twice: fountains are added only if their name is new, and
-- a review is added only if no review has the same Instagram link.
-- The whole file is one transaction: if any check fails, nothing changes.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. The 17 posts. Fill in `link` (the post's Instagram link) for every
--    row before running; step 2 refuses to run while any is missing.
--    fountain = a City ID (DFPB/DFENG...) or the name of a new fountain
--    added in step 3. media_id is Instagram's ID from the export, kept
--    here only so each row can be traced back to the export.
-- ---------------------------------------------------------------------
create temporary table backlog (
  row_no    int primary key,     -- row number in the to-do doc's backlog table
  posted_at timestamptz not null,
  media_id  text not null,
  rating    numeric(4,1) not null check (rating between 0 and 10),
  fountain  text not null,
  link      text,
  caption   text not null
) on commit drop;

insert into backlog (row_no, posted_at, media_id, rating, fountain, link, caption) values
  ( 1, '2026-03-31T05:49:31+00:00', '17972685626862367',    8, 'Costco Downtown (indoor)', null,
       'Costco downtown! 8/10, solid 👌
#yvrwaterfountains #costcosecrets'),
  ( 2, '2026-05-31T19:40:42+00:00', '17970838935060761',   10, 'UBC AMS Student Nest (indoor)', null,
       'UBC stuedent nest building. 10/10
#yvrwaterfountains #ubcstudentnest'),
  ( 3, '2026-06-01T18:11:59+00:00', '17865582570652234',    8, 'Orpheum Theatre lobby (indoor)', null,
       'Orpheum lobby fancy waterfountain, 8/10
It''s average when it comes to stream, temp, and taste, but look at how fancy it is!!!
Prettiest waterfountain so far.
#yvrwaterfountains #orpheumtheatre @vsorchestra'),
  ( 4, '2026-06-08T22:10:30+00:00', '18102657869278506',  8.5, 'Vancouver Aquatic Centre (indoor)', null,
       'Vancouver Aquatic Centre
This is a good one! A personal fav. 8.5/10. It''d have a higher rating if it wasn''t in a bathroom, which I know feels a bit icky. At least there''s separation from the stalls.

#yvrwaterfountains #vancouveraquaticcentre #dohashtagsevenworkanymore'),
  ( 5, '2026-06-29T23:36:52+00:00', '18089826710565932',    1, 'DFENG0034', null,
       'Hastings and Kamloops, 1/10. This has potential to be at least 7 if they can fix the water pressure! @vanparkboard 
I give the little seating area 10/10. Very nice.
@firehydrants.yvr there''s a pretty one here!

#yvrwaterfountains #eastvillageyvr'),
  ( 6, '2026-08-11T22:59:24+00:00', '18106305788172836',    7, 'DFPB0120', null,
       'Pandora Park 7/10

#yvrwaterfountains #eastvancouver #pandorapark'),
  ( 8, '2026-08-16T20:35:45+00:00', '18025283603886285',  7.5, 'DFPB0032', null,
       'David Lam park, near the courts. 7.5/10. It would have scored higher if it wasn''t clogged

#yvrwaterfountains #davidlampark'),
  (10, '2026-08-24T00:38:16+00:00', '18106070228138628',  9.5, 'DFPB0063', null,
       'Hastings Community Park, 9.5/10. The mosaic did a lot for this one! The stream was less than average, but the enjoyment level from the aesthetics bumped this up to 9.5'),
  (11, '2026-08-25T20:44:42+00:00', '18119422645713358',  7.5, 'DFPB0187', null,
       'Van Tech 7.5/10, above average, location not super convenient, but great for students or folks who use the fields'),
  (12, '2026-09-01T03:19:50+00:00', '17905871013492823',    6, 'DFPB0177', null,
       'Victoria Park - 6/10

Very cool looking fountain but not very functional unfortunately!'),
  (13, '2026-09-06T21:56:27+00:00', '18069189269721613',  7.5, 'VPL Hastings Branch (indoor)', null,
       '@vancouverpubliclibrary Hastings branch waterfountain - 7.5/10

Pretty good!'),
  (14, '2026-09-10T21:21:23+00:00', '18206147542321560',    7, 'Rice Lake, Lower Seymour Conservation Reserve', null,
       'Watershed, Rice lake, North Van
7/10'),
  (15, '2026-09-11T19:56:37+00:00', '18015647420739914',    8, 'Grouse Grind trailhead', null,
       'Grouse Grind Trail feat. Lauren
8/10, pretty great!'),
  (16, '2026-09-17T22:33:56+00:00', '18095761499556488',  7.5, 'Pandora Park - near the courts', null,
       'Pandora Park waterfountain #2! 7.5/10. Nice!
#yvrfoodblogger #eastvandogs #pandorapark'),
  (17, '2026-10-04T17:26:24+00:00', '17933388570146856',    9, 'Jade Rock, False Creek seawall', null,
       'Secret Jade Rock Waterfountain, false creek
9/10. Could have been perfect with a better stream and slightly crisper taste'),
  (18, '2026-10-11T07:46:10+00:00', '17891138526616273',  2.5, 'Queen Elizabeth Theatre (backstage, not public)', null,
       'Backstage Queen Elizabeth Theatre 
2.5/10
It''s something, but it''s not much. It''s there for survival purposes only I think'),
  (19, '2026-10-25T20:11:46+00:00', '18197646952396395',  8.5, 'Lower Seymour demonstration forest gazebo', null,
       'Lower Seymour Conservation Reserve, demo forest road gazebo. 8.5/10!
#yvrwaterfountains #northvan #demoforest')
;

-- ---------------------------------------------------------------------
-- 2. Checks before anything changes
-- ---------------------------------------------------------------------
do $$
begin
  if exists (select 1 from backlog where link is null or link !~ '^https://www\.instagram\.com/(p|reel)/[A-Za-z0-9_-]+/$') then
    raise exception 'Every row needs an Instagram link like https://www.instagram.com/reel/ABC123/ (missing or malformed: rows %)',
      (select string_agg(row_no::text, ', ' order by row_no) from backlog
       where link is null or link !~ '^https://www\.instagram\.com/(p|reel)/[A-Za-z0-9_-]+/$');
  end if;
  if (select count(distinct link) from backlog) <> (select count(*) from backlog) then
    raise exception 'The same Instagram link is used on two rows';
  end if;
  if not exists (select 1 from public.sources where name = '@yvrwaterfountains field observation') then
    raise exception 'Run supabase/data_fixes/2026-10-06_review_link_fixes.sql first';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 3. New places and fountains
-- ---------------------------------------------------------------------
insert into public.cities (name, slug) values
  ('North Vancouver (District)', 'north-vancouver-district')
on conflict (name) do nothing;

-- columns: name, neighbourhood, description, lat, lon, indoor, status, status note, city
create temporary table new_fountains on commit drop as
select * from (values
  ('Costco Downtown (indoor)', 'Downtown',
   'INDOOR: inside Costco, 605 Expo Blvd; members only, store hours',
   49.2787, -123.1094, true, 'unknown', null, 'Vancouver'),
  ('UBC AMS Student Nest (indoor)', 'UBC',
   'INDOOR: inside the AMS Student Nest, 6133 University Blvd',
   49.2666, -123.2499, true, 'unknown', null, 'Vancouver'),
  ('Orpheum Theatre lobby (indoor)', 'Downtown',
   'INDOOR: Orpheum lobby, 601 Smithe St; open to ticket holders during events',
   49.27995, -123.1201, true, 'unknown', null, 'Vancouver'),
  ('Vancouver Aquatic Centre (indoor)', 'West End',
   'INDOOR: in a washroom at the Vancouver Aquatic Centre, 1050 Beach Ave',
   49.2769, -123.1351, true, 'closed', 'Closed permanently on 28 June 2026; building being demolished', 'Vancouver'),
  ('VPL Hastings Branch (indoor)', 'Hastings-Sunrise',
   'INDOOR: Vancouver Public Library, Hastings Branch, 2674 E Hastings St; library hours',
   49.280891, -123.050135, true, 'unknown', null, 'Vancouver'),
  ('Rice Lake, Lower Seymour Conservation Reserve', 'Lower Seymour Conservation Reserve',
   'Near Rice Lake, Lower Seymour Conservation Reserve',
   49.35044391277449, -123.01461154232803, false, 'unknown', null, 'North Vancouver (District)'),
  ('Grouse Grind trailhead', 'Grouse Mountain',
   'At the bottom of the Grouse Grind trail',
   49.37138180574521, -123.09854399999996, false, 'unknown', null, 'North Vancouver (District)'),
  ('Pandora Park - near the courts', 'Grandview-Woodland',
   'Second Pandora Park fountain, near the courts (not in City data)',
   49.28257823289365, -123.0578580169218, false, 'unknown', null, 'Vancouver'),
  ('Jade Rock, False Creek seawall', 'Fairview',
   'Next to the jade rock on the False Creek seawall; a separate fountain from the City''s Charleson Park fountain (DFPB0017) about 7 m away',
   49.2681040110693, -123.125984, false, 'unknown', null, 'Vancouver'),
  ('Queen Elizabeth Theatre (backstage, not public)', 'Downtown',
   'NOT PUBLIC: backstage at the Queen Elizabeth Theatre, staff and performers only',
   49.28043157010823, -123.11255893675666, true, 'unknown', null, 'Vancouver'),
  ('Lower Seymour demonstration forest gazebo', 'Lower Seymour Conservation Reserve',
   'At the gazebo on the demonstration forest road, Lower Seymour Conservation Reserve',
   49.350862700996196, -123.01628282040537, false, 'unknown', null, 'North Vancouver (District)')
) as t(name, neighbourhood, description, lat, lon, indoor, status, status_note, city);

insert into public.fountains
  (name, neighbourhood, location_description, latitude, longitude, is_indoor,
   operational_status, season_note, city_id, source_id)
select n.name, n.neighbourhood, n.description, n.lat, n.lon, n.indoor,
       n.status, n.status_note,
       (select id from public.cities  where name = n.city),
       (select id from public.sources where name = '@yvrwaterfountains field observation')
from new_fountains n
where not exists (select 1 from public.fountains f where f.name = n.name);

-- every row must now point at exactly one fountain
do $$
begin
  if exists (
    select 1 from backlog b
    where (select count(*) from public.fountains f
           where f.external_id = b.fountain or (f.external_id is null and f.name = b.fountain)) <> 1
  ) then
    raise exception 'A backlog row does not match exactly one fountain';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 4. The reviews: same shape as the existing 42 (admin, approved,
--    caption as the review text). visit_date is the post's local date.
-- ---------------------------------------------------------------------
insert into public.reviews
  (fountain_id, author_type, status, rating, review_text, instagram_url,
   instagram_caption, visit_date, reviewed_at)
select
  (select f.id from public.fountains f
   where f.external_id = b.fountain or (f.external_id is null and f.name = b.fountain)),
  'admin', 'approved', b.rating, b.caption, b.link,
  b.caption, (b.posted_at at time zone 'America/Vancouver')::date, b.posted_at
from backlog b
where not exists (select 1 from public.reviews r where r.instagram_url = b.link);

-- ---------------------------------------------------------------------
-- Check: the 17 reviews and where they point
-- ---------------------------------------------------------------------
select b.row_no, r.visit_date, r.rating, coalesce(f.external_id, 'new') as id, f.name, f.is_indoor, f.operational_status
from backlog b
join public.reviews r on r.instagram_url = b.link
join public.fountains f on f.id = r.fountain_id
order by b.row_no;

commit;
