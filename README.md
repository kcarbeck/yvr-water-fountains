# 🚰 YVR Water Fountains

An interactive web application mapping 429+ public drinking fountains across Vancouver and Burnaby, featuring Instagram-integrated reviews, community ratings, and comprehensive moderation system.

**🌐 [View Live Application →](https://yvr-water-fountains.netlify.app)**

> 💡 **Full functionality** (including review submissions) available on Netlify deployment
> 📱 **Read-only version** also available on [GitHub Pages](https://kcarbeck.github.io/yvr-water-fountains/map.html)

This readme now contains the key context for contributors, including testing steps and architecture notes.

![Water Fountains Map](docs/images/map-preview.png)

## ✨ Project Highlights

- 🗺️ **Interactive Mapping**: Responsive web application built with Leaflet.js
- 📊 **Data Engineering**: Custom ETL pipeline processing municipal open data
- 🗃️ **Database Design**: Normalized PostgreSQL schema with PostGIS spatial capabilities
- 📱 **Mobile Optimization**: Touch-friendly interface with bottom sheet navigation
- 📸 **Instagram Integration**: Seamless connection with [@yvrwaterfountains](https://www.instagram.com/yvrwaterfountains/) reviews
- 🛡️ **Moderation System**: Professional review management for public submissions
- 🔧 **DevOps**: Automated deployment pipeline with GitHub Pages

## 🛠️ Technical Implementation

### Frontend Architecture
- **Framework**: Vanilla JavaScript with Leaflet.js for mapping
- **Design**: Mobile-first responsive CSS with modern UI patterns
- **UX**: Conditional popups (desktop) vs bottom sheets (mobile)
- **Script organization**: Map behavior now lives in [`docs/js/map.js`](docs/js/map.js) so the HTML remains simple and the logic is easy to review.

### Backend & Data Pipeline
- **Database**: Supabase (PostgreSQL + PostGIS) for spatial data
- **ETL Process**: Python pipeline transforming UTM coordinates to WGS84
- **Data Sources**: Vancouver and Burnaby municipal open data portals
- **Instagram API**: Automated post ID extraction and metadata collection
- **Review System**: Multi-criteria rating system with moderation workflows
- **Validation**: Automated coordinate bounds checking and duplicate detection

### Database schema & supabase setup
- **core schema**: `supabase/migrations/20241015120000_core_schema.sql` defines `cities`, `sources`, `fountains`, `reviews`, the supporting `admins` table, and the SQL views (`fountain_ratings_view`, `fountain_latest_review_view`, `fountain_overview_view`). run this migration once through the supabase sql editor or `supabase db push` so every environment shares the same structure.
- **row level security**: policies allow the public role to read fountains and approved reviews, create pending reviews, and require that admins exist in the `admins` table before they can moderate data. this keeps public submissions safe even when the anon key is embedded in the client.
- **backfill**: after applying the schema, seed production data by running `SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... node scripts/backfill_supabase.mjs`. the script reads `data/fountains_processed.geojson` and `data/ratings.csv`, creates missing cities and sources, and imports historical @yvrwaterfountains reviews as approved admin entries.
- **runtime config**: set `window.__ENV = { SUPABASE_URL: 'https://your-project.supabase.co', SUPABASE_ANON_KEY: 'public-anon-key' };` before loading `docs/config.js` (netlify can inject this with an inline script). when those values are present the map and forms use live data; otherwise they gracefully fall back to static geojson.
- **admin workflow**: `docs/admin_review_form.html` and `docs/moderation_dashboard.html` now prompt for supabase email/password. only users listed in the `admins` table can approve, reject, or publish reviews. successful logins immediately update the map because the client reads from `fountain_overview_view`.

### Key Technical Challenges Solved
1. **Coordinate Transformation**: Converted UTM Zone 10N municipal data to web-standard WGS84
2. **Data Normalization**: Unified disparate CSV formats into consistent schema
3. **Instagram Integration**: Seamless workflow for [@yvrwaterfountains](https://www.instagram.com/yvrwaterfountains/) review management
4. **Review Moderation**: Built comprehensive approval/rejection system for public submissions
5. **Multi-Review Architecture**: Support for multiple reviews per fountain with rating aggregation
6. **Spatial Optimization**: Implemented efficient rendering of 429+ map markers
7. **Mobile Performance**: Custom bottom sheet UI with Instagram post previews

## 🧭 Editing the Map Code

- The map logic now lives in [`docs/js/map.js`](docs/js/map.js), which keeps the HTML file light and makes maintenance easier.
- The script uses plain JavaScript with lots of inline explanations, so you can scroll from top to bottom and follow what each helper does.
- Functions that need to be callable from the HTML (for example the links inside popups) are attached to `window` so they stay available without extra setup.
- Error handling is centralized, so if the GeoJSON file fails to load you will see one clear alert instead of partial failures.

### How to Test Changes Manually

1. Open `docs/map.html` in a browser (double-clicking the file works) and make sure the map pins load.
2. Click a fountain marker on desktop to confirm the popup still shows ratings, Instagram previews, and review text.
3. Shrink the browser window below 768px and click a pin to confirm the bottom sheet opens and can be dismissed.
4. Use the "My Location" button to check geolocation permissions, and click the admin gear icon to confirm the new supabase login panel opens with links to the admin tools.

### Admin testing quickstart

1. Visit `docs/admin_review_form.html`, sign in with a supabase admin account, and ensure the loading spinner is replaced with the review form and the map highlights the selected fountain.
2. Submit a test review with a unique instagram url. Because admin reviews are auto-approved you should see the new entry when you refresh `docs/map.html`.
3. Open `docs/moderation_dashboard.html`, sign in with the same account, and approve or reject a pending review. The counters at the top should update immediately after each action.
4. Use the "My Location" button to check geolocation permissions, and try the admin gear icon to make sure the password prompt still appears.

### Shared helpers sanity check

1. Load `docs/public_review_form.html` locally and submit a sample review (use fake data if needed). A green toast in the corner should confirm the pending submission in addition to the inline alert.
2. While still on the public form, clear your selection to verify the helper utilities reset the hidden supabase id fields and re-center the map.
3. Open `docs/moderation_dashboard.html` and approve or reject a review; watch for the toast notification that now confirms the action and double-check the counts update without a full reload.

## 📊 Project Impact & Results

### Data Successfully Processed
- **429 Public Fountains** mapped across two municipalities
- **Coordinate Accuracy**: All locations validated within Vancouver/Burnaby boundaries
- **Data Integration**: Unified disparate municipal datasets into single schema
- **Performance**: 95% file size reduction through optimization techniques

### User Experience Achievements
- **Cross-Platform Compatibility**: Responsive design works on desktop, tablet, and mobile
- **Accessibility**: Touch-friendly controls and clear visual hierarchy
- **Load Performance**: < 3 second initial load time with 429 map markers
- **Progressive Enhancement**: Graceful degradation for older browsers

## 🔧 Development Methodology

### Problem-Solving Approach
1. **Data Quality Issues**: Implemented validation pipeline catching coordinate anomalies
2. **Performance Optimization**: Built file compression reducing payload by 95%
3. **User Interface Design**: Created adaptive UI (popups vs bottom sheets) based on device capabilities
4. **Deployment Automation**: Established CI/CD workflow with GitHub Pages

### Technical Skills Demonstrated
- **Spatial Data Processing**: UTM to WGS84 coordinate transformation
- **Database Design**: Normalized schema with proper relationships and constraints
- **API Development**: RESTful data endpoints with Supabase
- **Frontend Development**: Modern JavaScript, CSS Grid/Flexbox, responsive design
- **DevOps**: Version control, automated deployment, performance monitoring

## 🎯 Key Features

### For End Users
- **📍 Location Discovery**: Find nearest fountains with geolocation
- **⭐ Multi-Criteria Ratings**: Detailed reviews covering water quality, flow, temperature, cleanliness, and accessibility
- **📸 Instagram Integration**: View linked Instagram posts and reviews from [@yvrwaterfountains](https://www.instagram.com/yvrwaterfountains/)
- **👥 Community Reviews**: Submit public reviews with professional moderation
- **📱 Mobile Experience**: Touch-optimized interface with Instagram post previews
- **🔍 Smart Filtering**: Search by neighborhood, maintainer, or features

### For Developers
- **🔄 ETL Pipeline**: Automated data processing and validation
- **📸 Instagram Workflow**: Streamlined tools for systematically entering Instagram reviews
- **🛡️ Moderation Dashboard**: Professional interface for managing public submissions
- **📊 Analytics**: Track fountain usage patterns and community engagement
- **🛠️ Admin Tools**: Command-line utilities for data management and review moderation
- **📈 Monitoring**: Performance tracking and error handling

## 💼 Professional Context

This project demonstrates proficiency in:

- **Full-Stack Development**: End-to-end application development from data pipeline to user interface
- **Social Media Integration**: Seamless Instagram workflow integration with automated metadata extraction
- **Content Moderation Systems**: Professional review management with approval/rejection workflows
- **Multi-Criteria Rating Systems**: Complex rating aggregation and display across multiple dimensions
- **Spatial Data Engineering**: Working with geographic datasets and coordinate systems
- **API Integration**: Modern backend-as-a-service architecture with Supabase
- **Performance Optimization**: Data compression, lazy loading, and mobile performance
- **User Experience Design**: Responsive design principles and accessibility considerations

### Impact Metrics
- **429 fountains** successfully mapped and validated
- **Instagram Integration** with [@yvrwaterfountains](https://www.instagram.com/yvrwaterfountains/) for systematic review collection
- **Multi-dimensional Rating System** covering 6 criteria (overall, water quality, flow, temperature, cleanliness, accessibility)
- **Professional Moderation Tools** for managing community-submitted reviews
- **Mobile-first design** supporting all modern browsers with Instagram post previews
- **Zero-downtime deployment** via GitHub Pages

---

## 📄 Open Data Attribution

- **Municipal Data**: City of Vancouver & City of Burnaby Open Data Portals
- **Mapping**: OpenStreetMap contributors
- **Infrastructure**: Supabase, GitHub Pages, Leaflet.js

## 📋 License

MIT License - see [LICENSE](LICENSE) for details.

---

**🚀 Built by Katherine Carbeck** | [GitHub](https://github.com/kcarbeck) | [LinkedIn](https://linkedin.com/in/kcarbeck)
