# author: katherine carbeck
# 16 may 2025
# clean geojson exported from vancouver open data export to GeoJSON feature collection that folium/ leaflet can load

import geojson
import shutil, os
import pandas as pd
import click
from pathlib import Path
import folium

@click.command()
@click.option(
    "--infile",
    default="data/fountains_raw.geojson",
    show_default=True,
    help="Raw GeoJSON file downloaded",
)
@click.option(
    "--outfile",
    default="data/fountains_processed.geojson",
    show_default=True,
    help="Destination GeoJSON path",
)
def main(infile: str, outfile: str) -> None:
    """Transform raw → tidy → GeoJSON."""
    # Load GeoJSON
    with open(infile) as f:
        gj = geojson.load(f)
    
    # Extract features into DataFrame
    records = []
    for feature in gj["features"]:
        props = feature["properties"].copy()
        lon, lat = feature["geometry"]["coordinates"]
        # Clean up name: extract after colon and newline if present
        if "name" in props and props["name"]:
            name_val = props["name"]
            if ":" in name_val:
                name_val = name_val.split(":", 1)[-1].strip()
            name_val = name_val.replace("\n", " ").strip()
            props["name"] = name_val
        # Use 'location' as address
        props["address"] = props.get("location", None)
        props["longitude"] = lon
        props["latitude"] = lat
        records.append(props)
    df = pd.DataFrame(records)

    # Rename & subset useful columns
    df = df.rename(
        columns={
            "mapid": "id",
            "geo_local_area": "geo_local_area",
        }
    )

    # Define all columns to keep (add new ones as needed)
    all_columns = [
        "id", "name", "address", "geo_local_area", "latitude", "longitude",
        "pet_friendly", "wheelchair_accessible", "bottle_filler", "last_service_date"
    ]

    # Ensure all columns exist in DataFrame, fill missing with None
    for col in all_columns:
        if col not in df.columns:
            df[col] = None

    # Subset and order columns
    df = df[all_columns]

    # Build GeoJSON features
    features = [
        geojson.Feature(
            geometry=geojson.Point((row.longitude, row.latitude)),
            properties=row.drop(["latitude", "longitude"]).to_dict(),
        )
        for _, row in df.iterrows()
    ]

    Path(outfile).parent.mkdir(parents=True, exist_ok=True)
    Path(outfile).write_text(geojson.dumps(geojson.FeatureCollection(features), indent=2))

    # copy into docs/data so GitHub Pages can serve it
    dest = Path("docs/data") / Path(outfile).name
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(outfile, dest)

    click.echo(
        f"✓ saved {len(df):,} cleaned records → {outfile} "
        f"and copied to {dest}"
    )

    # Add popups to features
    for feature in features:
        lon, lat = feature["geometry"]["coordinates"]
        row = pd.Series(feature["properties"])
        popup = folium.Popup(f"""
<b>{row['name']}</b><br>
Neighbourhood: {row['geo_local_area']}<br>
Address: {row['address']}<br>
Pet Friendly: {row['pet_friendly']}<br>
Wheelchair Accessible: {row['wheelchair_accessible']}<br>
Bottle Filler: {row['bottle_filler']}<br>
Last Service: {row['last_service_date']}
""", max_width=300)
        folium.Marker(location=(lat, lon), popup=popup).add_to(folium.FeatureGroup(name="Fountains"))

if __name__ == "__main__":  # pragma: no cover
    main()