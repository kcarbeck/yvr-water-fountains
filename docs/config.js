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
    MAP_CENTER: [49.251, -123.060],
    MAP_ZOOM: 11,
    GEOJSON_PATH: 'data/fountains_processed.geojson',
    SUPABASE_URL: env.SUPABASE_URL || window.SUPABASE_URL || null,
    SUPABASE_ANON_KEY: env.SUPABASE_ANON_KEY || window.SUPABASE_ANON_KEY || null,
    VERSION: '1.0.0',
    DEPLOYMENT_TYPE: isNetlify ? 'netlify' : (isGitHubPages ? 'github-pages' : 'custom')
  };
})();
