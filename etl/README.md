# Fountain import

Loads a city's open-data CSV of drinking fountains into Supabase. Re-running is safe: rows are matched on `external_id` and `source_id`, so existing fountains are updated rather than duplicated.

## Setup

Node.js 18+, then `npm install` in the repo root. Put the credentials in `.env` (git-ignored):

```ini
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<service role key>
```

## Usage

```bash
node etl/import-fountains.js \
  --csv data/raw/vancouver_fountains_raw.csv \
  --city "Vancouver" \
  --source "City of Vancouver Open Data" \
  --url "https://opendata.vancouver.ca/explore/dataset/water-fountains" \
  --license "Open Government Licence - Vancouver"
```

The script prints the CSV column mapping it chose, then a summary of rows inserted, updated and skipped (with reasons).

## Common errors

| Message | Fix |
|---|---|
| `csv file not found` | Check the path passed to `--csv`. |
| `supabase credentials are missing` | Add both variables to `.env`. |
| `missing required options` | Pass all of `--csv`, `--city`, `--source`, `--url` and `--license`. |
| Rows skipped with `missing required fields` | Rename the CSV headers so these columns can be found. |
| `sources.license column is not available` | Warning only: the import runs, without saving the license. |
| Markers in the wrong place | Coordinates must be WGS84 latitude/longitude. |
