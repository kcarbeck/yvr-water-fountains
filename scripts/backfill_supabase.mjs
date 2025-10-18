#!/usr/bin/env node
'use strict';

import { createClient } from '@supabase/supabase-js';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');

/**
 * reads the geojson and csv datasets and upserts them into the new supabase schema.
 */
async function main() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !serviceRoleKey) {
    console.error('set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY before running this script.');
    process.exit(1);
  }

  const client = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } });

  const [geojson, ratingsCsv] = await Promise.all([
    loadGeojson(path.join(rootDir, 'data', 'fountains_processed.geojson')),
    readFile(path.join(rootDir, 'data', 'ratings.csv'), 'utf8')
  ]);

  const fountainRecords = buildFountainRecords(geojson.features || []);
  const reviewRecords = buildReviewRecords(ratingsCsv);

  const cityRecords = Array.from(new Set(fountainRecords.map((item) => item.city_name)))
    .filter(Boolean)
    .map((name) => ({ name, slug: slugify(name) }));

  const sourceRecords = Array.from(new Set(fountainRecords.map((item) => item.source_name)))
    .filter(Boolean)
    .map((name) => ({ name, slug: slugify(name) }));

  console.log(`upserting ${cityRecords.length} cities, ${sourceRecords.length} sources, and ${fountainRecords.length} fountains.`);

  const cityIdMap = await upsertWithIds(client, 'cities', cityRecords, 'slug');
  const sourceIdMap = await upsertWithIds(client, 'sources', sourceRecords, 'slug');

  const fountainsWithForeignKeys = fountainRecords.map((record) => ({
    ...record,
    city_id: cityIdMap.get(record.city_name) || null,
    source_id: sourceIdMap.get(record.source_name) || null
  }));

  const fountainIdMap = await upsertWithIds(client, 'fountains', fountainsWithForeignKeys, 'external_id');

  const reviews = reviewRecords
    .filter((record) => fountainIdMap.has(record.external_id))
    .map((record) => ({
      fountain_id: fountainIdMap.get(record.external_id),
      author_type: 'admin',
      status: 'approved',
      rating: record.rating,
      water_quality: record.water_quality,
      flow_pressure: record.flow_pressure,
      temperature: record.temperature,
      cleanliness: record.cleanliness,
      accessibility: null,
      review_text: record.review_text,
      instagram_url: record.instagram_url,
      instagram_caption: record.instagram_caption,
      instagram_image_url: record.instagram_image_url,
      visit_date: record.visit_date,
      reviewed_at: record.reviewed_at,
      reviewer_name: '@yvrwaterfountains'
    }));

  console.log(`upserting ${reviews.length} admin reviews.`);
  await chunkedUpsert(client, 'reviews', reviews);

  console.log('backfill complete.');
}

async function loadGeojson(filePath) {
  const raw = await readFile(filePath, 'utf8');
  return JSON.parse(raw);
}

function buildFountainRecords(features) {
  return features.map((feature) => {
    const props = feature.properties || {};
    const coordinates = feature.geometry && feature.geometry.coordinates ? feature.geometry.coordinates : [null, null];
    return {
      external_id: props.id || null,
      name: props.name || 'Unnamed Fountain',
      city_name: deriveCity(props),
      source_name: deriveSource(props),
      neighbourhood: props.geo_local_area || props.neighborhood || null,
      location_description: props.location || props.address || null,
      latitude: coordinates[1],
      longitude: coordinates[0],
      operational_status: normalizeOperationalStatus(props.in_operation),
      season_note: props.in_operation || null,
      pet_friendly: normalizePetFriendly(props.pet_friendly),
      has_bottle_filler: normalizeFlag(props.bottle_filler),
      is_wheelchair_accessible: normalizeFlag(props.wheelchair_accessible),
      last_verified_at: parseDate(props.last_service_date)
    };
  }).filter((record) => typeof record.latitude === 'number' && typeof record.longitude === 'number');
}

function buildReviewRecords(csvText) {
  const rows = parseCsv(csvText);
  const headers = rows.shift();
  if (!headers) {
    return [];
  }

  return rows
    .filter((row) => row.length > 0 && row[0])
    .map((row) => {
      const record = Object.fromEntries(headers.map((header, index) => [header, row[index]]));
      const rating = toNumber(record.rating);
      return {
        external_id: record.id,
        instagram_url: record.ig_post_url || null,
        instagram_caption: record.caption || null,
        instagram_image_url: buildInstagramImageUrl(record.ig_post_url),
        rating,
        water_quality: toNumber(record.rating),
        flow_pressure: toNumber(record.flow),
        temperature: toNumber(record.temp),
        cleanliness: toNumber(record.drainage),
        review_text: record.caption || null,
        visit_date: parseDate(record.visit_date),
        reviewed_at: parseDate(record.visit_date) || new Date().toISOString()
      };
    });
}

