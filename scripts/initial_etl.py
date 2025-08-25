#!/usr/bin/env python3
"""
Initial ETL Pipeline - Load CSV fountains into Supabase with UPSERT functionality
Safely loads data from source CSV files without creating duplicates
"""

import pandas as pd
import os
import json
from supabase import create_client, Client
from dotenv import load_dotenv
from pathlib import Path
import logging
from pyproj import Transformer
from typing import Dict, List, Optional

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

load_dotenv()

class InitialETL:
    def __init__(self, update_only=False):
        self.supabase: Client = create_client(
            os.getenv("SUPABASE_URL"), 
            os.getenv("SUPABASE_KEY")
        )
        self.project_root = Path(__file__).parent.parent
        self.update_only = update_only  # If True, only update existing fountains
        
        # UTM Zone 10N to WGS84 transformer (Vancouver/Burnaby area)
        self.transformer = Transformer.from_crs("EPSG:26910", "EPSG:4326", always_xy=True)
        
    def ensure_cities_exist(self):
        """Ensure Vancouver and Burnaby cities exist in database"""
        logger.info("🏙️ Ensuring cities exist...")
        
        cities_to_check = [
            {"name": "Vancouver", "province": "BC", "country": "Canada"},
            {"name": "Burnaby", "province": "BC", "country": "Canada"}
        ]
        
        for city_data in cities_to_check:
            # Check if city exists
            existing = self.supabase.table("cities").select("id").eq("name", city_data["name"]).execute()
            
            if not existing.data:
                # Insert city
                result = self.supabase.table("cities").insert(city_data).execute()
                logger.info(f"   ✅ Created city: {city_data['name']}")
            else:
                logger.info(f"   ✅ City exists: {city_data['name']} (ID: {existing.data[0]['id']})")
    
    def get_city_id(self, city_name: str) -> int:
        """Get city ID by name"""
        result = self.supabase.table("cities").select("id").eq("name", city_name).execute()
        return result.data[0]["id"]
    
    def convert_utm_to_wgs84(self, utm_x: float, utm_y: float) -> tuple:
        """Convert UTM coordinates to WGS84 lat/lon"""
        try:
            lon, lat = self.transformer.transform(utm_x, utm_y)
            return lat, lon
        except Exception as e:
            logger.error(f"Error converting coordinates ({utm_x}, {utm_y}): {e}")
            return None, None
    
    def extract_coordinates_from_geom(self, geom_str: str) -> tuple:
        """Extract UTM coordinates from Vancouver CSV Geom field and convert to lat/lon"""
        try:
            geom_data = json.loads(geom_str)
            utm_x, utm_y = geom_data["coordinates"]
            # Convert UTM to lat/lon
            return self.convert_utm_to_wgs84(utm_x, utm_y)
        except Exception as e:
            logger.error(f"Error parsing geom: {e}")
            return None, None
    
    def load_vancouver_fountains(self):
        """Load Vancouver fountains from CSV with UPSERT"""
        logger.info("🚰 Loading Vancouver fountains...")
        
        csv_path = self.project_root / "data" / "raw" / "vancouver_fountains_raw.csv"
        df = pd.read_csv(csv_path)
        logger.info(f"   📊 Found {len(df)} Vancouver fountains in CSV")
        
        vancouver_city_id = self.get_city_id("Vancouver")
        
        processed = 0
        updated = 0
        created = 0
        
        for _, row in df.iterrows():
            # Extract coordinates - prefer Geom field over X,Y
            if pd.notna(row.get("Geom", "")):
                lat, lon = self.extract_coordinates_from_geom(row["Geom"])
            else:
                lat, lon = self.convert_utm_to_wgs84(row["X"], row["Y"])
            
            if lat is None or lon is None:
                logger.warning(f"   ⚠️ Skipping {row['MAPID']} - invalid coordinates")
                continue
            
            # Debug: Show first few coordinate conversions
            if processed < 3:
                logger.info(f"   🔄 {row['MAPID']}: UTM({row['X']}, {row['Y']}) → WGS84({lat:.6f}, {lon:.6f})")
            
            # Prepare fountain data
            fountain_data = {
                "city_id": vancouver_city_id,
                "original_mapid": row["MAPID"],
                "name": self.safe_strip(row.get("LOCATION")),
                "location_description": self.safe_strip(row.get("LOCATION")),
                "detailed_location": self.safe_strip(row.get("DETAILED_LOCATION")),
                "neighborhood": self.safe_strip(row.get("Neighborhood")),
                "type": self.safe_strip(row.get("TYPE")),
                "maintainer": self.safe_strip(row.get("MAINTAINER")),
                "operational_season": self.safe_strip(row.get("IN_OPERATION")),
                "pet_friendly": self.parse_boolean(row.get("PET_FRIENDLY")),
                "lat": lat,
                "lon": lon
            }
            
            # Check if fountain already exists
            existing = self.supabase.table("fountains").select("id").eq("original_mapid", row["MAPID"]).execute()
            
            if existing.data:
                # Update existing fountain
                fountain_id = existing.data[0]["id"]
                self.supabase.table("fountains").update(fountain_data).eq("id", fountain_id).execute()
                updated += 1
                logger.debug(f"   🔄 Updated {row['MAPID']}")
            elif not self.update_only:
                # Insert new fountain only if not in update-only mode
                self.supabase.table("fountains").insert(fountain_data).execute()
                created += 1
                logger.debug(f"   ✅ Created {row['MAPID']}")
            else:
                # Skip creation in update-only mode
                logger.debug(f"   ⏭️ Skipped {row['MAPID']} (update-only mode)")
            
            processed += 1
            if processed % 50 == 0:
                logger.info(f"   📊 Processed {processed}/{len(df)} Vancouver fountains...")
        
        logger.info(f"✅ Vancouver fountains complete: {created} created, {updated} updated, {processed} total")
    
    def load_burnaby_fountains(self):
        """Load Burnaby fountains from CSV with UPSERT"""
        logger.info("🚰 Loading Burnaby fountains...")
        
        csv_path = self.project_root / "data" / "raw" / "burnaby_fountains_raw.csv"
        df = pd.read_csv(csv_path)
        logger.info(f"   📊 Found {len(df)} Burnaby fountains in CSV")
        
        burnaby_city_id = self.get_city_id("Burnaby")
        
        processed = 0
        updated = 0
        created = 0
        
        for _, row in df.iterrows():
            # Convert UTM coordinates to lat/lon
            lat, lon = self.convert_utm_to_wgs84(row["X"], row["Y"])
            
            if lat is None or lon is None:
                logger.warning(f"   ⚠️ Skipping OBJECTID {row['OBJECTID']} - invalid coordinates")
                continue
            
            # Use COMPKEY as the original_mapid for Burnaby fountains
            mapid = str(row['COMPKEY'])
            
            # Debug: Show first few coordinate conversions
            if processed < 3:
                logger.info(f"   🔄 {mapid}: UTM({row['X']}, {row['Y']}) → WGS84({lat:.6f}, {lon:.6f})")
            
            # Prepare fountain data
            fountain_data = {
                "city_id": burnaby_city_id,
                "original_mapid": mapid,
                "name": self.safe_strip(row.get("SITE")),
                "location_description": self.safe_strip(row.get("NOTES")),
                "detailed_location": self.safe_strip(row.get("SITE")),
                "neighborhood": None,  # Not provided in Burnaby data
                "type": self.safe_strip(row.get("TYPE")),
                "maintainer": "Burnaby Parks",  # Assume Burnaby Parks maintains them
                "operational_season": None,  # Not provided in Burnaby data
                "pet_friendly": None,  # Not provided in Burnaby data
                "lat": lat,
                "lon": lon
            }
            
            # Check if fountain already exists
            existing = self.supabase.table("fountains").select("id").eq("original_mapid", mapid).execute()
            
            if existing.data:
                # Update existing fountain
                fountain_id = existing.data[0]["id"]
                self.supabase.table("fountains").update(fountain_data).eq("id", fountain_id).execute()
                updated += 1
                logger.debug(f"   🔄 Updated {mapid}")
            elif not self.update_only:
                # Insert new fountain only if not in update-only mode
                self.supabase.table("fountains").insert(fountain_data).execute()
                created += 1
                logger.debug(f"   ✅ Created {mapid}")
            else:
                # Skip creation in update-only mode
                logger.debug(f"   ⏭️ Skipped {mapid} (update-only mode)")
            
            processed += 1
            if processed % 50 == 0:
                logger.info(f"   📊 Processed {processed}/{len(df)} Burnaby fountains...")
        
        logger.info(f"✅ Burnaby fountains complete: {created} created, {updated} updated, {processed} total")
    
    def safe_strip(self, value) -> Optional[str]:
        """Safely strip a string value, handling NaN and None"""
        if pd.isna(value) or value is None:
            return None
        
        str_val = str(value).strip()
        return str_val if str_val else None
    
    def parse_boolean(self, value) -> Optional[bool]:
        """Parse various boolean representations"""
        if pd.isna(value) or value == "":
            return None
        
        str_val = str(value).lower().strip()
        if str_val in ["true", "yes", "1", "y"]:
            return True
        elif str_val in ["false", "no", "0", "n"]:
            return False
        else:
            return None
    
    def verify_data_integrity(self):
        """Verify loaded data makes sense"""
        logger.info("🔍 Verifying data integrity...")
        
        # Check fountain counts
        fountains = self.supabase.table("fountains").select("id, original_mapid, city_id, lat, lon").execute()
        total_fountains = len(fountains.data)
        
        logger.info(f"   📊 Total fountains in database: {total_fountains}")
        
        # Count by city pattern
        vancouver_count = len([f for f in fountains.data if f["original_mapid"].startswith("DFPB")])
        burnaby_count = len([f for f in fountains.data if f["original_mapid"].isdigit()])  # Burnaby uses numeric COMPKEY
        other_count = total_fountains - vancouver_count - burnaby_count
        
        logger.info(f"   📊 Vancouver fountains (DFPB*): {vancouver_count}")
        logger.info(f"   📊 Burnaby fountains (numeric): {burnaby_count}")
        if other_count > 0:
            logger.info(f"   📊 Other patterns: {other_count}")
        
        # Check coordinate ranges
        if fountains.data:
            lats = [f["lat"] for f in fountains.data if f["lat"]]
            lons = [f["lon"] for f in fountains.data if f["lon"]]
            
            if lats and lons:
                lat_range = (min(lats), max(lats))
                lon_range = (min(lons), max(lons))
                
                logger.info(f"   🗺️ Latitude range: {lat_range[0]:.6f} to {lat_range[1]:.6f}")
                logger.info(f"   🗺️ Longitude range: {lon_range[0]:.6f} to {lon_range[1]:.6f}")
                
                # Vancouver/Burnaby should be roughly:
                # Lat: 49.0 to 49.4, Lon: -123.5 to -122.5
                if 49.0 <= lat_range[0] <= 49.4 and 49.0 <= lat_range[1] <= 49.4:
                    logger.info("   ✅ Latitude range looks correct for Vancouver/Burnaby area")
                else:
                    logger.warning("   ⚠️ Latitude range seems outside expected Vancouver/Burnaby area")
                
                if -123.5 <= lon_range[0] <= -122.5 and -123.5 <= lon_range[1] <= -122.5:
                    logger.info("   ✅ Longitude range looks correct for Vancouver/Burnaby area")
                else:
                    logger.warning("   ⚠️ Longitude range seems outside expected Vancouver/Burnaby area")
        
        logger.info("✅ Data integrity check complete")
    
    def run_etl(self):
        """Run the complete ETL pipeline"""
        mode_text = "UPDATE-ONLY" if self.update_only else "FULL (CREATE + UPDATE)"
        logger.info(f"🚀 Starting ETL Pipeline - Mode: {mode_text}")
        logger.info("=" * 60)
        
        try:
            # Step 1: Ensure cities exist
            self.ensure_cities_exist()
            
            # Step 2: Load Vancouver fountains
            self.load_vancouver_fountains()
            
            # Step 3: Load Burnaby fountains  
            self.load_burnaby_fountains()
            
            # Step 4: Verify data integrity
            self.verify_data_integrity()
            
            logger.info("=" * 60)
            logger.info("🎉 ETL Pipeline completed successfully!")
            logger.info("")
            logger.info("Next steps:")
            logger.info("1. Run review migration: python scripts/review_etl.py")
            logger.info("2. Generate GeoJSON: python scripts/generate_geojson_api.py")
            logger.info("3. Test the web app!")
            
        except Exception as e:
            logger.error(f"❌ ETL Pipeline failed: {e}")
            raise

if __name__ == "__main__":
    import sys
    
    # Check if pyproj is installed
    try:
        import pyproj
    except ImportError:
        print("❌ pyproj library is required for coordinate conversion")
        print("Install with: pip install pyproj")
        exit(1)
    
    # Check for update-only mode
    update_only = "--update-only" in sys.argv
    
    etl = InitialETL(update_only=update_only)
    etl.run_etl()
