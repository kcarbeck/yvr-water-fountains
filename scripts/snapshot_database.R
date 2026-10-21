# =====================================================================
# snapshot_database.R
# ---------------------------------------------------------------------
# Downloads the public fountain + review data from Supabase and saves:
#   data/snapshot/fountains.csv           one row per fountain (+ ratings)
#   data/snapshot/reviews.csv             every approved review
#   data/snapshot/snapshot_info.json      when + how many
#   docs/data/fountains_processed.geojson backup copy the map uses if
#                                         Supabase is ever unreachable
#
# It runs twice a day on GitHub (.github/workflows/nightly-snapshot.yml).
# Those requests also count as "activity", which stops Supabase's free
# plan from pausing the project.
#
# To run it yourself in RStudio:
#   1. open the project folder (yvr-water-fountains) as the working dir
#   2. Sys.setenv(SUPABASE_URL = "https://hnyktzfyquvmpthfwpvd.supabase.co",
#                 SUPABASE_ANON_KEY = "<the public anon key from docs/config.js>")
#   3. source("scripts/snapshot_database.R")
#
# Only uses the public "anon" key, so it only ever sees what the public
# website sees (approved reviews, no emails).
# Needs one package: install.packages("jsonlite")
# =====================================================================

library(jsonlite)


# ---------------------------------------------------------------------
# SETTINGS — the parts you might edit
# ---------------------------------------------------------------------
supabase_url <- Sys.getenv("SUPABASE_URL")
anon_key     <- Sys.getenv("SUPABASE_ANON_KEY")

snapshot_dir <- "data/snapshot"
geojson_path <- "docs/data/fountains_processed.geojson"

# review columns to export (reviewer_email is deliberately left out)
review_columns <- c("id", "fountain_id", "author_type", "status", "rating",
                    "review_text", "reviewer_name", "instagram_url",
                    "instagram_caption", "visit_date", "created_at")


# ---------------------------------------------------------------------
# HELPER FUNCTIONS — don't normally need editing
# ---------------------------------------------------------------------

# Download one table/view from the Supabase REST API as a data frame
download_table <- function(path) {
  url <- paste0(supabase_url, "/rest/v1/", path)
  tmp <- tempfile(fileext = ".json")
  download.file(url, tmp, quiet = TRUE, method = "libcurl",
                headers = c(apikey = anon_key,
                            Authorization = paste("Bearer", anon_key)))
  fromJSON(tmp)
}

# Turn NA into NULL so it is written as JSON null
na_to_null <- function(x) if (length(x) == 0 || is.na(x)) NULL else x

# Build the map properties for one fountain row
# (mirrors buildProperties() in docs/js/fountain-data.js)
map_properties <- function(row) {
  status <- row$operational_status
  season <- row$season_note
  operational_label <- if (status == "operational") "operational"
    else if (status == "seasonal" && !is.na(season)) paste0("seasonal (", season, ")")
    else if (status == "seasonal") "seasonal"
    else if (status == "closed") "closed"
    else if (!is.na(season)) season
    else "unknown"

  pet <- if (row$pet_friendly == "yes") "Yes" else if (row$pet_friendly == "no") "No" else "unknown"
  yes_no <- function(x) if (is.na(x)) NULL else if (x) "Yes" else "No"

  latest_rating <- if (is.na(row$latest_review_rating)) NULL
                   else sprintf("%.1f", row$latest_review_rating)

  reviewer <- if (!is.na(row$latest_review_author_type) && row$latest_review_author_type == "admin") "@yvrwaterfountains"
              else if (!is.na(row$latest_review_reviewer_name)) row$latest_review_reviewer_name
              else "community reviewer"

  instagram_posts <- list()
  if (!is.na(row$latest_review_instagram_url)) {
    instagram_posts <- list(list(
      url        = row$latest_review_instagram_url,
      date_posted = na_to_null(row$latest_reviewed_at),
      rating     = latest_rating,
      caption    = na_to_null(if (!is.na(row$latest_review_instagram_caption)) row$latest_review_instagram_caption else row$latest_review_text),
      photo_url  = na_to_null(row$latest_review_instagram_image_url)
    ))
  }

  list(
    id                    = if (!is.na(row$external_id)) row$external_id else row$id,
    supabase_id           = row$id,
    name                  = row$name,
    neighborhood          = na_to_null(row$neighbourhood),
    location              = na_to_null(row$location_description),
    address               = na_to_null(row$location_description),
    city_name             = na_to_null(row$city_name),
    source_name           = na_to_null(row$source_name),
    currently_operational = operational_label,
    operational_status    = status,
    season_note           = na_to_null(season),
    pet_friendly          = pet,
    pet_status            = row$pet_friendly,
    avg_rating            = na_to_null(row$average_rating),
    rating_count          = row$approved_review_count,
    admin_review_count    = row$admin_review_count,
    rating                = latest_rating,
    latest_reviewer       = reviewer,
    latest_review_author_type = na_to_null(row$latest_review_author_type),
    latest_review_text    = na_to_null(row$latest_review_text),
    latest_review_instagram_caption = na_to_null(row$latest_review_instagram_caption),
    latest_reviewed_at    = na_to_null(row$latest_reviewed_at),
    caption               = na_to_null(if (!is.na(row$latest_review_text)) row$latest_review_text else row$latest_review_instagram_caption),
    has_instagram         = length(instagram_posts) > 0,
    instagram_posts       = instagram_posts,
    wheelchair_accessible = yes_no(row$is_wheelchair_accessible),
    bottle_filler         = yes_no(row$has_bottle_filler),
    last_verified_at      = na_to_null(row$last_verified_at)
  )
}


