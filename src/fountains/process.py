import pandas as pd
import click
from pathlib import Path

@click.command()
@click.option("--infile", default="data/fountains_raw.csv")
@click.option("--outfile", default="data/fountains_processed.geojson")
def process(infile, outfile):
    df = (
        pd.read_csv(infile)
          .rename(columns={"fields.geo_point_2d": "coords"})
    )
    df["latitude"]  = df["coords"].apply(lambda x: float(x.strip("[]").split(",")[0]))
    df["longitude"] = df["coords"].apply(lambda x: float(x.strip("[]").split(",")[1]))
    keep = [
        "recordid", "fields.name", "fields.address", "latitude",
        "longitude", "fields.geo_local_area"
    ]
    df = df[keep].rename(columns={
        "recordid": "id",
        "fields.name": "name",
        "fields.address": "address",
        "fields.geo_local_area": "geo_local_area"
    })

    # convert → geojson
    import json, geojson
    features = [
        geojson.Feature(
            geometry=geojson.Point((row.longitude, row.latitude)),
            properties=row.drop(["latitude", "longitude"]).to_dict(),
        )
        for _, row in df.iterrows()
    ]
    geojson_data = geojson.FeatureCollection(features)
    Path(outfile).write_text(geojson.dumps(geojson_data, indent=2))
    click.echo(f"Saved {len(df)} cleaned records to {outfile}")

if __name__ == "__main__":
    process()