'use strict';

(function () {
  const config = window.APP_CONFIG || {};
  const cache = {
    geojson: null
  };

  /**
   * fetches fountain data from supabase when available, otherwise falls back to the bundled geojson.
   */
  async function fetchGeoData() {
    if (cache.geojson) {
      return clone(cache.geojson);
    }

    const supabaseClient = window.createSupabaseClient ? window.createSupabaseClient() : null;

    if (supabaseClient) {
      try {
        const geojson = await loadFromSupabase(supabaseClient);
        cache.geojson = geojson;
        return clone(geojson);
      } catch (error) {
        console.warn('supabase fountain fetch failed, falling back to geojson', error);
      }
    }

    const fallback = await loadFromGeojson(config.GEOJSON_PATH);
    cache.geojson = fallback;
    return clone(fallback);
  }

  /**
   * converts geojson output into an array of simple objects for search widgets.
   */
  function getPlainList(geojson) {
    if (!geojson || !Array.isArray(geojson.features)) {
      return [];
    }

    return geojson.features.map((feature) => {
      const props = feature.properties || {};
      const coordinates = feature.geometry && feature.geometry.coordinates ? feature.geometry.coordinates : [null, null];
      return {
        id: props.id || null,
        supabaseId: props.supabase_id || null,
        name: props.name || 'Unnamed Fountain',
        neighborhood: props.neighborhood || null,
        location: props.location || props.address || null,
        latitude: coordinates[1],
        longitude: coordinates[0]
      };
    });
  }

  async function loadFromSupabase(client) {
    const { data, error } = await client
      .from('fountain_overview_view')
      .select('*')
      .order('name', { ascending: true });

    if (error) {
      throw error;
    }

    return transformRecordsToGeojson(data || []);
  }

  async function loadFromGeojson(path) {
    if (!path) {
      throw new Error('no geojson path configured');
    }

    const response = await fetch(path);
    if (!response.ok) {
      throw new Error(`failed to load geojson: ${response.status} ${response.statusText}`);
    }
    return response.json();
  }

  function transformRecordsToGeojson(records) {
    const features = (records || []).reduce((all, record) => {
      if (typeof record.longitude !== 'number' || typeof record.latitude !== 'number') {
        return all;
      }

      const properties = buildProperties(record);
      const feature = {
        type: 'Feature',
        geometry: {
          type: 'Point',
          coordinates: [record.longitude, record.latitude]
        },
        properties
      };

      all.push(feature);
      return all;
    }, []);

    return {
      type: 'FeatureCollection',
      features
    };
  }

  function buildProperties(record) {
    const operationalLabel = buildOperationalLabel(record.operational_status, record.season_note);
    const averageRating = record.average_rating !== null && record.average_rating !== undefined
      ? Number.parseFloat(record.average_rating)
      : null;
    const latestRating = record.latest_review_rating !== null && record.latest_review_rating !== undefined
      ? Number.parseFloat(record.latest_review_rating).toFixed(1)
      : null;

    const instagramPosts = buildInstagramPosts(record);

    return {
      id: record.external_id || record.id,
      supabase_id: record.id,
      name: record.name,
      neighborhood: record.neighbourhood,
      location: record.location_description,
      address: record.location_description,
      city_name: record.city_name,
      source_name: record.source_name,
      currently_operational: operationalLabel,
      operational_status: record.operational_status,
      season_note: record.season_note,
      pet_friendly: formatPetFriendly(record.pet_friendly),
      pet_status: record.pet_friendly,
      avg_rating: averageRating,
      rating_count: record.approved_review_count || 0,
      admin_review_count: record.admin_review_count || 0,
      rating: latestRating,
      latest_reviewer: deriveReviewer(record),
      latest_review_author_type: record.latest_review_author_type,
      latest_review_text: record.latest_review_text,
      latest_review_instagram_caption: record.latest_review_instagram_caption,
      latest_reviewed_at: record.latest_reviewed_at,
      caption: record.latest_review_text || record.latest_review_instagram_caption,
      has_instagram: instagramPosts.length > 0,
      instagram_posts: instagramPosts,
      wheelchair_accessible: formatAvailability(record.is_wheelchair_accessible),
      bottle_filler: formatAvailability(record.has_bottle_filler),
      last_verified_at: record.last_verified_at
    };
  }

  function buildOperationalLabel(status, seasonNote) {
    if (status === 'operational') {
      return 'operational';
    }
    if (status === 'seasonal') {
      return seasonNote ? `seasonal (${seasonNote})` : 'seasonal';
    }
    if (status === 'closed') {
      return 'closed';
    }
    return seasonNote || 'unknown';
  }

  function formatPetFriendly(value) {
    if (value === true || value === 'yes') {
      return 'Yes';
    }
    if (value === false || value === 'no') {
      return 'No';
    }
    if (typeof value === 'string') {
      const normalized = value.toLowerCase();
      if (normalized.includes('yes')) {
        return 'Yes';
      }
      if (normalized.includes('no')) {
        return 'No';
      }
    }
    return 'unknown';
  }

  function formatAvailability(value) {
    if (value === true || value === 'true') {
      return 'Yes';
    }
    if (value === false || value === 'false') {
      return 'No';
    }
    return null;
  }

  function deriveReviewer(record) {
    if (record.latest_review_author_type === 'admin') {
      return '@yvrwaterfountains';
    }
    if (record.latest_review_reviewer_name) {
      return record.latest_review_reviewer_name;
    }
    return 'community reviewer';
  }

  function buildInstagramPosts(record) {
    if (!record.latest_review_instagram_url) {
      return [];
    }

    return [
      {
        url: record.latest_review_instagram_url,
        date_posted: record.latest_reviewed_at,
        rating: record.latest_review_rating !== null && record.latest_review_rating !== undefined
          ? Number.parseFloat(record.latest_review_rating).toFixed(1)
          : null,
        caption: record.latest_review_instagram_caption || record.latest_review_text,
        photo_url: record.latest_review_instagram_image_url || null
      }
    ];
  }

  function clone(source) {
    if (!source) {
      return source;
    }
    if (typeof structuredClone === 'function') {
      return structuredClone(source);
    }
    return JSON.parse(JSON.stringify(source));
  }

  window.FountainData = {
    fetchGeoData,
    getPlainList
  };
})();
