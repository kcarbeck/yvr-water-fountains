# author: katherine carbeck
# 14 may 2025
# script to fetch vancouver drinking fountains data


import requests
import pandas as pd
import click

API_URL = "https://opendata.vancouver.ca/api/records/1.0/search/"
DATASET = "drinking-fountains"

@click.command()
@click.option("--out", default="data/fountains_raw.csv", help="Where to save raw data")
def fetch(out):
    params = {"dataset": DATASET, "rows": 5000}
    r = requests.get(API_URL, params=params)
    r.raise_for_status()
    recs = r.json()["records"]
    df = pd.json_normalize(recs)
    df.to_csv(out, index=False)
    click.echo(f"Saved {len(df)} records to {out}")

if __name__ == "__main__":
    fetch()

    