#!/usr/bin/env python3
"""
Auto-deployment trigger script
This script can be called when reviews are approved to automatically trigger deployment
"""

import requests
import os
import logging
from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger(__name__)

def trigger_github_deployment():
    """Trigger a GitHub Actions workflow deployment"""
    github_token = os.getenv('GITHUB_TOKEN')
    github_repo = os.getenv('GITHUB_REPO', 'your-username/yvr-water-fountains')
    
    if not github_token:
        logger.warning("No GitHub token provided - cannot trigger auto-deployment")
        return False
    
    # Trigger workflow dispatch
    url = f"https://api.github.com/repos/{github_repo}/actions/workflows/deploy.yml/dispatches"
    headers = {
        'Authorization': f'token {github_token}',
        'Accept': 'application/vnd.github.v3+json'
    }
    data = {
        'ref': 'main',
        'inputs': {
            'reason': 'Review approved - auto-deployment triggered'
        }
    }
    
    try:
        response = requests.post(url, headers=headers, json=data)
        if response.status_code == 204:
            logger.info("✅ Successfully triggered GitHub deployment")
            return True
        else:
            logger.error(f"❌ Failed to trigger deployment: {response.status_code}")
            return False
    except Exception as e:
        logger.error(f"❌ Error triggering deployment: {e}")
        return False

def trigger_netlify_deployment():
    """Trigger a Netlify deployment via webhook"""
    netlify_hook = os.getenv('NETLIFY_BUILD_HOOK')
    
    if not netlify_hook:
        logger.warning("No Netlify build hook provided - cannot trigger auto-deployment")
        return False
    
    try:
        response = requests.post(netlify_hook)
        if response.status_code == 200:
            logger.info("✅ Successfully triggered Netlify deployment")
            return True
        else:
            logger.error(f"❌ Failed to trigger Netlify deployment: {response.status_code}")
            return False
    except Exception as e:
        logger.error(f"❌ Error triggering Netlify deployment: {e}")
        return False

def trigger_deployment():
    """Trigger deployment on the configured platform"""
    logger.info("🚀 Triggering auto-deployment...")
    
    # Try GitHub first, then Netlify
    github_success = trigger_github_deployment()
    netlify_success = trigger_netlify_deployment()
    
    if github_success or netlify_success:
        logger.info("✅ Auto-deployment triggered successfully")
        return True
    else:
        logger.warning("⚠️ No deployment platforms configured or available")
        return False

if __name__ == "__main__":
    trigger_deployment()
