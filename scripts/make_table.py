#!/usr/bin/env python
"""
Build docs/table.html with a responsive Bootstrap/DataTables view.
"""
import json, pandas as pd, pathlib, textwrap, os

SRC = pathlib.Path("docs/data/fountains_processed.geojson")
DST = pathlib.Path("docs/table.html")

# -------- load data --------
gj = json.load(SRC.open())
df = pd.json_normalize([f["properties"] for f in gj["features"]])

# Try to merge with ratings.csv if it exists
ratings_path = "data/ratings.csv"
if os.path.exists(ratings_path):
    ratings = pd.read_csv(ratings_path)
    df = df.merge(ratings, how="left", on="id")
    print(f"✓ merged with ratings.csv ({len(ratings)} IG posts)")
else:
    print("⚠️  data/ratings.csv not found. Skipping IG merge.")

# Add IG thumbnail and IG post link columns
if 'photo_url' in df.columns:
    df['IG Photo'] = df['photo_url'].apply(lambda url: f"<img src='{url}' width='60'>" if pd.notnull(url) else "")
else:
    df['IG Photo'] = ""
if 'ig_post_url' in df.columns:
    df['IG Post'] = df['ig_post_url'].apply(lambda url: f"<a href='{url}' target='_blank'>View Post</a>" if pd.notnull(url) else "")
else:
    df['IG Post'] = ""

# Format rating (scale of 10, show as stars and number)
def format_rating(val):
    try:
        v = float(val)
        stars = '★' * int(round(v/2))
        return f"{stars} {v:.1f}" if v else '—'
    except:
        return '—'
df['Rating'] = df['rating'].apply(format_rating) if 'rating' in df.columns else '—'

# Order columns
ordered_cols = [
    "name", "geo_local_area", "address", "Rating", "IG Photo", "IG Post",
    "pet_friendly", "wheelchair_accessible", "bottle_filler", "last_service_date",
    "visited", "visit_date", "caption"
]
# Only keep columns that exist
ordered_cols = [c for c in ordered_cols if c in df.columns]
df = df[ordered_cols]

# Rename columns for display
col_rename = {
    "name": "Name",
    "geo_local_area": "Neighbourhood",
    "address": "Address",
    "pet_friendly": "Pet OK",
    "wheelchair_accessible": "Wheelchair",
    "bottle_filler": "Bottle",
    "last_service_date": "Serviced",
    "visited": "Visited",
    "visit_date": "Visit Date",
    "caption": "Caption"
}
df = df.rename(columns=col_rename)

# Prettify booleans → icons
def iconize(val: str | bool, ok="✅", bad="❌"):
    return ok if str(val).strip().lower() in {"yes", "true", "1"} else bad
for col in ["Pet OK", "Wheelchair", "Bottle"]:
    if col in df.columns:
        df[col] = df[col].apply(iconize)

# -------- build html --------
BOOT = "https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
DAT_CSS = "https://cdn.jsdelivr.net/npm/datatables@1.13.8/media/css/jquery.dataTables.min.css"
DAT_JS  = "https://cdn.jsdelivr.net/npm/datatables@1.13.8/media/js/jquery.dataTables.min.js"
JQ      = "https://code.jquery.com/jquery-3.7.1.min.js"

html_table = df.to_html(
    classes="table table-striped table-hover nowrap",
    index=False,
    border=0,
    escape=False,            # keep emoji and HTML
)

DST.write_text(
    textwrap.dedent(
        f"""
    <!doctype html><html><head><meta charset='utf-8'>
    <title>Vancouver Water Fountains – Table</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <link rel="stylesheet" href="{BOOT}">
    <link rel="stylesheet" href="{DAT_CSS}">
    <style>
      body{{padding:1rem;}}
      table.dataTable {{width:100% !important;}}
      th, td {{vertical-align: middle;}}
      thead th {{position: sticky; top: 0; background: #fff; z-index: 2;}}
    </style>
    </head><body>
    <a href='index.html' class='btn btn-link'>&larr; Map</a>
    <h2 class='mb-3'>All Vancouver Fountains</h2>
    <div class="table-responsive">{html_table}</div>

    <script src="{JQ}"></script>
    <script src="{DAT_JS}"></script>
    <script>
      $(function(){{
        $('table').DataTable({{
          responsive: true,
          pageLength: 25,
          order: [[1,'asc']],     // sort by Neighbourhood
        }});
      }});
    </script>
    </body></html>
"""
    )
)

print("✔ wrote", DST)
