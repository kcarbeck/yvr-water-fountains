#!/usr/bin/env python3
"""
Pre-deployment validation script
Checks for common issues before deploying to production
"""

import os
import json
import sys
from pathlib import Path

def validate_gitignore():
    """Check that sensitive files are properly ignored"""
    print("🔍 Validating .gitignore...")
    
    gitignore_path = Path('.gitignore')
    if not gitignore_path.exists():
        print("❌ .gitignore file not found")
        return False
    
    gitignore_content = gitignore_path.read_text()
    
    required_patterns = ['.env', 'node_modules/', '*.log', '.DS_Store']
    missing_patterns = []
    
    for pattern in required_patterns:
        if pattern not in gitignore_content:
            missing_patterns.append(pattern)
    
    if missing_patterns:
        print(f"❌ Missing patterns in .gitignore: {missing_patterns}")
        return False
    
    print("✅ .gitignore looks good")
    return True

def validate_env_example():
    """Check that env.example exists and has required fields"""
    print("🔍 Validating env.example...")
    
    env_example_path = Path('env.example')
    if not env_example_path.exists():
        print("❌ env.example file not found")
        return False
    
    env_content = env_example_path.read_text()
    required_vars = ['SUPABASE_URL', 'SUPABASE_KEY', 'ADMIN_PASSWORD']
    
    missing_vars = []
    for var in required_vars:
        if var not in env_content:
            missing_vars.append(var)
    
    if missing_vars:
        print(f"❌ Missing variables in env.example: {missing_vars}")
        return False
    
    print("✅ env.example has all required variables")
    return True

def validate_netlify_function():
    """Check that Netlify function exists and has proper structure"""
    print("🔍 Validating Netlify function...")
    
    function_path = Path('netlify/functions/submit-review.js')
    if not function_path.exists():
        print("❌ Netlify function not found")
        return False
    
    function_content = function_path.read_text()
    
    required_elements = [
        'exports.handler',
        'process.env.SUPABASE_URL',
        'process.env.SUPABASE_KEY',
        'process.env.ADMIN_PASSWORD',
        'handlePublicReview',
        'handleAdminReview'
    ]
    
    missing_elements = []
    for element in required_elements:
        if element not in function_content:
            missing_elements.append(element)
    
    if missing_elements:
        print(f"❌ Missing elements in Netlify function: {missing_elements}")
        return False
    
    print("✅ Netlify function structure looks good")
    return True

def validate_config_js():
    """Check that config.js doesn't expose credentials"""
    print("🔍 Validating config.js security...")
    
    config_path = Path('docs/config.js')
    if not config_path.exists():
        print("❌ config.js not found")
        return False
    
    config_content = config_path.read_text()
    
    # Check for dangerous patterns
    dangerous_patterns = [
        'your-project.supabase.co',  # Should not have real URL
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9',  # JWT token pattern
        'ENABLE_SUPABASE: true'  # Should use API endpoints now
    ]
    
    security_issues = []
    for pattern in dangerous_patterns:
        if pattern in config_content:
            security_issues.append(pattern)
    
    # Check for secure patterns
    secure_patterns = [
        'API_ENDPOINT',
        'ENABLE_API_SUBMISSION: true'
    ]
    
    missing_secure = []
    for pattern in secure_patterns:
        if pattern not in config_content:
            missing_secure.append(pattern)
    
    if security_issues:
        print(f"❌ Security issues in config.js: {security_issues}")
        return False
    
    if missing_secure:
        print(f"❌ Missing secure configurations: {missing_secure}")
        return False
    
    print("✅ config.js is secure")
    return True

def validate_forms():
    """Check that forms use secure API endpoints"""
    print("🔍 Validating form security...")
    
    forms = ['docs/public_review_form.html', 'docs/admin_review_form.html']
    
    for form_path in forms:
        if not Path(form_path).exists():
            print(f"❌ Form not found: {form_path}")
            return False
        
        form_content = Path(form_path).read_text()
        
        # Check for security issues
        if 'SUPABASE_ANON_KEY' in form_content:
            print(f"❌ {form_path} still contains direct Supabase credentials")
            return False
        
        if 'submitToAPI' not in form_content:
            print(f"❌ {form_path} doesn't use secure API submission")
            return False
    
    print("✅ Forms use secure API endpoints")
    return True

def validate_package_json():
    """Check that package.json has required dependencies"""
    print("🔍 Validating package.json...")
    
    package_path = Path('package.json')
    if not package_path.exists():
        print("❌ package.json not found")
        return False
    
    try:
        package_data = json.loads(package_path.read_text())
        
        required_deps = ['@supabase/supabase-js']
        deps = package_data.get('dependencies', {})
        
        missing_deps = []
        for dep in required_deps:
            if dep not in deps:
                missing_deps.append(dep)
        
        if missing_deps:
            print(f"❌ Missing dependencies: {missing_deps}")
            return False
        
        print("✅ package.json has required dependencies")
        return True
        
    except json.JSONDecodeError:
        print("❌ package.json is not valid JSON")
        return False

def validate_netlify_toml():
    """Check Netlify configuration"""
    print("🔍 Validating netlify.toml...")
    
    toml_path = Path('netlify.toml')
    if not toml_path.exists():
        print("❌ netlify.toml not found")
        return False
    
    toml_content = toml_path.read_text()
    
    required_elements = [
        'functions = "netlify/functions"',
        'from = "/api/*"',
        'to = "/.netlify/functions/:splat"'
    ]
    
    missing_elements = []
    for element in required_elements:
        if element not in toml_content:
            missing_elements.append(element)
    
    if missing_elements:
        print(f"❌ Missing Netlify configuration: {missing_elements}")
        return False
    
    print("✅ netlify.toml is properly configured")
    return True

def main():
    """Run all validation checks"""
    print("🚀 YVR Water Fountains - Pre-Deployment Validation")
    print("=" * 60)
    
    checks = [
        validate_gitignore,
        validate_env_example,
        validate_netlify_function,
        validate_config_js,
        validate_forms,
        validate_package_json,
        validate_netlify_toml
    ]
    
    results = []
    for check in checks:
        try:
            result = check()
            results.append(result)
        except Exception as e:
            print(f"❌ Check failed with error: {e}")
            results.append(False)
        print()
    
    print("=" * 60)
    print("📊 VALIDATION SUMMARY")
    print("=" * 60)
    
    passed = sum(results)
    total = len(results)
    
    if passed == total:
        print(f"✅ ALL CHECKS PASSED ({passed}/{total})")
        print("🎉 Ready for deployment!")
        sys.exit(0)
    else:
        print(f"❌ {total - passed} checks failed ({passed}/{total} passed)")
        print("🔧 Please fix the issues above before deploying")
        sys.exit(1)

if __name__ == "__main__":
    main()
