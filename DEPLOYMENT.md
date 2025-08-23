# 🚀 Deployment Guide

This guide covers deploying the YVR Water Fountains project to various platforms.

## 🌐 Netlify Deployment (Recommended)

Netlify is perfect for this project since it's a static site with pre-generated data.

### Quick Deploy to Netlify

1. **Push to GitHub**:
   ```bash
   git add .
   git commit -m "Ready for deployment"
   git push origin main
   ```

2. **Connect to Netlify**:
   - Go to [netlify.com](https://netlify.com) and sign up/login
   - Click "New site from Git"
   - Connect your GitHub repository
   - Configure build settings:
     - **Build command**: `python scripts/generate_geojson_api.py`
     - **Publish directory**: `docs`
     - **Environment variables**: Add your `SUPABASE_URL` and `SUPABASE_KEY`

3. **Deploy**:
   - Click "Deploy site"
   - Your site will be live at `https://random-name.netlify.app`
   - Optionally change the domain name in site settings

### Environment Variables for Netlify

In your Netlify dashboard, add these environment variables:

```
SUPABASE_URL=your_supabase_project_url
SUPABASE_KEY=your_supabase_anon_key
```

### Custom Domain (Optional)

To use a custom domain like `yvr-water-fountains.com`:

1. **In Netlify Dashboard**:
   - Go to Site settings → Domain management
   - Add custom domain
   - Follow DNS configuration instructions

2. **Update README.md**:
   - Change the live demo URL to your custom domain

## 🔄 Automated Updates

### GitHub Actions (Optional)

Set up automated data updates with GitHub Actions:

```yaml
# .github/workflows/update-data.yml
name: Update Fountain Data

on:
  schedule:
    - cron: '0 6 * * 1'  # Weekly on Monday at 6 AM
  workflow_dispatch:  # Manual trigger

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'
          
      - name: Install dependencies
        run: pip install -r requirements.txt
        
      - name: Update fountain data
        env:
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_KEY: ${{ secrets.SUPABASE_KEY }}
        run: |
          python scripts/etl_pipeline.py
          python scripts/generate_geojson_api.py
          
      - name: Commit changes
        run: |
          git config --local user.email "action@github.com"
          git config --local user.name "GitHub Action"
          git add docs/data/
          git diff --staged --quiet || git commit -m "🔄 Auto-update fountain data"
          git push
```

### Manual Updates

To update fountain data manually:

1. **Update Database**:
   ```bash
   python scripts/etl_pipeline.py
   ```

2. **Regenerate Web Data**:
   ```bash
   python scripts/generate_geojson_api.py
   ```

3. **Deploy**:
   ```bash
   git add docs/data/
   git commit -m "Update fountain data"
   git push
   ```
   
   Netlify will automatically redeploy.

## 🌍 Alternative Deployment Options

### Vercel
```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
vercel --prod
```

### GitHub Pages
1. Enable GitHub Pages in repository settings
2. Set source to `docs` folder
3. Your site will be at `https://username.github.io/yvr-water-fountains`

### Firebase Hosting
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Initialize
firebase init hosting

# Deploy
firebase deploy
```

## 📊 Performance Optimization

### Data Optimization
- The GeoJSON file is ~2MB with 429 fountains
- Consider splitting by city if it grows larger
- Enable gzip compression (automatic on Netlify)

### Caching Strategy
- Static assets cached for 1 day
- GeoJSON data cached for 1 hour
- Configure via `netlify.toml`

### Monitoring
- Use Netlify Analytics (built-in)
- Consider Google Analytics if detailed tracking needed
- Monitor site performance with Lighthouse

## 🔒 Security Considerations

### Environment Variables
- **Never commit** Supabase credentials to git
- Use environment variables for all secrets
- Supabase keys should be "anon" keys (read-only for public)

### Content Security Policy
```html
<!-- Add to <head> in HTML files -->
<meta http-equiv="Content-Security-Policy" content="
  default-src 'self';
  script-src 'self' 'unsafe-inline' unpkg.com;
  style-src 'self' 'unsafe-inline' unpkg.com;
  img-src 'self' data: *.tile.openstreetmap.org;
  connect-src 'self' *.supabase.co;
">
```

## 📱 Mobile Optimization

The site is already mobile-optimized, but consider:

- **PWA Features**: Add `manifest.json` for app-like experience
- **Offline Support**: Cache critical data with service worker
- **Performance**: Minimize initial load time

## 🚨 Troubleshooting

### Build Failures
```bash
# Check build logs in Netlify dashboard
# Common issues:
# 1. Missing environment variables
# 2. Python dependency conflicts
# 3. Supabase connection errors
```

### Data Update Issues
```bash
# Test locally first
python scripts/check_data.py

# Verify Supabase connection
python -c "from scripts.etl_pipeline import FountainETL; print('Connection OK')"
```

### Performance Issues
- Check GeoJSON file size in `docs/data/`
- Verify image optimization
- Use browser dev tools to profile

## 📈 Analytics & Monitoring

### Netlify Analytics
- Enabled by default for Pro accounts
- Shows page views, unique visitors, bandwidth

### Custom Analytics
```html
<!-- Add to HTML if needed -->
<script async src="https://www.googletagmanager.com/gtag/js?id=GA_MEASUREMENT_ID"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'GA_MEASUREMENT_ID');
</script>
```

## 🎯 Production Checklist

Before going live:

- [ ] All fountain data loaded correctly (429 fountains)
- [ ] Map displays all markers properly
- [ ] Mobile responsiveness tested
- [ ] All links work (table view, my location)
- [ ] Environment variables configured
- [ ] Custom domain configured (if applicable)
- [ ] SSL certificate active
- [ ] Performance tested (< 3s load time)
- [ ] Cross-browser testing completed
- [ ] README.md updated with live URLs

---

**Need help?** Open an issue on GitHub or check the main README.md for more information.
