-- =====================================================================
-- 2026-10-06  Review ↔ fountain link fixes (from the Instagram audit)
-- =====================================================================
-- How to run: Supabase dashboard → SQL editor → paste this file → Run.
-- Everything is inside one transaction: if any step fails, nothing changes.
--
-- Section A = fixes from the audit (data/audits/2026-10-06_...).
-- Section B = Katherine's decisions of 2026-10-20 (B1/B2 pins to confirm).
-- Rollback:   supabase/rollbacks/rollback_2026-10-06_review_link_fixes.sql
-- Needs:      supabase/pending/add_is_indoor.sql applied first (is_indoor column).
--
-- Reviews are found by their Instagram link so you can check each one
-- by pasting the link into a browser.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- A1. "Empire fields, south side by the basketball courts and parking lot"
--     was linked to David Lam Park (Downtown!). City record DFPB0068 is
--     "Hastings Park / Empire Fields — East of basketball courts".
-- ---------------------------------------------------------------------
update public.reviews
set fountain_id = (select id from public.fountains where external_id = 'DFPB0068')
where instagram_url = 'https://www.instagram.com/p/DJuVLSLvfzk/';


-- ---------------------------------------------------------------------
-- A2. The City's open data uses the ID DFPB0066 TWICE: once for Sunset
--     Beach and once for "field house at empire field". Our import kept
--     only Sunset Beach, so the Empire Fields field-house fountain never
--     made it onto the map. Add it back (coordinates converted from the
--     City's own UTM values), then move the "by the bathrooms" review
--     to it — the video shows a fountain on the field-house wall under
--     the 1954 Miracle Mile plaque.
-- ---------------------------------------------------------------------
insert into public.fountains
  (external_id, city_id, source_id, name, neighbourhood, location_description,
   latitude, longitude, operational_status, season_note)
select
  'DFPB0066-EF',
  (select id from public.cities  where name = 'Vancouver'),
  (select id from public.sources where name = 'Vancouver Open Data'),
  'Hastings Park / Empire Fields - Field house',
  'Hastings-Sunrise',
  'Field house at Empire Field (City data lists this under duplicate ID DFPB0066)',
  49.282669, -123.034248,
  'seasonal', 'spring to fall'
where not exists (select 1 from public.fountains where external_id = 'DFPB0066-EF');

update public.reviews
set fountain_id = (select id from public.fountains where external_id = 'DFPB0066-EF')
where instagram_url = 'https://www.instagram.com/p/DJw7orQvz5i/';


-- ---------------------------------------------------------------------
-- A3. The Hinge Park review has the Charleson Park post's link. Clear it
--     so the map stops showing the wrong video. (Paste the right link in
--     section B4 when you have it.)
-- ---------------------------------------------------------------------
update public.reviews
set instagram_url = null
where id = '29174da1-b3b0-4bb8-b910-1d9287e04b8f';   -- "False creek seawall near hinge park"


-- ---------------------------------------------------------------------
-- A4. "False Creek Community Centre!" (indoors) was linked to Douglas Park
--     community centre, ~2 km away. The indoor fountain isn't in the City's
--     data, so add it. Location copied from the City's fountain on the
--     south side of the same building (DFPB0168, Sutcliffe Park) —
--     nudge the pin if you want it exact.
--     (Fun fact for the comments: the City's data says the outdoor one
--      you couldn't find is on the south side of the building.)
-- ---------------------------------------------------------------------
insert into public.fountains
  (name, neighbourhood, location_description, latitude, longitude, operational_status, is_indoor)
select
  'False Creek Community Centre (indoor)', 'Fairview',
  'Inside the community centre, Granville Island — open during centre hours',
  latitude, longitude, 'operational', true
from public.fountains
where external_id = 'DFPB0168'
  and not exists (select 1 from public.fountains where name = 'False Creek Community Centre (indoor)');

update public.reviews
set fountain_id = (select id from public.fountains where name = 'False Creek Community Centre (indoor)')
where id = '521b37c8-e683-41de-a1e8-e5101c21695c';   -- "False Creek Community Centre!"


-- ---------------------------------------------------------------------
-- A5. City labels. All 151 Burnaby fountains are labelled city "Vancouver"
--     and source "Vancouver Open Data"; the airport is labelled Kerrisdale.
-- ---------------------------------------------------------------------
insert into public.cities (name, slug) values
  ('Burnaby', 'burnaby'),
  ('Richmond', 'richmond')
on conflict (name) do nothing;

insert into public.sources (name, url) values
  ('Burnaby Open Data', 'https://data.burnaby.ca'),
  ('@yvrwaterfountains field observation', 'https://www.instagram.com/yvrwaterfountains/')
on conflict (name) do nothing;

-- Burnaby's IDs are all digits (their asset numbers)
update public.fountains
set city_id   = (select id from public.cities  where name = 'Burnaby'),
    source_id = (select id from public.sources where name = 'Burnaby Open Data')
where external_id ~ '^[0-9]+$';

-- fountains we added ourselves (no City ID)
update public.fountains
set source_id = (select id from public.sources where name = '@yvrwaterfountains field observation')
where external_id is null and source_id is null;

update public.fountains
set city_id = (select id from public.cities where name = 'Richmond'),
    neighbourhood = 'Sea Island (YVR)'
where name = 'YVR Airport - Domestic Terminal (C51)';

-- Vancouver for any of ours still missing a city
update public.fountains
set city_id = (select id from public.cities where name = 'Vancouver')
where city_id is null;


-- =====================================================================
-- B. Katherine's decisions (2026-10-20)
-- =====================================================================

-- B1. "BTS waterfountain ... #theorpheumtheatre" (backstage, not public)
--     was linked to the street fountain at 4th & Arbutus. Decision: its own
--     fountain, shown on the map, clearly labelled as not public.
--     PIN: 601 Smithe St (Orpheum), confirmed 2026-10-20.
insert into public.fountains
  (name, neighbourhood, location_description, latitude, longitude, operational_status, is_indoor,
   city_id, source_id)
select
  'Orpheum Theatre (backstage, not public)', 'Downtown',
  'NOT PUBLIC: backstage at the Orpheum, staff and performers only',
  49.27985, -123.12045,                                    -- pin confirmed 2026-10-20
  'unknown', true,
  (select id from public.cities  where name = 'Vancouver'),
  (select id from public.sources where name = '@yvrwaterfountains field observation')
where not exists (select 1 from public.fountains where name = 'Orpheum Theatre (backstage, not public)');

update public.reviews
set fountain_id = (select id from public.fountains where name = 'Orpheum Theatre (backstage, not public)')
where instagram_url = 'https://www.instagram.com/p/DKDx_pOxWc0/';


-- B2. "Kensington Park! ... inside the community centre" was linked to the
--     OUTDOOR fountain (DFPB0077). Decision: a separate indoor fountain,
--     pin on the community centre building (5175 Dumfries St).
--     PIN: confirmed 2026-10-20.
insert into public.fountains
  (name, neighbourhood, location_description, latitude, longitude, operational_status, is_indoor,
   city_id, source_id)
select
  'Kensington Community Centre (indoor)', 'Kensington-Cedar Cottage',
  'INDOOR: inside Kensington Community Centre, 5175 Dumfries St; open during centre hours',
  49.23780, -123.07450,                                    -- pin confirmed 2026-10-20
  'operational', true,
  (select id from public.cities  where name = 'Vancouver'),
  (select id from public.sources where name = '@yvrwaterfountains field observation')
where not exists (select 1 from public.fountains where name = 'Kensington Community Centre (indoor)');

update public.reviews
set fountain_id = (select id from public.fountains where name = 'Kensington Community Centre (indoor)')
where instagram_url = 'https://www.instagram.com/p/DRNjgBGE73O/';


-- B3. "Empire Fields, between the fields": NOT merged with City DFPB0070.
--     The City gives DFPB0070 the exact same coordinates as DFPB0068 (a
--     placeholder), so "72 m apart" proves nothing either way, and the
--     park has many fountains. Keep our own record and say so on it.
update public.fountains
set location_description = 'Our own pin (between the fields). May be the same fountain as City record DFPB0070, whose City coordinates are a placeholder; unconfirmed.'
where name = 'Empire Fields - Between two fields'
  and external_id is null;


-- B4. Correct Instagram links for the Hinge Park and False Creek CC
--     reviews: NOT set here. Katherine copies them from Instagram and they
--     are added in supabase/data_fixes/2026-10-25_backlog_import.sql.
--     Until then the map shows no Instagram link for them (A3 cleared the
--     wrong one).


-- B5. "6-7/10 ... It's a 7 right now, last summer it was 6".
--     Decision: rating 7 (this visit). The caption, which is kept, still
--     says last summer was a 6.
update public.reviews
set rating = 7.0
where id = 'b3f99574-9c11-4f53-8d65-1b7395c562c7'
  and rating = 6.5;


-- (The "-10/10" review stays at 0, the bottom of the 0-10 scale. Once the
--  Part 2 schema adds rating_raw, the popup can show "-10/10" exactly as
--  written while analyses use 0.)


-- ---------------------------------------------------------------------
-- Check: every admin review and the fountain it now points to
-- ---------------------------------------------------------------------
select r.visit_date, f.external_id, f.name, left(coalesce(r.instagram_caption, r.review_text), 60) as caption
from public.reviews r
join public.fountains f on f.id = r.fountain_id
where r.author_type = 'admin'
order by r.visit_date;

commit;
