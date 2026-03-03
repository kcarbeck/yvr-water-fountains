'use strict';

const { createClient } = require('@supabase/supabase-js');
const { Resend } = require('resend');

// Netlify Scheduled Function — runs weekly (configured in netlify.toml)
exports.handler = async function () {
  console.log('weekly-reminder: starting');

  const missing = [];
  if (!process.env.SUPABASE_URL) missing.push('SUPABASE_URL');
  if (!process.env.SUPABASE_SERVICE_ROLE_KEY) missing.push('SUPABASE_SERVICE_ROLE_KEY');
  if (!process.env.RESEND_API_KEY) missing.push('RESEND_API_KEY');

  if (missing.length > 0) {
    console.error('weekly-reminder: missing env vars:', missing.join(', '));
    return { statusCode: 500, body: JSON.stringify({ error: 'Missing env vars: ' + missing.join(', ') }) };
  }

  const adminEmail = process.env.ADMIN_EMAIL || 'yvrwaterfountains@gmail.com';

  try {
    const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

    // Get counts for the email
    const [fountainResult, reviewedResult, recentResult] = await Promise.all([
      supabase.from('fountains').select('id', { count: 'exact', head: true }),
      supabase.from('reviews').select('id', { count: 'exact', head: true }).eq('status', 'approved'),
      supabase.from('reviews').select('id', { count: 'exact', head: true }).eq('status', 'approved').gte('created_at', sevenDaysAgo())
    ]);

    const totalFountains = fountainResult.count || 0;
    const totalReviews = reviewedResult.count || 0;
    const recentReviews = recentResult.count || 0;

    const siteUrl = process.env.URL || 'https://yvr-water-fountains.netlify.app';

    const resend = new Resend(process.env.RESEND_API_KEY);

    await resend.emails.send({
      from: 'YVR Water Fountains <onboarding@resend.dev>',
      to: [adminEmail],
      subject: 'Weekly reminder — any new fountain reviews?',
      html: buildEmailHtml(totalFountains, totalReviews, recentReviews, siteUrl)
    });

    console.log('weekly-reminder: email sent to', adminEmail);
    return { statusCode: 200, body: JSON.stringify({ message: 'Reminder sent' }) };

  } catch (error) {
    console.error('weekly-reminder: error', error);
    return { statusCode: 500, body: JSON.stringify({ error: error.message }) };
  }
};

function sevenDaysAgo() {
  const date = new Date();
  date.setDate(date.getDate() - 7);
  return date.toISOString();
}

function buildEmailHtml(totalFountains, totalReviews, recentReviews, siteUrl) {
  return '<div style="font-family: -apple-system, BlinkMacSystemFont, \'Segoe UI\', sans-serif; max-width: 500px; margin: 0 auto;">' +
    '<h2 style="color: #198754;">Weekly Fountain Check-In</h2>' +
    '<p>Have you or your friend posted any new <strong>@yvrwaterfountains</strong> reels this week?</p>' +
    '<p>If so, add them to the map — it only takes 30 seconds:</p>' +
    '<div style="margin: 20px 0;">' +
      '<a href="' + siteUrl + '/admin_review_form.html" style="display: inline-block; background: #198754; color: white; padding: 12px 24px; border-radius: 6px; text-decoration: none; font-weight: 600;">Open Admin Form</a>' +
    '</div>' +
    '<p style="font-size: 14px; color: #6c757d;">Paste the IG URL + caption, and the form auto-fills the rating and fountain match. One click to publish.</p>' +
    '<hr style="border: none; border-top: 1px solid #e9ecef; margin: 24px 0;">' +
    '<div style="font-size: 14px; color: #6c757d;">' +
      '<p style="margin: 4px 0;"><strong>' + totalReviews + '</strong> reviews on the map</p>' +
      '<p style="margin: 4px 0;"><strong>' + totalFountains + '</strong> fountains tracked</p>' +
      '<p style="margin: 4px 0;"><strong>' + recentReviews + '</strong> reviews added this week</p>' +
    '</div>' +
    '<p style="color: #adb5bd; font-size: 12px; margin-top: 20px;">' +
      '<a href="' + siteUrl + '/map.html" style="color: #adb5bd;">View the map</a>' +
    '</p>' +
  '</div>';
}
