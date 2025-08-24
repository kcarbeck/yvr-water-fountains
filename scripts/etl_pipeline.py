#!/usr/bin/env python3
"""
ETL Pipeline for YVR Water Fountains
Processes raw CSV files and loads into normalized database structure
"""

import pandas as pd
import json
from pathlib import Path
from supabase import create_client, Client
from dotenv import load_dotenv
import os
from typing import Dict, List, Optional
import logging
from pyproj import Transformer

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

class FountainETL:
    def __init__(self):
        self.supabase: Client = create_client(
            os.getenv("SUPABASE_URL"), 
            os.getenv("SUPABASE_KEY")
        )
        self.project_root = Path(__file__).parent.parent
        # Set up coordinate transformer from EPSG:26910 (UTM Zone 10N) to EPSG:4326 (WGS84)
        self.transformer = Transformer.from_crs("EPSG:26910", "EPSG:4326", always_xy=True)
        
    def get_or_create_city(self, city_name: str) -> int:
        """Get city ID, create if doesn't exist"""
        result = self.supabase.table("cities").select("id").eq("name", city_name).execute()
        
        if result.data:
            return result.data[0]["id"]
        else:
            # Create new city
            result = self.supabase.table("cities").insert({"name": city_name}).execute()
            return result.data[0]["id"]
    
    def get_or_create_source_dataset(self, city_name: str, dataset_name: str) -> int:
        """Get or create source dataset record"""
        result = self.supabase.table("source_datasets").select("id").eq("city_name", city_name).eq("dataset_name", dataset_name).execute()
        
        if result.data:
            return result.data[0]["id"]
        else:
            result = self.supabase.table("source_datasets").insert({
                "city_name": city_name,
                "dataset_name": dataset_name,
                "data_format": "csv",
                "last_updated": pd.Timestamp.now().date().isoformat()
            }).execute()
            return result.data[0]["id"]
    
    def process_vancouver_data(self) -> List[Dict]:
        """Process Vancouver fountain CSV data"""
        logger.info("Processing Vancouver fountain data...")
        
        csv_path = self.project_root / "data" / "raw" / "vancouver_fountains_raw.csv"
        df = pd.read_csv(csv_path)
        
        city_id = self.get_or_create_city("Vancouver")
        source_id = self.get_or_create_source_dataset("Vancouver", "Vancouver Parks Open Data")
        
        fountains = []
        
        for _, row in df.iterrows():
            # Parse coordinates from UTM (EPSG:26910) and transform to WGS84
            try:
                utm_x, utm_y = float(row['X']), float(row['Y'])
                # Transform from UTM Zone 10N to WGS84 lat/lon
                lon, lat = self.transformer.transform(utm_x, utm_y)
                
                if not (-90 <= lat <= 90 and -180 <= lon <= 180):
                    logger.warning(f"Invalid transformed coordinates for Vancouver fountain {row.get('MAPID', 'unknown')}: lat={lat}, lon={lon}")
                    continue
            except (ValueError, TypeError) as e:
                logger.error(f"Could not parse/transform coordinates for Vancouver fountain {row.get('MAPID', 'unknown')}: {e}")
                continue
            
            # Parse operational season
            operational_season = 'unknown'  # Default for blank/NA
            if pd.notna(row['IN_OPERATION']):
                op_status = str(row['IN_OPERATION']).lower().strip()
                if op_status and op_status != '':  # Not empty
                    if op_status in ['spring to fall', 'may-october']:
                        operational_season = op_status
                    elif op_status in ['year-round', 'year round']:
                        operational_season = 'year-round'
                    else:
                        operational_season = op_status  # Keep original if not recognized
            
            # Parse pet_friendly
            pet_friendly = False
            if pd.notna(row['PET_FRIENDLY']):
                pet_friendly = str(row['PET_FRIENDLY']).upper() == 'Y'
            
            fountain_data = {
                "city_id": city_id,
                "source_dataset_id": source_id,
                "name": str(row.get('LOCATION', '') or '').strip() or None,
                "location_description": str(row.get('DETAILED_LOCATION', '') or '').strip() or None,
                "neighborhood": str(row.get('Neighborhood', '') or '').strip() or None,
                "type": str(row.get('TYPE', '') or '').strip() or None,
                "lat": lat,
                "lon": lon,
                "location": f"POINT({lon} {lat})",
                "operational_season": operational_season,
                "pet_friendly": pet_friendly,
                "maintainer": str(row.get('MAINTAINER', '') or '').strip() or None,
                "original_mapid": str(row.get('MAPID', '') or '').strip() or None
            }
            
            fountains.append(fountain_data)
        
        logger.info(f"Processed {len(fountains)} Vancouver fountains")
        return fountains
    
    def process_burnaby_data(self) -> List[Dict]:
        """Process Burnaby fountain CSV data"""
        logger.info("Processing Burnaby fountain data...")
        
        csv_path = self.project_root / "data" / "raw" / "burnaby_fountains_raw.csv"
        df = pd.read_csv(csv_path)
        
        city_id = self.get_or_create_city("Burnaby")
        source_id = self.get_or_create_source_dataset("Burnaby", "Burnaby Open Data")
        
        fountains = []
        
        for _, row in df.iterrows():
            # Parse coordinates from UTM (EPSG:26910) and transform to WGS84
            try:
                utm_x, utm_y = float(row['X']), float(row['Y'])
                # Transform from UTM Zone 10N to WGS84 lat/lon
                lon, lat = self.transformer.transform(utm_x, utm_y)
                
                if not (-90 <= lat <= 90 and -180 <= lon <= 180):
                    logger.warning(f"Invalid transformed coordinates for Burnaby fountain {row.get('COMPKEY', 'unknown')}: lat={lat}, lon={lon}")
                    continue
            except (ValueError, TypeError) as e:
                logger.error(f"Could not parse/transform coordinates for Burnaby fountain {row.get('COMPKEY', 'unknown')}: {e}")
                continue
            
            # Map Burnaby types to more descriptive names
            type_mapping = {
                'DF': 'Drinking Fountain',
                'DDF': 'Dual Drinking Fountain', 
                'ST': 'Standard Fountain',
                'BF': 'Bottle Filler'
            }
            
            # Handle TYPE field with NaN values
            type_raw = row.get('TYPE', '')
            if pd.notna(type_raw):
                fountain_type = type_mapping.get(type_raw, type_raw)
            else:
                # Default for NaN TYPE - check UNITID for clues
                unitid = str(row.get('UNITID', '') or '')
                if 'FOUN' in unitid.upper():
                    fountain_type = "Water Fountain"
                else:
                    fountain_type = "Water Feature"
            
            fountain_data = {
                "city_id": city_id,
                "source_dataset_id": source_id,
                "name": f"{fountain_type} - {str(row.get('SITE', '') or str(row.get('UNITID', '') or 'Unknown Location'))}".strip().rstrip(' -').strip(),
                "location_description": str(row.get('NOTES', '') or '').strip() or None,
                "detailed_location": f"{str(row.get('SITE', '') or '').strip()} (ID: {str(row.get('OBJECTID', '') or '')})".strip() if str(row.get('SITE', '') or '').strip() else None,
                "type": fountain_type,
                "lat": lat,
                "lon": lon,
                "location": f"POINT({lon} {lat})",
                "operational_season": 'unknown',  # Default for Burnaby data (not specified)
                "pet_friendly": False,  # Not specified in Burnaby data
                "maintainer": "Parks",  # Inferred from data source
                "original_mapid": str(row.get('COMPKEY', '')) if pd.notna(row.get('COMPKEY')) else None  # COMPKEY is Burnaby's equivalent to Vancouver's MAPID
            }
            
            fountains.append(fountain_data)
        
        logger.info(f"Processed {len(fountains)} Burnaby fountains")
        return fountains
    
    def load_fountains(self, fountains: List[Dict]):
        """Load fountain data into database"""
        logger.info(f"Loading {len(fountains)} fountains into database...")
        
        # Clear existing fountain data to avoid duplicates
        logger.info("Clearing existing fountain data...")
        try:
            self.supabase.table("fountains").delete().neq("id", "non-existent").execute()
            logger.info("Cleared existing fountain data")
        except Exception as e:
            logger.warning(f"Could not clear existing data: {e}")
        
        # Insert in batches
        batch_size = 50
        successful_inserts = 0
        for i in range(0, len(fountains), batch_size):
            batch = fountains[i:i + batch_size]
            
            # Clean batch: remove None values, fix float precision, and let database generate UUIDs
            cleaned_batch = []
            for fountain in batch:
                skip_fountain = False
                cleaned_fountain = {}
                
                for k, v in fountain.items():
                    if v is not None:
                        # Handle pandas NaN values first
                        import pandas as pd
                        if pd.isna(v):
                            # Skip NaN values - they'll be treated as None and filtered out
                            continue
                        
                        # Fix float precision issues for lat/lon and other numeric fields
                        if isinstance(v, (int, float)):
                            # Check for NaN or infinity (additional check for numpy NaN)
                            import math
                            if math.isnan(v) or math.isinf(v):
                                logger.warning(f"Invalid numeric value {v} for field {k} in fountain {fountain.get('original_mapid', 'unknown')}")
                                skip_fountain = True
                                break
                            
                            # Special handling for lat/lon
                            if k in ['lat', 'lon']:
                                # Check for valid range
                                if k == 'lat' and not (-90 <= v <= 90):
                                    logger.warning(f"Invalid latitude {v} for fountain {fountain.get('original_mapid', 'unknown')}")
                                    skip_fountain = True
                                    break
                                elif k == 'lon' and not (-180 <= v <= 180):
                                    logger.warning(f"Invalid longitude {v} for fountain {fountain.get('original_mapid', 'unknown')}")
                                    skip_fountain = True
                                    break
                            
                            # Convert to proper types for database
                            if k in ['city_id', 'source_dataset_id']:
                                # These must be integers, not floats
                                v = int(v)
                            elif k in ['pet_friendly']:
                                # This must be boolean, not float
                                v = bool(v) and v != 0.0
                            else:
                                # Round other floats to avoid JSON precision issues
                                v = round(float(v), 10)
                        cleaned_fountain[k] = v
                
                # Only add if we have valid coordinates and didn't skip
                if not skip_fountain and 'lat' in cleaned_fountain and 'lon' in cleaned_fountain:
                    # Remove id field to let database auto-generate UUID
                    cleaned_fountain.pop('id', None)
                    cleaned_batch.append(cleaned_fountain)
            
            try:
                if cleaned_batch:  # Only try to insert if we have valid fountains
                    result = self.supabase.table("fountains").insert(cleaned_batch).execute()
                    successful_inserts += len(cleaned_batch)
                    logger.info(f"Inserted batch {i//batch_size + 1}: {len(cleaned_batch)} fountains")
                else:
                    logger.warning(f"Batch {i//batch_size + 1}: All fountains had invalid coordinates, skipping")
            except Exception as e:
                logger.error(f"Error inserting batch {i//batch_size + 1}: {e}")
                # Debug: show the problematic data
                for idx, fountain in enumerate(cleaned_batch):
                    logger.error(f"  Fountain {idx}: {fountain.get('original_mapid', 'unknown')} - lat: {fountain.get('lat')}, lon: {fountain.get('lon')}")
                # Continue with next batch
        
        logger.info(f"Successfully inserted {successful_inserts} out of {len(fountains)} fountains")
    
    def migrate_existing_ratings(self):
        """Migrate existing ratings from old structure"""
        logger.info("Migrating existing ratings...")
        
        ratings_path = self.project_root / "data" / "ratings.csv"
        if not ratings_path.exists():
            logger.info("No existing ratings file found")
            return
        
        df = pd.read_csv(ratings_path)
        
        migrated_ratings = []
        migrated_instagram = []
        
        for _, row in df.iterrows():
            # Find fountain by original mapid
            fountain_result = self.supabase.table("fountains").select("id").eq("original_mapid", row["id"]).execute()
            
            if not fountain_result.data:
                logger.warning(f"Could not find fountain with mapid {row['id']}")
                continue
                
            fountain_id = fountain_result.data[0]["id"]
            
            # Parse visit date
            visit_date = None
            if pd.notna(row["visit_date"]):
                try:
                    visit_date = pd.to_datetime(row["visit_date"]).date().isoformat()
                except:
                    logger.warning(f"Could not parse date: {row['visit_date']}")
            
            # Create rating record
            rating_data = {
                "fountain_id": fountain_id,
                "overall_rating": float(row["rating"]) if pd.notna(row["rating"]) else None,
                "flow_pressure": int(row["flow"]) if pd.notna(row["flow"]) else None,
                "temperature": int(row["temp"]) if pd.notna(row["temp"]) else None,
                "drainage": int(row["drainage"]) if pd.notna(row["drainage"]) else None,
                "visited": str(row["visited"]).upper() == "YES" if pd.notna(row["visited"]) else False,
                "visit_date": visit_date,
                "notes": row.get("caption", "").strip() or None
            }
            
            migrated_ratings.append(rating_data)
            
            # Create Instagram post record if URL exists
            if pd.notna(row["ig_post_url"]) and row["ig_post_url"].strip():
                instagram_data = {
                    "fountain_id": fountain_id,
                    "post_url": row["ig_post_url"].strip(),
                    "caption": row.get("caption", "").strip() or None,
                    "date_posted": visit_date
                }
                migrated_instagram.append(instagram_data)
        
        # Insert ratings
        if migrated_ratings:
            self.supabase.table("ratings").insert(migrated_ratings).execute()
            logger.info(f"Migrated {len(migrated_ratings)} ratings")
        
        # Insert Instagram posts (skip duplicates)
        if migrated_instagram:
            try:
                self.supabase.table("instagram_posts").insert(migrated_instagram).execute()
                logger.info(f"Migrated {len(migrated_instagram)} Instagram posts")
            except Exception as e:
                if "duplicate key" in str(e):
                    logger.info(f"Skipped {len(migrated_instagram)} Instagram posts (already exist)")
                else:
                    logger.error(f"Error migrating Instagram posts: {e}")
    
    def run_full_etl(self):
        """Run the complete ETL pipeline"""
        logger.info("Starting full ETL pipeline...")
        
        try:
            # Process and load fountain data
            vancouver_fountains = self.process_vancouver_data()
            burnaby_fountains = self.process_burnaby_data()
            
            all_fountains = vancouver_fountains + burnaby_fountains
            self.load_fountains(all_fountains)
            
            # Migrate existing ratings
            self.migrate_existing_ratings()
            
            logger.info("ETL pipeline completed successfully!")
            
        except Exception as e:
            logger.error(f"ETL pipeline failed: {e}")
            raise

if __name__ == "__main__":
    etl = FountainETL()
    etl.run_full_etl()
