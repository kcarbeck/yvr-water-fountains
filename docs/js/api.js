(function (global) {
  'use strict';

  const config = global.APP_CONFIG || {};
  let cachedClient = null;

  // determines if we have enough information to talk to supabase
  function hasCredentials() {
    return Boolean(global.supabase && config.SUPABASE_URL && config.SUPABASE_ANON_KEY);
  }

  // shared supabase client with session persistence for admin flows
  function getClient() {
    if (cachedClient) {
      return cachedClient;
    }

    if (!hasCredentials()) {
      return null;
    }

    cachedClient = global.supabase.createClient(
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

  function ensureClient(client) {
    const activeClient = client || getClient();
    if (!activeClient) {
      throw new Error('supabase client is not configured');
    }
    return activeClient;
  }

  // returns fountain overview rows sorted by name
  async function fetchFountainOverview(client) {
    const activeClient = ensureClient(client);
    const { data, error } = await activeClient
      .from('fountain_overview_view')
      .select('*')
      .order('name', { ascending: true });

    if (error) {
      throw error;
    }

    return data || [];
  }

  // returns the admin profile for the supplied user id
  async function fetchAdminProfile(userId, client) {
    if (!userId) {
      return null;
    }
    const activeClient = ensureClient(client);
    const { data, error } = await activeClient
      .from('admins')
      .select('user_id, display_name')
      .eq('user_id', userId)
      .maybeSingle();

    if (error && error.code !== 'PGRST116') {
      throw error;
    }

    return data || null;
  }

  // inserts a new public review with pending status
  async function insertPublicReview(payload, client) {
    const activeClient = ensureClient(client);
    const { error } = await activeClient
      .from('reviews')
      .insert(payload);

    if (error) {
      throw error;
    }
  }

  // inserts an admin-authored review that is immediately approved
  async function insertAdminReview(payload, client) {
    const activeClient = ensureClient(client);
    const { error } = await activeClient
      .from('reviews')
      .insert(payload);

    if (error) {
      throw error;
    }
  }

  // loads reviews by status in ascending created order
  async function fetchReviewsByStatus(status, client) {
    const activeClient = ensureClient(client);
    const { data, error } = await activeClient
      .from('reviews')
      .select('id, fountain_id, reviewer_name, reviewer_email, rating, water_quality, flow_pressure, temperature, cleanliness, accessibility, review_text, instagram_url, visit_date, created_at, author_type')
      .eq('status', status)
      .order('created_at', { ascending: true });

    if (error) {
      throw error;
    }

    return data || [];
  }

  // counts reviews for a status and optional starting iso timestamp
  async function countReviewsByStatus(status, options, client) {
    const activeClient = ensureClient(client);
    const query = activeClient
      .from('reviews')
      .select('id', { count: 'exact', head: true })
      .eq('status', status);

    if (options && options.since) {
      query.gte('reviewed_at', options.since);
    }

    const { count, error } = await query;
    if (error) {
      throw error;
    }

    return count || 0;
  }

  // updates the moderation status of a review
  async function updateReviewStatus(reviewId, status, extra, client) {
    const activeClient = ensureClient(client);
    const payload = Object.assign({ status }, extra || {});
    const { error } = await activeClient
      .from('reviews')
      .update(payload)
      .eq('id', reviewId);

    if (error) {
      throw error;
    }
  }

  const exported = {
    getClient,
    hasCredentials,
    fetchFountainOverview,
    fetchAdminProfile,
    insertPublicReview,
    insertAdminReview,
    fetchReviewsByStatus,
    countReviewsByStatus,
    updateReviewStatus
  };

  global.AppApi = exported;
  global.createSupabaseClient = getClient;
  global.hasSupabaseCredentials = hasCredentials;

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = exported;
  }
})(typeof window !== 'undefined' ? window : global);
