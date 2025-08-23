import json
import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

url: str = os.getenv("SUPABASE_URL")
key: str = os.getenv("SUPABASE_KEY")
supabase: Client = create_client(url, key)

# Clear existing data before loading
#supabase.table("fountains").delete().neq("original_mapid", "non_existent_value_12345").execute()

with open("data/fountains_raw.geojson") as f:
    data = json.load(f)

fountains_data = []

for feature in data["features"]:
    props = feature["properties"]
    coords = feature["geometry"]["coordinates"]
    
    insert_data = {
        "name": props["name"],
        "original_mapid": props["mapid"],
        "location_note": props.get("location"),
        "maintainer": props.get("maintainer"),
        "in_operation": props.get("in_operation"),
        "pet_friendly": props.get("pet_friendly"),
        "photo_name": props.get("photo_name"),
        "geo_local_area": props.get("geo_local_area"),
        "lat": coords[1],
        "lon": coords[0],
        "location": f"POINT({coords[0]} {coords[1]})"
    }
    
    fountains_data.append(insert_data)

supabase.table("fountains").insert(fountains_data).execute()
