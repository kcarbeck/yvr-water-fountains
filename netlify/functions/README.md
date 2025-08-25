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

### 3. ADMIN_PASSWORD (Required for Admin Reviews)
- Choose a secure password for admin review functionality
- Add this as `ADMIN_PASSWORD` in Netlify environment variables
- **IMPORTANT**: This must be set in Netlify dashboard, NOT in a .env file
- This is different from the frontend admin access password

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

### "Invalid admin password"
This means the admin password you entered doesn't match the `ADMIN_PASSWORD` environment variable set in Netlify.

### "Admin functionality is not configured on this server"
This means the `ADMIN_PASSWORD` environment variable is not set in Netlify.

## Two Admin Password Systems

There are TWO separate admin password systems:

1. **Frontend Admin Access** (for accessing admin panel from map):
   - Uses `APP_CONFIG.ADMIN_PASSWORD` in config.js (currently set to null for security)
   - This is for basic frontend access to admin forms

2. **Backend Admin Review Submission** (for actually submitting admin reviews):
   - Uses `ADMIN_PASSWORD` environment variable in Netlify
   - This is for secure server-side validation of admin review submissions
   - **This is what you need to set in Netlify dashboard**

## Testing

After setting up the environment variables:
1. Redeploy your site
2. Try submitting a review
3. Check the browser console for any remaining errors
4. Check Netlify function logs for server-side errors
