import json, pandas as pd, pathlib, textwrap

gj = json.load(open("docs/data/fountains_processed.geojson"))
df = pd.json_normalize([f["properties"] for f in gj["features"]])

html_table = (
    df[["name","address","geo_local_area"]]
      .sort_values("geo_local_area")
      .to_html(classes="table table-striped", index=False, border=0)
)

out = pathlib.Path("docs/table.html")
out.write_text(textwrap.dedent(f"""\
    <!doctype html><html><head><meta charset='utf-8'>
    <title>Fountain Table</title>
    <link rel="stylesheet"
     href="https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/5.3.3/css/bootstrap.min.css">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.7.1/jquery.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/datatables/1.13.8/js/jquery.dataTables.min.js"></script>
    </head><body class='p-3'>
    <a href='index.html'>&larr; Map</a><h2>All Vancouver Fountains</h2>
    {html_table}
    <script>$(function(){{ $('table').DataTable(); }});</script>
    </body></html>
    """))
print("wrote", out)