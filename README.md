# 🚰 YVR Water Fountains

A comprehensive interactive map and database for tracking, rating, and discovering water fountains across Vancouver and Burnaby (more to come soon!).

**🌐 Live Demo**: [kcarbeck.github.io/yvr-water-fountains](https://kcarbeck.github.io/yvr-water-fountains)

![Water Fountains Map](docs/images/map-preview.png)

## ✨ Features

- 🗺️ **Interactive Map**: 429+ water fountains across Vancouver and Burnaby
- 📱 **Mobile Friendly**: Responsive design with touch-friendly controls
- ⭐ **Rating System**: Rate fountains on water quality, flow, temperature, and drainage
- 📸 **Instagram Integration**: Link fountain visits to social media posts
- 🏘️ **Neighborhood Search**: Find fountains by area or maintainer
- 🐕 **Pet Friendly**: Filter for dog-accessible fountains
- 📊 **Data Tracking**: Comprehensive database with operational status and features

## 🚀 Quick Start

### View the Map
Just visit the [live site](https://kcarbeck.github.io/yvr-water-fountains) or run locally:

```bash
git clone https://github.com/yourusername/yvr-water-fountains.git
cd yvr-water-fountains
python scripts/serve_docs.py
# Open http://localhost:8000
```

### Development Setup
```bash
# Setup environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your Supabase credentials

# Initialize database (optional - for contributors)
# Run supabase/schema_v2_updated.sql in your Supabase dashboard
python scripts/etl_pipeline.py
```

## 📊 Data Overview

### Current Dataset
- **429 Total Fountains**
  - 278 Vancouver fountains (Parks & Engineering departments)
  - 151 Burnaby fountains (Parks department)
- **Accurate Coordinates**: Transformed from UTM to WGS84
- **Rich Metadata**: Operational status, pet-friendly flags, maintainer info
- **Community Ratings**: User-contributed quality assessments

### Data Sources
- **Vancouver**: [Open Data Portal](https://opendata.vancouver.ca/)
- **Burnaby**: [Open Data Portal](https://www.burnaby.ca/our-city/open-data)
- **Community**: User ratings and Instagram posts

## 🛠️ Technical Architecture

### Database Schema
```sql
cities → fountains → ratings
                  → instagram_posts
source_datasets → fountains
```

### Tech Stack
- **Database**: Supabase (PostgreSQL + PostGIS)
- **Frontend**: Vanilla HTML/CSS/JS with Leaflet.js
- **Data Processing**: Python with pandas, geopandas
- **Deployment**: Netlify for frontend, Supabase for backend

### Key Files
```
yvr-water-fountains/
├── docs/                    # Web application
│   ├── index.html          # Main map interface
│   ├── table.html          # Table view
│   └── data/               # Generated GeoJSON
├── scripts/                # Data management tools
│   ├── etl_pipeline.py     # Data loading
│   ├── rating_helper.py    # Add/manage ratings
│   └── generate_geojson_api.py # Export for web
├── data/raw/               # Source CSV files
├── supabase/               # Database schema
└── requirements.txt        # Python dependencies
```

## 📱 Using the Application

### Finding Fountains
1. **Browse the Map**: Pan and zoom to explore different areas
2. **Click Markers**: View detailed information about each fountain
3. **Use "My Location"**: Center the map on your current position
4. **Search by Area**: Filter fountains by neighborhood or city

### Rating Fountains
Use the command-line tool to add ratings:

```bash
# Add a rating
python scripts/rating_helper.py rate DFPB0113 8.5 "Great cold water, good pressure!"

# Search fountains
python scripts/rating_helper.py search Vancouver

# Add rating with Instagram post
python scripts/rating_helper.py rate DFPB0067 7.5 "Decent fountain" "https://instagram.com/p/ABC123/"
```

### Data Management
```bash
# Update fountain data from sources
python scripts/etl_pipeline.py

# Generate fresh map data
python scripts/generate_geojson_api.py

# Check database status
python scripts/check_data.py
```

## 🔧 Development

### Adding New Cities
1. Add city to `supabase/schema_v2_updated.sql`
2. Create CSV processor in `etl_pipeline.py`
3. Add source dataset tracking
4. Run ETL pipeline

### Custom Ratings
The rating system supports multiple criteria:
- **Overall Rating** (0-10): General fountain quality
- **Water Quality** (1-10): Taste and cleanliness
- **Flow Pressure** (1-10): Water stream strength
- **Temperature** (1-10): How cold/refreshing
- **Drainage** (1-10): How well water drains away
- **Accessibility** (1-10): Wheelchair/mobility access

### API Usage
Access fountain data programmatically:

```python
from supabase import create_client
import os

supabase = create_client(
    os.getenv("SUPABASE_URL"), 
    os.getenv("SUPABASE_KEY")
)

# Get all fountains
fountains = supabase.table("fountain_details").select("*").execute()

# Get fountains in Vancouver
vancouver = supabase.table("fountain_details").select("*").eq("city_name", "Vancouver").execute()

# Get highly rated fountains
top_rated = supabase.table("fountain_details").select("*").gte("avg_rating", 8.0).execute()
```

## 📈 Project History

This project evolved from a simple fountain mapping exercise into a comprehensive database system:

1. **v1**: Basic GeoJSON files with manual data entry
2. **v2**: Database normalization and automated ETL
3. **v3**: Web application with rating system
4. **v4**: Instagram integration and mobile optimization
5. **Current**: Production deployment with 429+ fountains

## 🤝 Contributing

### Adding Fountain Data
1. Find fountains missing from the map
2. Use `rating_helper.py` to add ratings and notes
3. Submit coordinates for new fountains via issues

### Improving the Map
- UI/UX improvements
- Performance optimizations
- New filter options
- Better mobile experience

### Data Quality
- Verify fountain operational status
- Update seasonal information
- Correct coordinates or descriptions

## 📄 Data Sources & Attribution

- **Vancouver Fountains**: City of Vancouver Open Data Portal
- **Burnaby Fountains**: City of Burnaby Open Data Portal
- **Base Map**: OpenStreetMap contributors
- **Icons**: Leaflet.js default markers
- **Community Data**: User contributions and ratings

## 📱 Browser Support

- ✅ Chrome 90+
- ✅ Firefox 88+
- ✅ Safari 14+
- ✅ Edge 90+
- ✅ Mobile Safari (iOS 13+)
- ✅ Chrome Mobile (Android 7+)

## 🔒 Privacy

- No user tracking or analytics
- Location access only when explicitly requested
- Instagram posts linked via public URLs only
- All fountain data is public information

## 📞 Contact & Feedback

- **GitHub Issues**: Bug reports and feature requests
- **Instagram**: [@yvrwaterfountains](https://instagram.com/yvrwaterfountains) *(coming soon)*
- **Email**: Contact via GitHub profile

## 📋 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- Vancouver and Burnaby for providing open fountain data
- OpenStreetMap community for base mapping
- Supabase for backend infrastructure
- Leaflet.js for mapping capabilities

---

**Built with ❤️ for Vancouver's water fountain community**
