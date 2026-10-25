# SQL queries

Analysis and quality-control queries for the YVR Water Fountains database
(Supabase / PostgreSQL + PostGIS). Paste any file into the Supabase SQL editor,
or run from R:

```r
library(DBI)
con <- dbConnect(RPostgres::Postgres(), host = "db.<project-ref>.supabase.co",
                 dbname = "postgres", user = "postgres", password = Sys.getenv("SUPABASE_DB_PASSWORD"))
dbGetQuery(con, paste(readLines("queries/01_coverage_by_neighbourhood.sql"), collapse = "\n"))
```

| File | Question |
|---|---|
| `01_coverage_by_neighbourhood.sql` | What share of each neighbourhood's fountains have we reviewed? |
| `02_parks_vs_engineering.sql` | Do Park Board and street (Engineering) fountains differ? |
| `03_qc_review_links.sql` | Are reviews linked to the right fountain / post / rating? |
| `04_possible_duplicate_fountains.sql` | Are any fountains recorded twice? |

Spatial functions (from `supabase/pending/postgis_nearest_fountains.sql`):

```sql
select * from nearest_fountains(49.2734, -123.1038, 5);   -- 5 closest to Science World
select * from fountains_within(49.2797, -123.1157, 300);  -- within 300 m of the Central Library
```
