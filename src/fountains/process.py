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
        
        # Clean up name
        if "name" in props and props["name"]:
            name_val = props["name"].split(":", 1)[-1].strip() if ":" in props["name"] else props["name"]
            props["name"] = name_val.replace("\n", " ").strip()
        
        # Use 'location' as address
        props["address"] = props.get("location", None)
        props["longitude"] = lon
        props["latitude"] = lat
        
        # Set missing info to 'Unknown'
        for col in ["pet_friendly", "wheelchair_accessible", "bottle_filler", "in_operation"]:
            props[col] = props.get(col, "Unknown")
        
        records.append(props)
    
    df = pd.DataFrame(records)

    # Rename & subset useful columns
    df.rename(columns={"mapid": "id"}, inplace=True)

    # Define all columns to keep
    all_columns = [
        "id", "name", "address", "geo_local_area", "latitude", "longitude",
        "pet_friendly", "wheelchair_accessible", "bottle_filler", "in_operation", 
        "last_service_date", "rating", "ig_post_url", "flow", "temp", 
        "drainage", "caption", "visited", "visit_date", "photo_url"
    ]

    # Ensure all columns exist in DataFrame, fill missing with 'Unknown' or blank
    for col in all_columns:
        if col not in df.columns:
            df[col] = "" if col in ["rating", "ig_post_url", "flow", "temp", "drainage", "caption", "visited", "visit_date", "photo_url"] else "Unknown"

    # Merge with ratings.csv if it exists
    ratings_path = Path("data/ratings.csv")
    if ratings_path.exists():
        # Read CSV, explicitly naming columns since there's no header
        # Ensure the names match the order in your ratings.csv
        ratings = pd.read_csv(ratings_path, names=all_columns[1:], header=None)
        # Ensure the 'id' column exists in both DataFrames before merging
        if 'id' in df.columns and 'id' in ratings.columns:
            # Perform the merge. Columns from 'df' (left) keep their name,
            # columns from 'ratings' (right) get a '_y' suffix if names conflict.
            df = df.merge(ratings, how="left", on="id", suffixes=('', '_y')) # Use suffixes to keep original names for left df
            click.echo(f"✓ merged with ratings.csv ({len(ratings)} IG posts)")

            # Drop original columns that were replaced by merged data (if any)
            # Identify columns from original df that were duplicated in ratings csv
            original_dupe_cols = [col for col in ratings.columns if col in all_columns and col != 'id']
            # Construct the list of original columns with the '_x' suffix (which is empty string due to suffixes=('', '_y'))
            cols_to_drop_original = [col for col in original_dupe_cols]
            # Drop the original columns where the merged data (_y) is preferred
            df.drop(columns=cols_to_drop_original, errors='ignore', inplace=True)

            # Rename merged columns (_y suffix) to their intended names
            cols_to_rename = {f'{col}_y': col for col in ratings.columns if f'{col}_y' in df.columns}
            df.rename(columns=cols_to_rename, inplace=True)

            # Fill NaN values introduced by the merge in the newly renamed columns
            # Replace NaN in string/object columns with empty string
            string_cols = [col for col in ratings.columns if col in df.columns and col != 'id']
            df[string_cols] = df[string_cols].fillna("")

            # Replace NaN in numeric columns (like rating, flow, temp, drainage if they are numbers) with None or 0
            # You might need to adjust these based on the actual data types and desired representation
            numeric_cols_to_fill_none = ['rating', 'flow', 'temp', 'drainage'] # Add other numeric columns from ratings if applicable
            for col in numeric_cols_to_fill_none:
                 if col in df.columns:
                      # Use None for null in JSON, which is standard. Or use 0 if preferred.
                      df[col] = df[col].fillna(None) # or df[col] = df[col].fillna(0) if you prefer 0

        else:
            # Added a more specific warning
            missing_col_df = 'id' not in df.columns
            missing_col_ratings = 'id' not in ratings.columns
            missing_msg = f"⚠️  'id' column not found in {'fountain DataFrame' if missing_col_df else ''}{' and ' if missing_col_df and missing_col_ratings else ''}{'ratings DataFrame' if missing_col_ratings else ''}. Merge skipped."
            click.echo(missing_msg)
    else:
        click.echo("⚠️  data/ratings.csv not found. Skipping IG merge.")

    # Handle NaN values for existing columns
    for col in ["latitude", "longitude"]:
        if col in df.columns:
            df[col] = df[col].fillna(0)  # Use 0 or another appropriate value

    print("DataFrame columns:", df.columns)

    # Build GeoJSON features
    features = [
        geojson.Feature(
            geometry=geojson.Point((row.longitude, row.latitude)),
            properties=row.drop(["latitude", "longitude"]).to_dict(),
        )
        for _, row in df.iterrows()
        if pd.notnull(row.longitude) and pd.notnull(row.latitude)  # Ensure valid coordinates
    ]

    # Save GeoJSON
    Path(outfile).parent.mkdir(parents=True, exist_ok=True)
    Path(outfile).write_text(geojson.dumps(geojson.FeatureCollection(features), indent=2))

    # Copy into docs/data
    dest = Path("docs/data") / Path(outfile).name
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(outfile, dest)

    click.echo(f"✓ saved {len(df):,} cleaned records → {outfile} and copied to {dest}")

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