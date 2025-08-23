# YVR Water Fountains Project

A comprehensive database and web application for tracking, rating, and mapping water fountains across Vancouver, Burnaby, and surrounding areas.

## 🚀 Quick Start

### Prerequisites
- Python 3.9+
- Supabase account
- Environment variables (see `.env.example`)

### Setup
```bash
# Clone and setup environment
cd yvr-water-fountains
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt

# Copy environment template
cp .env.example .env
# Edit .env with your Supabase credentials
```

### Migration from Old Structure
If you have existing data:
```bash
# 1. Backup and prepare migration
python scripts/migrate_to_v2.py

# 2. Apply new schema in Supabase dashboard
# Run: supabase/schema_v2.sql

# 3. Load clean data
python scripts/etl_pipeline.py
```

### Fresh Installation
For new installations:
```bash
# 1. Apply schema in Supabase dashboard
# Run: supabase/schema_v2.sql

# 2. Load fountain data
python scripts/etl_pipeline.py
```

## 📊 Database Structure

### Core Tables
- **cities**: Vancouver, Burnaby, etc.
- **fountains**: Location, features, operational status
- **ratings**: User ratings with detailed metrics
- **instagram_posts**: Social media integration
- **source_datasets**: Data provenance tracking

### Key Features
- ✅ Normalized design with proper relationships
- ✅ PostGIS integration for geographic queries
- ✅ Rating system with multiple criteria
- ✅ Instagram post tracking
- ✅ Data source attribution
- ✅ Seasonal operation tracking

## 🗺️ Data Sources

### Vancouver
- **Source**: Vancouver Open Data
- **File**: `data/raw/vancouver_fountains_raw.csv`
- **Features**: 270+ fountains with operational status, pet-friendly flags

### Burnaby
- **Source**: Burnaby Open Data  
- **File**: `data/raw/burnaby_fountains_raw.csv`
- **Features**: 150+ fountains with location details

## 📱 Usage Examples

### Adding Ratings
```python
from scripts.rating_helper import add_rating

add_rating(
    fountain_mapid="DFPB0113",
    overall_rating=7.5,
    water_quality=8,
    flow_pressure=6,
    temperature=7,
    drainage=8,
    notes="Great fountain, cold water!",
    instagram_url="https://instagram.com/p/ABC123/"
)
```

### Querying Data
```sql
-- Find top-rated fountains in Vancouver
SELECT fd.name, fd.city_name, fd.avg_rating, fd.rating_count
FROM fountain_details fd 
WHERE fd.city_name = 'Vancouver' 
  AND fd.avg_rating > 8
ORDER BY fd.avg_rating DESC;

-- Find fountains near a location (within 1km)
SELECT f.name, f.location_description, 
       ST_Distance(f.location, ST_SetSRID(ST_Point(-123.1207, 49.2827), 4326)) as distance_m
FROM fountains f
WHERE ST_DWithin(f.location, ST_SetSRID(ST_Point(-123.1207, 49.2827), 4326), 1000)
ORDER BY distance_m;
```

## 🛠️ Development Scripts

### Data Management
- `scripts/etl_pipeline.py` - Complete data loading pipeline
- `scripts/migrate_to_v2.py` - Migration from old structure
- `scripts/rating_helper.py` - Helper for adding ratings

### Legacy (to be cleaned up)
- `scripts/load_fountains.py` - Old fountain loader
- `scripts/load_ratings.py` - Old rating loader
- `scripts/make_table.py` - Old table generator

## 📂 Project Structure

```
yvr-water-fountains/
├── data/
│   ├── raw/                          # Source CSV files
│   │   ├── vancouver_fountains_raw.csv
│   │   └── burnaby_fountains_raw.csv
│   └── backups/                      # Migration backups
├── scripts/
│   ├── etl_pipeline.py              # Main ETL process
│   ├── migrate_to_v2.py             # Migration script
│   └── rating_helper.py             # Rating utilities
├── supabase/
│   ├── schema_v2.sql                # New database schema
│   └── seed/                        # Sample data
├── app/                             # Web application (Next.js)
├── docs/                            # Documentation & static site
└── notebooks/                       # Analysis notebooks
```

## 🎯 Roadmap

### Phase 1: Core Infrastructure ✅
- [x] Normalized database schema
- [x] ETL pipeline for data loading
- [x] Migration from old structure

### Phase 2: Enhanced Features
- [ ] Web application with interactive map
- [ ] Mobile-responsive design
- [ ] Advanced filtering and search
- [ ] User authentication for ratings

### Phase 3: Community Features  
- [ ] Multi-user rating system
- [ ] Photo uploads
- [ ] Fountain status updates
- [ ] API for third-party integrations

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes and test thoroughly
4. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details.

---

**Note**: This project is a personal initiative to improve public water fountain access in Vancouver area. Data is sourced from municipal open data portals and user contributions.
