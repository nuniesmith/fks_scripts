#!/bin/bash
# Check GitHub Actions status for all FKS repositories

set -e

GITHUB_ORG="nuniesmith"
REPOS=("fks_api" "fks_app" "fks_data" "fks_execution" "fks_ai" "fks_ninja" "fks_web" "fks_training" "fks_auth")

echo "================================================"
echo "  GitHub Actions Status Check - FKS Platform"
echo "================================================"
echo ""

# Check if gh CLI is installed
if command -v gh &> /dev/null; then
    echo "✅ GitHub CLI detected - fetching live status..."
    echo ""
    
    for repo in "${REPOS[@]}"; do
        echo "📦 Repository: $repo"
        echo "   URL: https://github.com/$GITHUB_ORG/$repo/actions"
        
        # Try to get workflow run status
        if gh run list --repo "$GITHUB_ORG/$repo" --limit 1 --json conclusion,status,name,headBranch 2>/dev/null | grep -q "conclusion"; then
            gh run list --repo "$GITHUB_ORG/$repo" --limit 1 --json conclusion,status,name,headBranch,createdAt | \
                jq -r '.[] | "   Status: \(.status) | Conclusion: \(.conclusion // "pending") | Branch: \(.headBranch) | Created: \(.createdAt)"'
        else
            echo "   Status: ⏳ Workflow queued or starting..."
        fi
        echo ""
    done
else
    echo "ℹ️  GitHub CLI not found - showing URLs for manual checking"
    echo ""
    
    for repo in "${REPOS[@]}"; do
        echo "📦 $repo: https://github.com/$GITHUB_ORG/$repo/actions"
    done
    
    echo ""
    echo "Install GitHub CLI for live status: sudo apt install gh"
fi

echo ""
echo "================================================"
echo "  DockerHub Images Check"
echo "================================================"
echo ""
echo "Visit: https://hub.docker.com/u/$GITHUB_ORG"
echo ""
echo "Expected images:"
for repo in "${REPOS[@]}"; do
    echo "  - $GITHUB_ORG/$repo:latest"
done

echo ""
echo "Special variants:"
echo "  - $GITHUB_ORG/fks_ai:cpu"
echo "  - $GITHUB_ORG/fks_ai:gpu"
echo "  - $GITHUB_ORG/fks_ai:arm64"

echo ""
echo "================================================"
echo "  Quick Commands"
echo "================================================"
echo ""
echo "# Open GitHub Actions in browser:"
echo "xdg-open https://github.com/$GITHUB_ORG/fks_api/actions"
echo ""
echo "# Check latest workflow run (requires gh CLI):"
echo "gh run list --repo $GITHUB_ORG/fks_api --limit 1"
echo ""
echo "# Watch workflow run:"
echo "gh run watch --repo $GITHUB_ORG/fks_api"
echo ""
echo "# Pull Docker image:"
echo "docker pull $GITHUB_ORG/fks_api:latest"
