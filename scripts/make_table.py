#!/usr/bin/env python
"""
Build docs/table.html with a responsive Bootstrap/DataTables view.
"""
import json, pandas as pd, pathlib, textwrap, os
import re
from bs4 import BeautifulSoup

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

# Order columns (add 'id' for linking, but don't display it)
ordered_cols = [
    "id",  # keep for linking, not for display
    "name", "geo_local_area", "address", "Rating", "IG Photo", "IG Post",
    "pet_friendly", "wheelchair_accessible", "bottle_filler", "last_service_date",
    "visited", "visit_date", "caption"
]
ordered_cols = [c for c in ordered_cols if c in df.columns]
df = df[ordered_cols]

# Rename columns for display (do not rename 'id')
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

# Prepare table for display (exclude 'id' from shown columns)
display_cols = [c for c in df.columns if c != 'id']
df_display = df[display_cols]

# Use pandas Styler to add table attributes
styled_table = df_display.style.set_table_attributes('id="fountains-table" class="table table-striped table-hover nowrap"') \
    .set_td_classes(pd.DataFrame('', index=df_display.index, columns=df_display.columns)) \
    .hide(axis='index')
html_table = styled_table.to_html()

# Use BeautifulSoup to inject data-id into <tr> in <tbody>
soup = BeautifulSoup(html_table, 'html.parser')
for tr, row_id in zip(soup.select('tbody tr'), df['id']):
    tr['data-id'] = row_id
html_table = str(soup)

# Use a unique table id for robust JS targeting
TABLE_ID = "fountains-table"

DST.write_text(
    textwrap.dedent(
        f"""
    <!doctype html>
    <html lang='en'>
    <head>
      <meta charset='utf-8'>
      <title>Vancouver Water Fountains – Table</title>
      <meta name="viewport" content="width=device-width,initial-scale=1">
      <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css">
      <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/datatables.net-bs5@1.13.8/css/dataTables.bootstrap5.min.css">
      <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/datatables.net-responsive-bs5@2.5.0/css/responsive.bootstrap5.min.css">
      <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/datatables.net-buttons-bs5@2.4.2/css/buttons.bootstrap5.min.css">
      <style>
        body{{padding:1rem;}}
        table.dataTable {{width:100% !important;}}
        th, td {{vertical-align: middle;}}
        thead th {{position: sticky; top: 0; background: #fff; z-index: 2;}}
        td.feature-yes {{background:#e6ffe6; color:#155724;}}
        td.feature-no {{background:#ffe6e6; color:#721c24;}}
        td.feature-unknown {{background:#f2f2f2; color:#888;}}
        tr.clickable-row:hover {{background:#d9edf7 !important;cursor:pointer;}}
      </style>
    </head>
    <body>
      <a href='index.html' class='btn btn-link'>&larr; Map</a>
      <h2 class='mb-3'>All Vancouver Fountains</h2>
      <noscript><div class='alert alert-warning'>JavaScript is required for table interactivity.</div></noscript>
      <div class="table-responsive">{html_table}</div>
      <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
      <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
      <script src="https://cdn.jsdelivr.net/npm/datatables.net@1.13.8/js/jquery.dataTables.min.js"></script>
      <script src="https://cdn.jsdelivr.net/npm/datatables.net-bs5@1.13.8/js/dataTables.bootstrap5.min.js"></script>
      <script src="https://cdn.jsdelivr.net/npm/datatables.net-responsive@2.5.0/js/dataTables.responsive.min.js"></script>
      <script src="https://cdn.jsdelivr.net/npm/datatables.net-responsive-bs5@2.5.0/js/responsive.bootstrap5.min.js"></script>
      <script src="https://cdn.jsdelivr.net/npm/datatables.net-buttons@2.4.2/js/dataTables.buttons.min.js"></script>
      <script src="https://cdn.jsdelivr.net/npm/datatables.net-buttons-bs5@2.4.2/js/buttons.bootstrap5.min.js"></script>
      <script src="https://cdn.jsdelivr.net/npm/datatables.net-buttons@2.4.2/js/buttons.colVis.min.js"></script>
      <script>
        $(function(){{
          var table = $('#{TABLE_ID}').DataTable({{
            responsive: true,
            pageLength: 25,
            order: [],
            dom: 'Bfrtip',
            buttons: [
              'colvis'
            ],
            initComplete: function() {{
              // Add dropdown filters to each column
              this.api().columns().every(function() {{
                var column = this;
                var colIdx = column.index();
                var header = $(column.header());
                var title = header.text();
                if (["Neighbourhood","Pet OK","Wheelchair","Bottle","Visited"].includes(title)) {{
                  var select = $('<select><option value="">All</option></select>')
                    .appendTo(header.empty().attr('title', 'Filter by ' + title))
                    .on('change', function() {{
                      var val = $.fn.dataTable.util.escapeRegex($(this).val());
                      column.search(val ? '^'+val+'$' : '', true, false).draw();
                    }});
                  column.data().unique().sort().each(function(d) {{
                    if (d && d !== '—') select.append('<option value="'+d+'">'+d+'</option>');
                  }});
                }} else {{
                  header.attr('title', title);
                }}
              }});
            }}
          }});
          // Color coding for features
          table.rows().every(function() {{
            var row = this.node();
            $(row).addClass('clickable-row');
            $(row).find('td').each(function(i) {{
              var col = table.column(i).header().textContent;
              var val = $(this).text().trim().toLowerCase();
              if(["pet ok","wheelchair","bottle"].includes(col.toLowerCase())) {{
                if(val === 'yes') $(this).addClass('feature-yes');
                else if(val === 'no') $(this).addClass('feature-no');
                else $(this).addClass('feature-unknown');
              }}
            }});
          }});
          // Tooltips for headers
          $('#{TABLE_ID} th').each(function(){{
            var title = $(this).attr('title');
            if(title) $(this).tooltip({{container:'body', placement:'top'}});
          }});
          // Clickable rows
          $('#{TABLE_ID} tbody').on('click', 'tr.clickable-row', function() {{
            var name = $(this).find('td:first').text();
            alert('Fountain: ' + name);
          }});
        }});
      </script>
    </body>
    </html>
"""
    )
)

print("✔ wrote", DST)
