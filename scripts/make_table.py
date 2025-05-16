#!/usr/bin/env python
"""
Build docs/table.html with a responsive Bootstrap/DataTables view.
"""
import json, pandas as pd, pathlib, textwrap

SRC = pathlib.Path("docs/data/fountains_processed.geojson")
DST = pathlib.Path("docs/table.html")

# -------- load data --------
gj = json.load(SRC.open())
df = pd.json_normalize([f["properties"] for f in gj["features"]])

# pick & rename columns
df = (
    df[
        [
            "name",
            "geo_local_area",
            "location",
            "pet_friendly",
            "wheelchair_accessible",
            "bottle_filler",
            "last_service_date",
        ]
    ]
    .rename(
        columns={
            "name": "Name",
            "geo_local_area": "Neighbourhood",
            "location": "Address",
            "pet_friendly": "Pet OK",
            "wheelchair_accessible": "Wheelchair",
            "bottle_filler": "Bottle",
            "last_service_date": "Serviced",
        }
    )
)

# prettify booleans → icons
def iconize(val: str | bool, ok="✅", bad="❌"):
    return ok if str(val).strip().lower() in {"yes", "true", "1"} else bad

for col in ["Pet OK", "Wheelchair", "Bottle"]:
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
    escape=False,            # keep emoji
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
