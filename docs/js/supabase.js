'use strict';

(function () {
  const config = window.APP_CONFIG || {};
  let cachedClient = null;

  /**
   * returns a supabase client when url and anon key are provided.
   */
  function createClient() {
    if (cachedClient) {
      return cachedClient;
    }

    if (!window.supabase || !config.SUPABASE_URL || !config.SUPABASE_ANON_KEY) {
      return null;
    }

    cachedClient = window.supabase.createClient(
      config.SUPABASE_URL,
      config.SUPABASE_ANON_KEY,
      {
        auth: {
          persistSession: true,
          storageKey: 'yvr-water-fountains-session'
        }
      }
    );

    return cachedClient;
  }

  /**
   * true when a supabase client can be created.
   */
  function hasCredentials() {
    return Boolean(window.supabase && config.SUPABASE_URL && config.SUPABASE_ANON_KEY);
  }

  window.createSupabaseClient = createClient;
  window.hasSupabaseCredentials = hasCredentials;
})();
