# YVR Water Fountains

Two of us drink from public drinking fountains around Vancouver, review them on Instagram at [@yvrwaterfountains](https://www.instagram.com/yvrwaterfountains/), and put the reviews on a [map](https://yvr-water-fountains.netlify.app/map). Optimised for a phone screen and an empty water bottle.

As of 2026-10-21 the database holds 436 fountains and 43 reviews. 42 fountains have a published review. The 43rd review came in through the public form and is still waiting for us.

## How a review works

Each visit gets one overall rating out of 10. Reviews used to have five sub-ratings as well (water quality, flow, temperature, cleanliness, accessibility). None of them were ever filled in, so [we dropped them](supabase/migrations/20260302_drop_sub_ratings.sql).

A second visit to the same fountain is meant to be a new review with its own visit date, not an edit of the first one, so we can see whether a fountain gets better or worse over time. The database allows this. No fountain has been reviewed twice yet.

The map currently shows each fountain's mean rating and number of reviews. We have decided to switch to showing the latest rating on the map, with the mean and every visit date in the fountain's info. That change is not built yet.

Ratings are stored between 0 and 10. One caption gives a fountain -10/10. The database records this as 0, and the caption keeps the original opinion.

## The data, and what is wrong with it

Fountain locations come from two open data files kept in this repo: [City of Vancouver](data/raw/vancouver_fountains_raw.csv) (278 rows) and [City of Burnaby](data/raw/burnaby_fountains_raw.csv) (151 rows). We added 8 more that are in neither file, including one on the 8th floor of the Central Library and one at gate C51 of the YVR domestic terminal. Each city row keeps its original ID in `external_id`, so it can be traced back to the source file.

Things we found along the way:

- The City of Vancouver uses the ID `DFPB0066` for two different fountains: one at Sunset Beach and one on the field house at Empire Field, about 7.5 km apart. Our import requires unique IDs, so it kept Sunset Beach and silently dropped the other one. We noticed because we had reviewed the one it dropped.
- Six Stanley Park fountains, including the ones at the Lawn Bowling Club, the Brockton Cricket Pavilion and the Brockton Point viewpoint, share a single coordinate near the north end of the park. Two Empire Fields fountains (`DFPB0068` and `DFPB0070`) also share one point. The Burnaby file has five stacks of its own.
- All 151 Burnaby fountains are labelled city "Vancouver" and source "Vancouver Open Data" in our database. That one is our mistake, not the cities'. The airport fountain, which is in Richmond, is filed under Kerrisdale.
- The 8 fountains we added have no source recorded yet, and nothing in the database marks which ones are indoors or not open to the public.

Fixes for the duplicate ID, the city and source labels, and the indoor and not-public labels are written and tested on a copy of the database, but not applied (see In progress). The stacked fountains stay where the City put them until one of us walks over and drops a real pin.

## How changes are made

For the October 2026 changes we took a full backup of the live database, rebuilt it as a local copy, and checked that the copy matched production table by table. Each change was run on the copy first, along with its rollback, and we compared row counts and what the public map can see before and after. Schema changes are numbered files in [`supabase/migrations/`](supabase/migrations/). One-off corrections to the data are kept as separate scripts, each with a rollback (on the `oct-fixes` branch for now).

The security fix and the form pause reached the live database on 2026-10-21. Afterwards the public map view still returned 436 fountains, 42 of them rated, the same as before.

## Who can see and change what

Anyone can read fountains and published reviews. Only accounts listed in the `admins` table can add, edit or delete anything, and the admin pages sign in through Supabase Auth. This is enforced inside Postgres with row-level security, so the browser only ever holds the public key.

The rules have not always worked. In the [original schema](supabase/migrations/20241015120000_core_schema.sql), the function that checks if a user is an admin reads the `admins` table, and the `admins` table's own rule calls that same function. Postgres followed this loop until it ran out of stack, so anonymous reads of reviews failed. The fix, applied on 2026-10-21, makes the function run with its owner's permissions, so reading `admins` no longer sets off the rule again.

The public review form is switched off at the database for now. The button on the map is still there.

## How it is built

- The map is Leaflet and plain JavaScript in `docs/` (most of it in [`docs/js/map.js`](docs/js/map.js)). Netlify serves it, and GitHub Pages serves a second copy from the same folder.
- The data lives in Supabase Postgres. The map reads one view, `fountain_overview_view`, using the public key. If that fails it falls back to a GeoJSON file bundled in `docs/data/`.
- [`etl/import-fountains.js`](etl/import-fountains.js) loads a city CSV into the database, matching rows on `external_id` so re-running it updates fountains instead of duplicating them.

## In progress

This section is under construction, in the 1999 sense. None of it is on `main` yet.

- On the `oct-fixes` branch: the security and form-pause migrations already applied above; a PostGIS migration adding `nearest_fountains()` (not applied); the data fixes for the problems listed earlier, including three reviews linked to the wrong fountain, the missing Empire Field fountain and the Burnaby labels (not applied); four SQL queries for coverage by neighbourhood, Park Board versus street fountains, review-link checks and possible duplicates; an R script that snapshots the database to CSV; and the tests and rollbacks for all of it.
- The Instagram importer is decided but not written. It will use the official Instagram API. Each post is imported once, tracked by its Instagram media ID. A post goes on the map by itself only if its caption has exactly one fountain code and one clean rating. Anything else waits in a queue for us to confirm.

## Running it locally

```bash
cd docs
python3 -m http.server 8000
```

Then open <http://localhost:8000/map.html>. It reads the live database with the public key. The admin pages need an admin account.

MIT licence, see [LICENSE](LICENSE).

Guestbook: the comments on Instagram.
