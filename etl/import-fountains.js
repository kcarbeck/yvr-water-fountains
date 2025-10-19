#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');
const Papa = require('papaparse');

require('dotenv').config({ path: path.resolve(process.cwd(), '.env') });

const REQUIRED_FIELDS = ['name', 'lat', 'lon', 'external_id'];

async function main() {
  const options = parseArgs(process.argv.slice(2));
  validateOptions(options);

  const csvRows = await loadCsv(options.csv);
  if (!Array.isArray(csvRows) || csvRows.length === 0) {
    console.error('no rows were found in the provided csv file');
    process.exit(1);
  }

  const mapping = buildColumnMapping(Object.keys(csvRows[0]));
  logColumnMapping(mapping);

  const supabase = buildSupabaseClient();
  if (!supabase) {
    console.error('supabase credentials are missing. set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in your .env file.');
    process.exit(1);
  }

  const cityId = await ensureCity(supabase, options.city);
  const licenseSupported = await checkSourceLicenseColumn(supabase);
  const sourceId = await ensureSource(supabase, {
    name: options.source,
    url: options.url,
    license: options.license,
    licenseSupported
  });

  const summary = {
    inserted: 0,
    updated: 0,
    skipped: []
  };

  for (let index = 0; index < csvRows.length; index += 1) {
    const row = csvRows[index];
    const record = buildRecordFromRow(row, mapping, options.city);

    const validationError = validateRecord(record);
    if (validationError) {
      summary.skipped.push({
        row: index + 1,
        externalId: record.external_id || null,
        reason: validationError
      });
      continue;
    }

    const databaseRecord = {
      external_id: record.external_id,
      city_id: cityId,
      source_id: sourceId,
      name: record.name,
      latitude: record.latitude,
      longitude: record.longitude,
      operational_status: record.operational_status,
      season_note: record.season,
      pet_friendly: convertPetFriendlyForDatabase(record.pet_friendly),
      last_verified_at: record.last_verified_at || null
    };

    if (record.neighbourhood) {
      databaseRecord.neighbourhood = record.neighbourhood;
    }
    if (record.location_description) {
      databaseRecord.location_description = record.location_description;
    }

    try {
      const { action } = await upsertFountain(supabase, databaseRecord);
      if (action === 'inserted') {
        summary.inserted += 1;
      } else if (action === 'updated') {
        summary.updated += 1;
      } else {
        summary.skipped.push({
          row: index + 1,
          externalId: record.external_id,
          reason: 'unchanged from existing record'
        });
      }
    } catch (error) {
      summary.skipped.push({
        row: index + 1,
        externalId: record.external_id || null,
        reason: `supabase error: ${error.message}`
      });
    }
  }

  printSummary(summary);
}

function parseArgs(argv) {
  const options = {};

  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith('--')) {
      continue;
    }

    const key = token.slice(2);
    const next = argv[index + 1];
    if (next && !next.startsWith('--')) {
      options[key] = next;
      index += 1;
    } else {
      options[key] = true;
    }
  }

  return options;
}

function validateOptions(options) {
  const required = ['csv', 'city', 'source', 'url', 'license'];
  const missing = required.filter((key) => !options[key]);
  if (missing.length > 0) {
    console.error(`missing required options: ${missing.join(', ')}`);
    process.exit(1);
  }

  if (!fs.existsSync(options.csv)) {
    console.error(`csv file not found: ${options.csv}`);
    process.exit(1);
  }
}

async function loadCsv(filePath) {
  const content = await fs.promises.readFile(filePath, 'utf8');
  const parsed = Papa.parse(content, {
    header: true,
    skipEmptyLines: true,
    transformHeader: (header) => header.trim()
  });

  if (parsed.errors && parsed.errors.length > 0) {
    parsed.errors.forEach((error) => {
      console.warn(`csv parse warning at row ${error.row}: ${error.message}`);
    });
  }

  return parsed.data;
}

function buildColumnMapping(columns) {
  const cleanedColumns = columns.map((column) => column.trim());
  const mapping = {};

  const candidates = {
    name: ['name', 'fountain name', 'title', 'park', 'location', 'site', 'detailed location'],
    lat: ['latitude', 'lat', 'y', 'geom_y', 'geo_latitude'],
    lon: ['longitude', 'lon', 'lng', 'x', 'geom_x', 'geo_longitude'],
    operational: ['operational', 'status', 'in_operation', 'operating status'],
    season: ['season', 'season_note', 'season note', 'seasonal', 'season details'],
    pet_friendly: ['pet_friendly', 'pet friendly', 'pets', 'dog friendly'],
    external_id: ['external_id', 'id', 'mapid', 'objectid', 'unitid', 'compkey', 'uid'],
    neighbourhood: ['neighbourhood', 'neighborhood', 'area'],
    location_description: ['location_description', 'detailed_location', 'detailed location', 'address', 'notes'],
    last_verified_at: ['last_verified_at', 'last verified', 'verified_at', 'last verified date']
  };

  const normalizedColumns = cleanedColumns.map((column) => ({
    original: column,
    normalized: normalizeText(column)
  }));

  Object.entries(candidates).forEach(([field, synonyms]) => {
    let bestMatch = null;
    let bestScore = -Infinity;

    normalizedColumns.forEach((column) => {
      const score = scoreColumnMatch(column.normalized, field, synonyms);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = column.original;
      }
    });

    if (bestScore > 0) {
      mapping[field] = bestMatch;
    }
  });

  return mapping;
}

