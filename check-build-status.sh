#!/bin/bash
# Monitor GitHub Actions build status and notify when ready

REPO="nuniesmith/fks"
CHECK_INTERVAL=60  # seconds

echo "================================================"
echo "GitHub Actions Build Monitor"
echo "================================================"
echo ""
echo "Monitoring: https://github.com/$REPO/actions"
echo "Check interval: ${CHECK_INTERVAL}s"
echo ""

while true; do
    # Get latest workflow run
    RESPONSE=$(curl -s "https://api.github.com/repos/$REPO/actions/runs?per_page=1")
    
    STATUS=$(echo "$RESPONSE" | jq -r '.workflow_runs[0].status')
    CONCLUSION=$(echo "$RESPONSE" | jq -r '.workflow_runs[0].conclusion')
    CREATED=$(echo "$RESPONSE" | jq -r '.workflow_runs[0].created_at')
    UPDATED=$(echo "$RESPONSE" | jq -r '.workflow_runs[0].updated_at')
    HTML_URL=$(echo "$RESPONSE" | jq -r '.workflow_runs[0].html_url')
    NAME=$(echo "$RESPONSE" | jq -r '.workflow_runs[0].name')
    
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$TIMESTAMP] Workflow: $NAME"
    echo "  Status: $STATUS"
    echo "  Conclusion: ${CONCLUSION:-pending}"
    echo "  Created: $CREATED"
    echo "  Updated: $UPDATED"
    echo ""
    
    # Check if build is complete
    if [ "$STATUS" = "completed" ]; then
        echo "================================================"
        echo "✅ BUILD COMPLETE!"
        echo "================================================"
        echo ""
        echo "Conclusion: $CONCLUSION"
        echo "URL: $HTML_URL"
        echo ""
        
        if [ "$CONCLUSION" = "success" ]; then
            echo "🎉 Build succeeded! Ready to deploy."
            echo ""
            echo "Next step:"
            echo "./scripts/deploy-web-services.sh"
            echo ""
            
            # Check if image is available
            echo "Verifying image availability..."
            if docker pull nuniesmith/fks:web-latest 2>/dev/null; then
                echo "✅ Image nuniesmith/fks:web-latest is ready!"
                echo ""
                echo "You can now run:"
                echo "./scripts/deploy-web-services.sh"
            else
                echo "⏳ Image not yet available on DockerHub."
                echo "   It may take a few minutes to propagate."
                echo "   Retry in 2-3 minutes."
            fi
        else
            echo "❌ Build failed with conclusion: $CONCLUSION"
            echo ""
            echo "Check the logs at:"
            echo "$HTML_URL"
            echo ""
            echo "Common issues:"
            echo "- Test failures (expected - Phase 1 backlog)"
            echo "- Lint failures (expected - Phase 1 backlog)"
            echo "- Docker build errors (check syntax)"
        fi
        
        break
    fi
    
    # Calculate elapsed time
    CREATED_TS=$(date -d "$CREATED" +%s 2>/dev/null || echo 0)
    NOW_TS=$(date +%s)
    ELAPSED=$((NOW_TS - CREATED_TS))
    ELAPSED_MIN=$((ELAPSED / 60))
    
    echo "  Elapsed: ${ELAPSED_MIN} minutes"
    echo "  Estimated remaining: ~$((40 - ELAPSED_MIN)) minutes"
    echo ""
    echo "  Next check in ${CHECK_INTERVAL}s... (Ctrl+C to stop)"
    echo "================================================"
    echo ""
    
    sleep $CHECK_INTERVAL
done
