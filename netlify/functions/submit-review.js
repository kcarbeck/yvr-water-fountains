// Secure serverless function for form submissions
// Keeps database credentials on the server, not exposed to users

const { createClient } = require('@supabase/supabase-js');

exports.handler = async (event, context) => {
    console.log('Function called with method:', event.httpMethod);
    console.log('Function path:', event.path);
    console.log('Event body present:', !!event.body);
    
    // CORS headers for all responses
    const headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'POST, OPTIONS'
    };

    // Handle preflight OPTIONS request
    if (event.httpMethod === 'OPTIONS') {
        return {
            statusCode: 200,
            headers,
            body: ''
        };
    }

    // Only allow POST requests
    if (event.httpMethod !== 'POST') {
        return {
            statusCode: 405,
            headers,
            body: JSON.stringify({ error: 'Method not allowed' })
        };
    }

    try {
        // Check for required environment variables
        if (!process.env.SUPABASE_URL || !process.env.SUPABASE_KEY) {
            console.error('Missing required environment variables: SUPABASE_URL or SUPABASE_KEY');
            return {
                statusCode: 500,
                headers,
                body: JSON.stringify({ 
                    error: 'Server configuration error',
                    message: 'Required environment variables are not configured' 
                })
            };
        }

        // Parse request body
        let requestBody;
        try {
            requestBody = JSON.parse(event.body || '{}');
        } catch (parseError) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({ 
                    error: 'Invalid JSON in request body',
                    message: parseError.message 
                })
            };
        }

        const { reviewData, reviewType } = requestBody;
        
        // Validate required fields
        if (!reviewData || !reviewType) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({ error: 'Missing required fields' })
            };
        }

        // Initialize Supabase with server-side credentials (secure!)
        let supabase;
        try {
            supabase = createClient(
                process.env.SUPABASE_URL,
                process.env.SUPABASE_KEY // Service role key (server-side only)
            );
        } catch (supabaseError) {
            console.error('Failed to initialize Supabase client:', supabaseError);
            return {
                statusCode: 500,
                headers,
                body: JSON.stringify({ 
                    error: 'Database connection error',
                    message: 'Failed to connect to database service' 
                })
            };
        }

        let response;

        if (reviewType === 'public') {
            response = await handlePublicReview(supabase, reviewData);
        } else if (reviewType === 'admin') {
            response = await handleAdminReview(supabase, reviewData);
        } else {
            throw new Error('Invalid review type');
        }

        return {
            statusCode: 200,
            headers,
            body: JSON.stringify(response)
        };

    } catch (error) {
        console.error('Function error:', error);
        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({ 
                error: 'Internal server error',
                message: error.message 
            })
        };
    }
};

async function handlePublicReview(supabase, reviewData) {
    // Find fountain by original_mapid
    const { data: fountainData, error: fountainError } = await supabase
        .from('fountains')
        .select('id')
        .eq('original_mapid', reviewData.fountainId)
        .single();

    if (fountainError) {
        throw new Error(`Fountain not found: ${fountainError.message}`);
    }

    // Prepare public review data
    const ratingData = {
        fountain_id: fountainData.id,
        overall_rating: parseInt(reviewData.overallRating),
        water_quality: reviewData.waterQuality ? parseInt(reviewData.waterQuality) : null,
        flow_pressure: reviewData.flowPressure ? parseInt(reviewData.flowPressure) : null,
        temperature: reviewData.temperature ? parseInt(reviewData.temperature) : null,
        drainage: reviewData.cleanliness ? parseInt(reviewData.cleanliness) : null,
        accessibility: reviewData.accessibility ? parseInt(reviewData.accessibility) : null,
        notes: reviewData.additionalNotes || null,
        visited: true,
        visit_date: reviewData.visitDate,
        user_name: reviewData.reviewerName,
        reviewer_email: reviewData.reviewerEmail || null,
        
        // Public review settings (unified approach)
        review_type: 'public_submission',
        review_status: 'pending', // Requires admin approval
        ig_post_url: null, // No Instagram for public
        instagram_caption: null,
        is_verified: false
    };

    // Insert the rating
    const { data: insertedRating, error: insertError } = await supabase
        .from('ratings')
        .insert([ratingData])
        .select()
        .single();

    if (insertError) {
        throw new Error(`Failed to submit review: ${insertError.message}`);
    }

    return {
        success: true,
        message: 'Review submitted successfully! It will be reviewed before being published.',
        reviewId: insertedRating.id,
        status: 'pending'
    };
}

async function handleAdminReview(supabase, reviewData) {
    console.log('Admin review attempt - password provided:', !!reviewData.adminPassword);
    console.log('Admin password configured on server:', !!process.env.ADMIN_PASSWORD);
    
    // Check if admin password is configured
    if (!process.env.ADMIN_PASSWORD) {
        console.error('ADMIN_PASSWORD environment variable not set');
        throw new Error('Admin functionality is not configured on this server. Please set ADMIN_PASSWORD in Netlify environment variables.');
    }
    
    // Verify admin password
    if (!reviewData.adminPassword) {
        throw new Error('Admin password is required');
    }
    
    if (reviewData.adminPassword !== process.env.ADMIN_PASSWORD) {
        console.error('Admin password mismatch');
        throw new Error('Invalid admin password');
    }
    
    console.log('Admin password verified successfully');

    // Find fountain by original_mapid
    const { data: fountainData, error: fountainError } = await supabase
        .from('fountains')
        .select('id')
        .eq('original_mapid', reviewData.fountainId)
        .single();

    if (fountainError) {
        throw new Error(`Fountain not found: ${fountainError.message}`);
    }

    // Prepare admin review data with Instagram
    const ratingData = {
        fountain_id: fountainData.id,
        overall_rating: parseInt(reviewData.overallRating),
        water_quality: parseInt(reviewData.waterQuality),
        flow_pressure: parseInt(reviewData.flowPressure),
        temperature: parseInt(reviewData.temperature),
        drainage: parseInt(reviewData.drainage),
        accessibility: parseInt(reviewData.accessibility),
        notes: reviewData.notes || null,
        visited: true,
        visit_date: reviewData.visitDate,
        
        // Admin review settings (unified approach)
        user_name: 'yvrwaterfountains', // Key identifier
        review_type: 'admin_instagram',
        review_status: 'approved', // Admin reviews auto-approved
        
        // Instagram data stored directly in ratings table
        ig_post_url: reviewData.instagramUrl || null,
        instagram_caption: reviewData.instagramCaption || null,
        
        is_verified: true
    };

    // Insert the rating
    const { data: insertedRating, error: insertError } = await supabase
        .from('ratings')
        .insert([ratingData])
        .select()
        .single();

    if (insertError) {
        throw new Error(`Failed to submit admin review: ${insertError.message}`);
    }

    // Trigger site regeneration (optional)
    // You could add a webhook call here to regenerate your static files

    return {
        success: true,
        message: 'Admin review submitted successfully! It is now live on the website.',
        reviewId: insertedRating.id,
        status: 'approved'
    };
}
