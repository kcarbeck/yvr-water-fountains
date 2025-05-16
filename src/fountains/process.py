# author: katherine carbeck
# 16 may 2025
# clean geojson exported from vancouver open data export to GeoJSON feature collection that folium/ leaflet can load

import geojson
import shutil, os
import pandas as pd
import click
from pathlib import Path

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
        props = feature["properties"]
        lon, lat = feature["geometry"]["coordinates"]
        props["longitude"] = lon
        props["latitude"] = lat
        records.append(props)
    df = pd.DataFrame(records)

    # Rename & subset useful columns
    df = df.rename(
        columns={
            "mapid": "id",
            "name": "name",
            "location": "address",
            "geo_local_area": "geo_local_area",
        }
    )

    # Define all columns to keep (add new ones as needed)
    all_columns = [
        "id", "name", "address", "geo_local_area", "latitude", "longitude",
        "location", "pet_friendly", "wheelchair_accessible", "bottle_filler", "last_service_date"
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

if __name__ == "__main__":  # pragma: no cover
    main()