# Netlify Functions Setup

## Required Environment Variables

To fix the JSON parsing error when submitting reviews, you need to configure the following environment variables in your Netlify dashboard:

### 1. SUPABASE_URL
- Go to your Supabase project dashboard
- Navigate to Settings → API
- Copy the "Project URL"
- Add this as `SUPABASE_URL` in Netlify

### 2. SUPABASE_KEY
- In the same Supabase API settings page
- Copy the "service_role" key (NOT the anon key)
- Add this as `SUPABASE_KEY` in Netlify

### 3. ADMIN_PASSWORD (Optional)
- Choose a secure password for admin functionality
- Add this as `ADMIN_PASSWORD` in Netlify

## How to Set Environment Variables in Netlify

1. Go to your Netlify dashboard
2. Select your site
3. Go to Site settings → Environment variables
4. Click "Add a variable"
5. Add each variable name and value
6. Save and redeploy your site

## Common Issues

### "JSON.parse: unexpected character at line 1 column 1"
This error typically occurs when:
- Required environment variables are missing
- The function returns HTML error page instead of JSON
- Dependencies are not properly installed

### "Server configuration error"
This means the SUPABASE_URL or SUPABASE_KEY environment variables are not set.

### "Database connection error"
This indicates an issue with the Supabase client initialization.

## Testing

After setting up the environment variables:
1. Redeploy your site
2. Try submitting a review
3. Check the browser console for any remaining errors
4. Check Netlify function logs for server-side errors
