// Reusable function to trigger deployment
// Can be called by any function when ratings are approved/unapproved

async function triggerAutoDeployment(reason = 'Rating status changed') {
    try {
        // Check for Netlify build hook in environment variables
        const netlifyBuildHook = process.env.NETLIFY_BUILD_HOOK;
        
        if (netlifyBuildHook) {
            console.log(`🚀 Triggering automatic deployment: ${reason}`);
            
            const response = await fetch(netlifyBuildHook, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    trigger_title: reason
                })
            });
            
            if (response.ok) {
                console.log('✅ Successfully triggered automatic deployment');
                return true;
            } else {
                console.error('❌ Failed to trigger deployment:', response.status);
                return false;
            }
        } else {
            console.log('ℹ️ No NETLIFY_BUILD_HOOK configured - skipping auto-deployment');
            return false;
        }
    } catch (error) {
        console.error('❌ Error triggering auto-deployment:', error);
        return false;
    }
}

module.exports = { triggerAutoDeployment };