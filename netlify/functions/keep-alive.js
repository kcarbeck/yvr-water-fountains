'use strict';

// Daily database check, run by Netlify on the schedule in netlify.toml.
//
// The free Supabase plan pauses a project after a week without activity,
// so each run makes a few small reads. If a read fails, it emails an alert.
// On Mondays it also sends a short "all good" email, so a missing Monday
// email means this function has stopped running.

const { createClient } = require('@supabase/supabase-js');
const { Resend } = require('resend');

// Netlify stops scheduled functions after 30 seconds
const TIMEOUT_MS = 8000;
const SENDER = 'YVR Water Fountains <onboarding@resend.dev>';

exports.handler = async function () {
  // Without this key there is no way to send an alert
  if (!process.env.RESEND_API_KEY) {
    console.error('keep-alive: RESEND_API_KEY is not set');
    return { statusCode: 500, body: 'RESEND_API_KEY is not set' };
  }

  const adminEmail = process.env.ADMIN_EMAIL || 'yvrwaterfountains@gmail.com';
  const siteUrl = process.env.URL || 'https://yvr-water-fountains.netlify.app';
  const resend = new Resend(process.env.RESEND_API_KEY);

  let counts;
  try {
    // throws if SUPABASE_URL or the key is missing, which also triggers the alert
    const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
    const [fountains, reviews, mapRows] = await Promise.all([
      countRows(supabase, 'fountains'),
      countRows(supabase, 'reviews', true),
      countRows(supabase, 'fountain_overview_view')
    ]);
    if (fountains === 0 || mapRows === 0) throw new Error('fountains came back empty');
    counts = { fountains, reviews, mapRows };
  } catch (error) {
    console.error('keep-alive: check failed:', error.message);
    await sendEmail(resend, adminEmail, 'YVR Water Fountains: database check failed', [
      'The daily database check failed.',
      '',
      'Error: ' + error.message,
      '',
      'If the free Supabase project has paused, open the Supabase dashboard and choose "Resume project".',
      'Until then the map falls back to the saved file and cannot show new reviews.',
      '',
      'Details: Netlify dashboard > Logs > Functions > keep-alive.'
    ].join('\n'));
    return { statusCode: 500, body: 'Check failed: ' + error.message };
  }

  console.log('keep-alive: ok', JSON.stringify(counts));

  // Monday email: its absence means this function is not running
  if (new Date().getUTCDay() === 1) {
    await sendEmail(resend, adminEmail, 'YVR Water Fountains: weekly check OK', [
      'The database answered today\'s check.',
      '',
      'Fountains: ' + counts.fountains,
      'Approved reviews: ' + counts.reviews,
      '',
      'Map: ' + siteUrl + '/map',
      '',
      'This email comes every Monday. If one is missing, the daily check has stopped running.'
    ].join('\n'));
  }

  return { statusCode: 200, body: JSON.stringify(counts) };
};

// ---- helpers ----

// Count the rows in a table or view (approved reviews only if asked)
async function countRows(supabase, table, approvedOnly) {
  let query = supabase.from(table).select('id', { count: 'exact', head: true });
  if (approvedOnly) query = query.eq('status', 'approved');
  const { count, error, status } = await query.abortSignal(AbortSignal.timeout(TIMEOUT_MS));
  if (error) throw new Error((table + ': HTTP ' + status + ' ' + error.message).trim());
  if (typeof count !== 'number') throw new Error(table + ': no row count in the response');
  return count;
}

async function sendEmail(resend, to, subject, text) {
  const { error } = await resend.emails.send({ from: SENDER, to: [to], subject, text });
  if (error) {
    console.error('keep-alive: email not sent:', error.message);
    throw new Error('email not sent: ' + error.message);
  }
  console.log('keep-alive: email sent to', to);
}
