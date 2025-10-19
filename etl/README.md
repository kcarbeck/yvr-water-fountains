# Fountain Import Guide

This guide is for volunteers and coordinators who need to load new fountain data into Supabase. No programming experience is required.

## Before you begin
1. Install [Node.js 18 or newer](https://nodejs.org/).
2. Ask the project lead for the Supabase **URL** and **service role key**. Put them in a file named `.env` inside this repository:
   ```ini
   SUPABASE_URL=your-project-url
   SUPABASE_SERVICE_ROLE_KEY=your-secret-key
   ```
3. Place the CSV file you received from the city inside the `data/raw` folder (or note the absolute path).
4. Make sure you know which city the file represents and where the data came from (source name, website, and license text).

## Importing a new city
Run the import script from the project root. Replace the example values with your own:
```bash
node etl/import-fountains.js \
  --csv data/raw/vancouver_fountains_raw.csv \
  --city "Vancouver" \
  --source "City of Vancouver Open Data" \
  --url "https://opendata.vancouver.ca/explore/dataset/water-fountains" \
  --license "Open Government Licence - Vancouver"
```
What happens:
- the script connects to Supabase using your `.env` file
- it guesses which CSV columns match the fields we store (name, latitude, longitude, etc.) and prints the mapping it chose
- any new fountains are inserted, existing fountains are updated in place, and nothing is duplicated
- a summary table tells you how many rows were inserted, updated, or skipped (with reasons)

## Re-running the import safely
Need to tweak the CSV and run it again? Just repeat the same command. The script compares each row by `external_id` and `source_id`, so existing fountains are updated instead of duplicated. Skipped rows will be listed with an explanation (for example, missing coordinates).

## Common issues and fixes
| Problem | What it means | How to fix |
|---------|---------------|------------|
| `csv file not found` | The path after `--csv` is wrong. | Double-check the filename and folder. Use `pwd` and `ls` in the terminal to confirm. |
| `supabase credentials are missing` | `.env` is missing or the variables are blank. | Edit `.env` so it contains `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`, then run the command again. |
| `missing required fields: name, lat, lon, external_id` | The script could not find columns for those fields. | Open the CSV to confirm it has those columns. If they are named differently, edit the header row to something clearer and re-run. |
| `supabase error: column sources.license does not exist` | Your Supabase project has not been updated with the optional `license` column. | Ask the tech lead to add the column or re-run with the same command—the script will automatically retry without the license column after logging this warning. |
| Map markers appear in the wrong place after import | The CSV coordinates were not in latitude/longitude. | Convert the coordinates to WGS84 (latitude/longitude) before importing, or contact the data steward for help. |

If you hit a different error, copy the full message and share it with the engineering team so they can troubleshoot.
