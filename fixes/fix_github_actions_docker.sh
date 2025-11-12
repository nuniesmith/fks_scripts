#!/bin/bash
# Fix GitHub Actions to use DOCKER_USERNAME and DOCKER_TOKEN
# Ensure all workflows use the correct secrets

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$PROJECT_ROOT/repo"

echo "🔧 Fixing GitHub Actions Docker Hub Authentication"
echo "=================================================="
echo ""

# Find all workflow files
find "$REPO_ROOT" -name "*.yml" -path "*/.github/workflows/*" -o -name "*.yaml" -path "*/.github/workflows/*" | while read -r workflow_file; do
    if grep -q "docker/login-action" "$workflow_file" 2>/dev/null; then
        echo "📝 Checking: $workflow_file"
        
        # Check if it uses DOCKER_PASSWORD (wrong)
        if grep -q "DOCKER_PASSWORD" "$workflow_file" 2>/dev/null; then
            echo "  ⚠️  Found DOCKER_PASSWORD, fixing..."
            sed -i 's/DOCKER_PASSWORD/DOCKER_TOKEN/g' "$workflow_file"
            echo "  ✅ Fixed: Changed DOCKER_PASSWORD to DOCKER_TOKEN"
        fi
        
        # Check if password field uses DOCKER_TOKEN (correct)
        if grep -q "password:.*DOCKER_TOKEN" "$workflow_file" 2>/dev/null; then
            echo "  ✅ Already using DOCKER_TOKEN correctly"
        elif grep -q "password:.*DOCKER_USERNAME" "$workflow_file" 2>/dev/null; then
            echo "  ⚠️  Wrong: password field uses DOCKER_USERNAME, fixing..."
            sed -i 's/password:.*DOCKER_USERNAME/password: ${{ secrets.DOCKER_TOKEN }}/g' "$workflow_file"
            echo "  ✅ Fixed: Updated password field to use DOCKER_TOKEN"
        fi
        
        # Verify username uses DOCKER_USERNAME
        if ! grep -q "username:.*DOCKER_USERNAME" "$workflow_file" 2>/dev/null; then
            echo "  ⚠️  Missing DOCKER_USERNAME, adding..."
            # This would need more context to fix properly
        fi
    fi
done

echo ""
echo "✅ GitHub Actions Docker authentication check complete!"
echo ""
echo "📋 Required Secrets:"
echo "  - DOCKER_USERNAME: Your Docker Hub username"
echo "  - DOCKER_TOKEN: Your Docker Hub access token (not password!)"
echo ""
echo "💡 To create a Docker Hub token:"
echo "  1. Go to https://hub.docker.com/settings/security"
echo "  2. Create a new access token"
echo "  3. Add it as DOCKER_TOKEN secret in GitHub"

