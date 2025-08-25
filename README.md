# 🚰 YVR Water Fountains

An interactive web application mapping 429+ public drinking fountains across Vancouver and Burnaby, featuring Instagram-integrated reviews, community ratings, and comprehensive moderation system.

**🌐 [View Live Application →](https://yvr-water-fountains.netlify.app)**

> 💡 **Full functionality** (including review submissions) available on Netlify deployment  
> 📱 **Read-only version** also available on [GitHub Pages](https://kcarbeck.github.io/yvr-water-fountains/map.html)

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

### Backend & Data Pipeline
- **Database**: Supabase (PostgreSQL + PostGIS) for spatial data
- **ETL Process**: Python pipeline transforming UTM coordinates to WGS84
- **Data Sources**: Vancouver and Burnaby municipal open data portals
- **Instagram API**: Automated post ID extraction and metadata collection
- **Review System**: Multi-criteria rating system with moderation workflows
- **Validation**: Automated coordinate bounds checking and duplicate detection

### Key Technical Challenges Solved
1. **Coordinate Transformation**: Converted UTM Zone 10N municipal data to web-standard WGS84
2. **Data Normalization**: Unified disparate CSV formats into consistent schema
3. **Instagram Integration**: Seamless workflow for [@yvrwaterfountains](https://www.instagram.com/yvrwaterfountains/) review management
4. **Review Moderation**: Built comprehensive approval/rejection system for public submissions
5. **Multi-Review Architecture**: Support for multiple reviews per fountain with rating aggregation
6. **Spatial Optimization**: Implemented efficient rendering of 429+ map markers
7. **Mobile Performance**: Custom bottom sheet UI with Instagram post previews

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
