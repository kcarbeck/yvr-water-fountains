'use strict';

(function () {
  const env = window.__ENV || {};
  const hostname = window.location && window.location.hostname ? window.location.hostname : '';
  const isNetlify = hostname.includes('netlify.app') || hostname.includes('netlify.com');
  const isGitHubPages = hostname.includes('github.io');

  /**
   * central application settings shared across pages.
   */
  window.APP_CONFIG = {
    API_ENDPOINT: isNetlify ? '/.netlify/functions/submit-review' : null,
    PERSONAL_ACCESS_TOKEN: null,
    REPO_NAME: null,
    ENABLE_API_SUBMISSION: isNetlify,
    FALLBACK_TO_GEOJSON: true,
    ENABLE_AUTO_DEPLOY: false,
    MAP_CENTER: [49.260, -123.090],
    MAP_ZOOM: 12,
    GEOJSON_PATH: 'data/fountains_processed.geojson',
    SUPABASE_URL: env.SUPABASE_URL || window.SUPABASE_URL || 'https://hnyktzfyquvmpthfwpvd.supabase.co',
    SUPABASE_ANON_KEY: env.SUPABASE_ANON_KEY || window.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhueWt0emZ5cXV2bXB0aGZ3cHZkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI0OTM2MzIsImV4cCI6MjA4ODA2OTYzMn0.OJJNyTz0LglcJgfGiNNOcy6tmayagXnpSkYnqg6_M6A',
    VERSION: '1.0.0',
    DEPLOYMENT_TYPE: isNetlify ? 'netlify' : (isGitHubPages ? 'github-pages' : 'custom')
  };
})();