function logColumnMapping(mapping) {
  console.log('column mapping:');
  Object.entries(mapping).forEach(([field, column]) => {
    console.log(`  ${field} -> ${column}`);
  });
}

function scoreColumnMatch(normalizedColumn, field, synonyms) {
  const normalizedField = normalizeText(field);
  const fieldTokens = new Set(normalizedField.split(' '));

  if (normalizedColumn === normalizedField) {
    return 100;
  }

  for (const synonym of synonyms) {
    const normalizedSynonym = normalizeText(synonym);
    if (normalizedColumn === normalizedSynonym) {
      return 90;
    }
    if (normalizedColumn.includes(normalizedSynonym) || normalizedSynonym.includes(normalizedColumn)) {
      return 75;
    }
  }

  const columnTokens = new Set(normalizedColumn.split(' '));
  let overlap = 0;
  columnTokens.forEach((token) => {
    if (fieldTokens.has(token)) {
      overlap += 1;
    }
  });

  return overlap / Math.max(columnTokens.size, 1);
}

function normalizeText(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

function buildSupabaseClient() {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;

  if (!url || !key) {
    return null;
  }

  return createClient(url, key, {
    auth: { persistSession: false }
  });
}

async function ensureCity(client, name) {
  const slug = slugify(name);
  const { data, error } = await client
    .from('cities')
    .select('id')
    .eq('slug', slug)
    .maybeSingle();

  if (error && error.code !== 'PGRST116') {
    throw error;
  }

  if (data && data.id) {
    return data.id;
  }

  const { data: inserted, error: insertError } = await client
    .from('cities')
    .insert({ name, slug })
    .select('id')
    .single();

  if (insertError) {
    throw insertError;
  }

  return inserted.id;
}

async function checkSourceLicenseColumn(client) {
  const { error } = await client
    .from('sources')
    .select('license')
    .limit(1);

  if (!error) {
    return true;
  }

  const message = (error.message || '').toLowerCase();
  if (message.includes('column') && message.includes('license')) {
    console.warn('sources.license column is not available; license will not be saved.');
    return false;
  }

  throw error;
}

async function ensureSource(client, options) {
  const payload = { name: options.name, url: options.url };
  if (options.licenseSupported) {
    payload.license = options.license;
  }

  const selectColumns = options.licenseSupported ? 'id, url, license' : 'id, url';

  const { data, error } = await client
    .from('sources')
    .select(selectColumns)
    .eq('name', options.name)
    .maybeSingle();

  if (error && error.code !== 'PGRST116') {
    throw error;
  }

  if (data && data.id) {
    const needsUpdate = (options.licenseSupported && data.license !== options.license) || data.url !== options.url;

    if (needsUpdate) {
      const { data: updated, error: updateError } = await client
        .from('sources')
        .update(payload)
        .eq('id', data.id)
        .select('id')
        .single();

      if (updateError) {
        throw updateError;
      }

      return updated.id;
    }

    return data.id;
  }

  const { data: inserted, error: insertError } = await client
    .from('sources')
    .insert(payload)
    .select('id')
    .single();

  if (insertError) {
    throw insertError;
  }

  return inserted.id;
}

function buildRecordFromRow(row, mapping, cityName) {
  const record = {};
  Object.entries(mapping).forEach(([field, column]) => {
    record[field] = row[column];
  });

  record.name = (record.name || '').toString().trim();
  record.external_id = (record.external_id || '').toString().trim();
  record.latitude = parseLatitude(record.lat);
  record.longitude = parseLongitude(record.lon);
  record.operational_status = normalizeOperational(record.operational);
  record.pet_friendly = normalizePetFriendly(record.pet_friendly);
  record.season = record.season ? record.season.toString().trim() : null;
  record.neighbourhood = record.neighbourhood ? record.neighbourhood.toString().trim() : null;
  record.location_description = record.location_description ? record.location_description.toString().trim() : null;
  record.last_verified_at = normalizeDate(record.last_verified_at);
  record.city = cityName;

  return record;
}

function parseLatitude(value) {
  return parseCoordinate(value, -90, 90);
}

function parseLongitude(value) {
  return parseCoordinate(value, -180, 180);
}

function parseCoordinate(rawValue, min, max) {
  if (rawValue === undefined || rawValue === null) {
    return null;
  }

  if (typeof rawValue === 'number') {
    return isFinite(rawValue) && rawValue >= min && rawValue <= max ? rawValue : null;
  }

  const value = rawValue.toString().trim();
  if (value.length === 0) {
    return null;
  }

  const number = Number.parseFloat(value);
  if (Number.isFinite(number) && number >= min && number <= max) {
    return number;
  }

  const matches = value.match(/-?\d+\.\d+/g);
  if (matches && matches.length >= 2) {
    const [first, second] = matches.map((match) => Number.parseFloat(match));
    if (first >= min && first <= max) {
      return first;
    }
    if (second >= min && second <= max) {
      return second;
    }
  }

  return null;
}

function normalizeOperational(value) {
  if (!value) {
    return 'unknown';
  }

  const text = value.toString().toLowerCase();

  if (matchesAny(text, ['year', 'operational', 'open', 'yes', '24/7', 'always'])) {
    return 'operational';
  }

  if (matchesAny(text, ['season', 'spring', 'summer', 'fall', 'winter'])) {
    return 'seasonal';
  }

  return 'unknown';
}

function normalizePetFriendly(value) {
  if (!value) {
    return 'unknown';
  }

  const text = value.toString().toLowerCase();

  if (matchesAny(text, ['yes', 'y', 'true', 'pet friendly', 'pets allowed', 'dogs welcome'])) {
    return 'y';
  }

  if (matchesAny(text, ['no', 'n', 'false', 'pets not allowed', 'no pets'])) {
    return 'n';
  }

  return 'unknown';
}

function convertPetFriendlyForDatabase(value) {
  if (value === 'y') {
    return 'yes';
  }
  if (value === 'n') {
    return 'no';
  }
  return 'unknown';
}

function matchesAny(text, keywords) {
  return keywords.some((keyword) => text.includes(keyword));
}

function normalizeDate(value) {
  if (!value) {
    return null;
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return null;
  }

  return date.toISOString().split('T')[0];
}

function validateRecord(record) {
  const missing = REQUIRED_FIELDS.filter((field) => {
    if (field === 'lat') {
      return typeof record.latitude !== 'number';
    }
    if (field === 'lon') {
      return typeof record.longitude !== 'number';
    }
    return !record[field];
  });

  if (missing.length > 0) {
    return `missing required fields: ${missing.join(', ')}`;
  }

  return null;
}

async function upsertFountain(client, record) {
  const { data: existing, error: fetchError } = await client
    .from('fountains')
    .select('id, name, latitude, longitude, operational_status, pet_friendly, season_note, location_description, neighbourhood')
    .eq('external_id', record.external_id)
    .eq('source_id', record.source_id)
    .maybeSingle();

  if (fetchError && fetchError.code !== 'PGRST116') {
    throw fetchError;
  }

  if (!existing) {
    const { error: insertError } = await client
      .from('fountains')
      .insert(record);

    if (insertError) {
      throw insertError;
    }

    return { action: 'inserted' };
  }

  const hasChanges =
    existing.name !== record.name ||
    existing.latitude !== record.latitude ||
    existing.longitude !== record.longitude ||
    existing.operational_status !== record.operational_status ||
    existing.pet_friendly !== record.pet_friendly ||
    (existing.season_note || '') !== (record.season_note || '') ||
    (existing.location_description || '') !== (record.location_description || '') ||
    (existing.neighbourhood || '') !== (record.neighbourhood || '');

  if (!hasChanges) {
    return { action: 'skipped' };
  }

  const { error: updateError } = await client
    .from('fountains')
    .update(record)
    .eq('id', existing.id);

  if (updateError) {
    throw updateError;
  }

  return { action: 'updated' };
}

function printSummary(summary) {
  console.log('\nimport summary');
  console.table([
    { action: 'inserted', count: summary.inserted },
    { action: 'updated', count: summary.updated },
    { action: 'skipped', count: summary.skipped.length }
  ]);

  if (summary.skipped.length > 0) {
    console.log('\nskipped rows:');
    summary.skipped.forEach((item) => {
      console.log(`  row ${item.row}${item.externalId ? ` (external_id: ${item.externalId})` : ''}: ${item.reason}`);
    });
  }
}

function slugify(value) {
  return value
    .toString()
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-');
}

main().catch((error) => {
  console.error('fatal error while running import:', error);
  process.exit(1);
});
