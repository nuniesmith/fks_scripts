#!/bin/bash
# Quick one-shot check if ready to deploy

echo "🔍 Checking if deployment is ready..."
echo ""

# Check if image exists
echo "1. Checking DockerHub for nuniesmith/fks:web-latest..."
if docker pull nuniesmith/fks:web-latest 2>&1 | grep -q "Status: Downloaded newer image\|Status: Image is up to date"; then
    echo "   ✅ Image is ready!"
    echo ""
    echo "2. Checking GitHub Actions status..."
    
    STATUS=$(curl -s "https://api.github.com/repos/nuniesmith/fks/actions/runs?per_page=1" | jq -r '.workflow_runs[0].status')
    CONCLUSION=$(curl -s "https://api.github.com/repos/nuniesmith/fks/actions/runs?per_page=1" | jq -r '.workflow_runs[0].conclusion')
    
    echo "   Status: $STATUS"
    echo "   Conclusion: ${CONCLUSION:-pending}"
    echo ""
    
    if [ "$STATUS" = "completed" ] && [ "$CONCLUSION" = "success" ]; then
        echo "================================================"
        echo "✅ READY TO DEPLOY!"
        echo "================================================"
        echo ""
        echo "Run this command to deploy:"
        echo "./scripts/deploy-web-services.sh"
        echo ""
        exit 0
    else
        echo "⚠️  GitHub Actions not yet complete or failed."
        echo "   You can still try to deploy if the image pulled successfully."
        echo ""
        echo "Deploy anyway?"
        echo "./scripts/deploy-web-services.sh"
        echo ""
        exit 1
    fi
else
    echo "   ❌ Image not yet available"
    echo ""
    echo "2. Checking GitHub Actions status..."
    
    STATUS=$(curl -s "https://api.github.com/repos/nuniesmith/fks/actions/runs?per_page=1" | jq -r '.workflow_runs[0].status')
    CREATED=$(curl -s "https://api.github.com/repos/nuniesmith/fks/actions/runs?per_page=1" | jq -r '.workflow_runs[0].created_at')
    HTML_URL=$(curl -s "https://api.github.com/repos/nuniesmith/fks/actions/runs?per_page=1" | jq -r '.workflow_runs[0].html_url')
    
    echo "   Status: $STATUS"
    echo "   Build URL: $HTML_URL"
    echo ""
    
    if [ "$STATUS" = "in_progress" ] || [ "$STATUS" = "queued" ]; then
        CREATED_TS=$(date -d "$CREATED" +%s 2>/dev/null || echo 0)
        NOW_TS=$(date +%s)
        ELAPSED=$((NOW_TS - CREATED_TS))
        ELAPSED_MIN=$((ELAPSED / 60))
        
        echo "⏳ Build still in progress..."
        echo "   Elapsed: ${ELAPSED_MIN} minutes"
        echo "   Estimated remaining: ~$((40 - ELAPSED_MIN)) minutes"
        echo ""
        echo "Run this to monitor continuously:"
        echo "./scripts/check-build-status.sh"
    else
        echo "❌ Build may have failed."
        echo "   Check: $HTML_URL"
    fi
    echo ""
    exit 2
fi
