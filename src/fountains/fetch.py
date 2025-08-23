# author: katherine carbeck
# 14 may 2025
# script to fetch vancouver drinking fountains data and save as csv

import requests
import pandas as pd
import click
from pathlib import Path

API_URL = (
    "https://opendata.vancouver.ca/"
    "api/explore/v2.1/catalog/datasets/drinking-fountains/records"
)

@click.command()
@click.option(
    "--out",
    default="data/fountains_raw.csv",
    show_default=True,
    help="Path to save the raw CSV",
)
@click.option(
    "--limit",
    default=5000,
    show_default=True,
    help="Maximum records to request (today there are < 500)",
)
def main(out: str, limit: int) -> None:
    """Download dataset → CSV."""
    Path(out).parent.mkdir(parents=True, exist_ok=True)

    params = {"limit": limit}
    resp = requests.get(API_URL, params=params, timeout=30)
    resp.raise_for_status()

    records = resp.json()["results"]       # v2 API returns {"results": [...]}
    df = pd.json_normalize(records)
    df.to_csv(out, index=False)

    click.echo(f"✓ saved {len(df):,} raw records → {out}")

if __name__ == "__main__":  # pragma: no cover
    main()