function parseCsv(text) {
  const rows = [];
  let current = [];
  let value = '';
  let inQuotes = false;

  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];
    if (char === '"') {
      if (inQuotes && text[i + 1] === '"') {
        value += '"';
        i += 1;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (char === ',' && !inQuotes) {
      current.push(value);
      value = '';
      continue;
    }
    if ((char === '\n' || char === '\r') && !inQuotes) {
      if (value || current.length) {
        current.push(value);
        rows.push(current);
        current = [];
        value = '';
      }
      continue;
    }
    value += char;
  }

  if (value || current.length) {
    current.push(value);
    rows.push(current);
  }

  return rows;
}

async function upsertWithIds(client, table, records, conflictColumn) {
  if (records.length === 0) {
    return new Map();
  }

  const chunks = chunk(records, 100);
  const idMap = new Map();

  for (const chunkRecords of chunks) {
    const { data, error } = await client
      .from(table)
      .upsert(chunkRecords, { onConflict: conflictColumn, ignoreDuplicates: false })
      .select('id, name, slug, external_id');

    if (error) {
      throw error;
    }

    data.forEach((row) => {
      const key = row.slug || row.name || row.external_id;
      if (key) {
        idMap.set(key, row.id);
      }
    });
  }

  return idMap;
}

async function chunkedUpsert(client, table, records) {
  const chunks = chunk(records, 100);
  for (const batch of chunks) {
    const { error } = await client.from(table).upsert(batch);
    if (error) {
      throw error;
    }
  }
}

function chunk(items, size) {
  const output = [];
  for (let i = 0; i < items.length; i += size) {
    output.push(items.slice(i, i + size));
  }
  return output;
}

function slugify(value) {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
}

function deriveCity(props) {
  const neighborhood = (props.geo_local_area || '').toLowerCase();
  if (neighborhood.includes('burnaby')) {
    return 'Burnaby';
  }
  return 'Vancouver';
}

function deriveSource(props) {
  return props.maintainer || 'Legacy Import';
}

function normalizeOperationalStatus(raw) {
  if (!raw) {
    return 'unknown';
  }
  const value = raw.toLowerCase();
  if (value.includes('year')) {
    return 'operational';
  }
  if (value.includes('spring') || value.includes('summer') || value.includes('fall')) {
    return 'seasonal';
  }
  if (value.includes('closed')) {
    return 'closed';
  }
  return 'unknown';
}

function normalizePetFriendly(raw) {
  if (!raw) {
    return 'unknown';
  }
  const value = raw.toString().toLowerCase();
  if (value.includes('yes')) {
    return 'yes';
  }
  if (value.includes('no')) {
    return 'no';
  }
  return 'unknown';
}

function normalizeFlag(raw) {
  if (!raw) {
    return null;
  }
  const value = raw.toString().toLowerCase();
  if (value.includes('yes')) {
    return true;
  }
  if (value.includes('no')) {
    return false;
  }
  return null;
}

function parseDate(value) {
  if (!value || value === 'Unknown') {
    return null;
  }
  if (value instanceof Date) {
    return value.toISOString().split('T')[0];
  }
  const parts = value.split(/[\/-]/);
  if (parts.length === 3) {
    const [first, second, year] = parts;
    if (year.length === 4) {
      const month = first.padStart(2, '0');
      const day = second.padStart(2, '0');
      return `${year}-${month}-${day}`;
    }
  }
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString().split('T')[0];
}

function toNumber(value) {
  if (value === undefined || value === null || value === '') {
    return null;
  }
  const number = Number.parseFloat(value);
  return Number.isFinite(number) ? number : null;
}

function buildInstagramImageUrl(url) {
  if (!url) {
    return null;
  }
  const match = url.match(/\/p\/([^\/]+)\//);
  if (!match) {
    return null;
  }
  const postId = match[1];
  return `https://instagram.com/p/${postId}/media/?size=l`;
}

main().catch((error) => {
  console.error('backfill failed', error);
  process.exit(1);
});