# ---------------------------------------------------------------------
# 1. Download from Supabase
# ---------------------------------------------------------------------
if (supabase_url == "" || anon_key == "") {
  stop("Set SUPABASE_URL and SUPABASE_ANON_KEY first (see top of this script).")
}

overview <- download_table(
  "fountain_overview_view?select=*&order=name.asc"
)
reviews <- download_table(
  paste0("reviews?select=", paste(review_columns, collapse = ","),
         "&status=eq.approved&order=visit_date.asc")
)

# Sanity check: never overwrite a good snapshot with an empty one.
# (If the project is paused, the download fails above and the job
#  goes red on GitHub — which emails you. That's the alarm.)
if (nrow(overview) < 100) {
  stop("Only ", nrow(overview), " fountains came back — something is wrong, not saving.")
}

cat("Downloaded", nrow(overview), "fountains and", nrow(reviews), "approved reviews\n")


# ---------------------------------------------------------------------
# 2. Save the CSVs (the tidy, analysis-ready copy)
# ---------------------------------------------------------------------
dir.create(snapshot_dir, recursive = TRUE, showWarnings = FALSE)

fountain_columns <- c("id", "external_id", "name", "neighbourhood",
                      "location_description", "city_name", "source_name",
                      "latitude", "longitude", "operational_status",
                      "season_note", "pet_friendly", "has_bottle_filler",
                      "is_wheelchair_accessible", "last_verified_at",
                      "average_rating", "approved_review_count",
                      "admin_review_count")
fountains_out <- overview[, fountain_columns]

# sort so the files only change when the data changes
fountains_out <- fountains_out[order(fountains_out$id), ]
reviews_out   <- reviews[order(reviews$id), ]

write.csv(fountains_out, file.path(snapshot_dir, "fountains.csv"), row.names = FALSE, na = "")
write.csv(reviews_out,   file.path(snapshot_dir, "reviews.csv"),   row.names = FALSE, na = "")


# ---------------------------------------------------------------------
# 3. Save the backup GeoJSON for the map
#    (same property names the map builds in docs/js/fountain-data.js)
# ---------------------------------------------------------------------
features <- vector("list", nrow(overview))
for (i in seq_len(nrow(overview))) {
  features[[i]] <- list(
    type = "Feature",
    geometry = list(type = "Point",
                    coordinates = c(overview$longitude[i], overview$latitude[i])),
    properties = map_properties(overview[i, ])
  )
}
geojson <- list(type = "FeatureCollection", features = features)
write_json(geojson, geojson_path, auto_unbox = TRUE, null = "null",
           na = "null", digits = NA, pretty = FALSE)


# ---------------------------------------------------------------------
# 4. Save a small summary file + print it
# ---------------------------------------------------------------------
# "checked_week" changes once a week, so GitHub sees at least one commit
# a week (it switches off scheduled jobs in repos with no activity for
# 60 days). Otherwise files only change when the data changes.
info <- list(
  checked_week          = format(Sys.Date(), "%G-W%V"),
  fountains             = nrow(overview),
  reviewed_fountains    = sum(!is.na(overview$average_rating)),
  approved_reviews      = nrow(reviews),
  mean_rating           = round(mean(reviews$rating, na.rm = TRUE), 2),
  latest_review_visit   = max(reviews$visit_date, na.rm = TRUE)
)
write_json(info, file.path(snapshot_dir, "snapshot_info.json"),
           auto_unbox = TRUE, pretty = TRUE)

cat("\nSnapshot summary\n")
str(info)
cat("\nSaved to", snapshot_dir, "and", geojson_path, "\n")
