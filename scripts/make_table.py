#!/usr/bin/env python
"""
Render docs/table.html from docs/data/fountains_processed.geojson
Run:  python scripts/make_table.py
"""

import json, pandas as pd, pathlib, textwrap

gj_path = pathlib.Path("docs/data/fountains_processed.geojson")
out_path = pathlib.Path("docs/table.html")

gj = json.load(gj_path.open())
df = pd.json_normalize([f["properties"] for f in gj["features"]])

html_table = (
    df[["name", "address", "geo_local_area"]]
      .sort_values("geo_local_area")
      .to_html(classes="table table-striped", index=False, border=0)
)

out_path.write_text(textwrap.dedent(f"""\
    <!doctype html><html><head><meta charset='utf-8'>
    <title>Fountain Table</title>
    <link rel="stylesheet"
      href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css">
    <link rel="stylesheet"
      href="https://cdn.jsdelivr.net/npm/datatables@1.13.8/media/css/jquery.dataTables.min.css">
    <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/datatables@1.13.8/media/js/jquery.dataTables.min.js"></script>
    </head><body class='p-3'>
    <a href='index.html'>&larr; Map view</a><h2>All Vancouver Fountains</h2>
    {html_table}
    <script>$(function(){{ $('table').DataTable(); }});</script>
    </body></html>
"""))

print("✔ wrote", out_path)
