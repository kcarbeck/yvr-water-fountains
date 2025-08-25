// Function to approve/reject ratings and trigger auto-deployment
const { createClient } = require('@supabase/supabase-js');
const { triggerAutoDeployment } = require('./trigger-deployment.js');

exports.handler = async (event, context) => {
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

        const { ratingId, action, adminPassword } = requestBody;
        
        // Validate required fields
        if (!ratingId || !action || !adminPassword) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({ error: 'Missing required fields: ratingId, action, adminPassword' })
            };
        }

        // Verify admin password
        if (!process.env.ADMIN_PASSWORD) {
            return {
                statusCode: 500,
                headers,
                body: JSON.stringify({ 
                    error: 'Admin functionality not configured',
                    message: 'ADMIN_PASSWORD environment variable not set'
                })
            };
        }

        const providedPassword = adminPassword.trim();
        const expectedPassword = process.env.ADMIN_PASSWORD.trim();
        
        if (providedPassword !== expectedPassword) {
            return {
                statusCode: 401,
                headers,
                body: JSON.stringify({ error: 'Invalid admin password' })
            };
        }

        // Initialize Supabase
        const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY);

        // Validate action
        if (!['approve', 'reject', 'pending'].includes(action)) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({ error: 'Invalid action. Must be: approve, reject, or pending' })
            };
        }

        // Update rating status
        const { data: updatedRating, error: updateError } = await supabase
            .from('ratings')
            .update({ 
                review_status: action === 'approve' ? 'approved' : action === 'reject' ? 'rejected' : 'pending',
                approved_by: action === 'approve' ? 'admin' : null,
                approved_at: action === 'approve' ? new Date().toISOString() : null
            })
            .eq('id', ratingId)
            .select()
            .single();

        if (updateError) {
            throw new Error(`Failed to update rating: ${updateError.message}`);
        }

        // Trigger auto-deployment for any status change that affects visibility
        let deploymentTriggered = false;
        if (['approve', 'reject'].includes(action)) {
            deploymentTriggered = await triggerAutoDeployment(`Rating ${action}d - syncing approved ratings`);
        }

        const message = deploymentTriggered 
            ? `Rating ${action}d successfully! Site regeneration has been triggered automatically.`
            : `Rating ${action}d successfully! Run \`python scripts/generate_geojson_api.py\` to sync changes.`;

        return {
            statusCode: 200,
            headers,
            body: JSON.stringify({
                success: true,
                message: message,
                ratingId: ratingId,
                newStatus: updatedRating.review_status,
                deploymentTriggered: deploymentTriggered
            })
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