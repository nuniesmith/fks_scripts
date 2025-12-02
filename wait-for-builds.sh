#!/bin/bash
# Wait for GitHub Actions builds to complete and verify images

set -e

DOCKER_USERNAME="nuniesmith"
REPOS=("fks_api" "fks_app" "fks_data" "fks_execution" "fks_ai" "fks_ninja" "fks_web" "fks_training" "fks_auth")
MAX_WAIT_MINUTES=15
CHECK_INTERVAL_SECONDS=30

echo "================================================"
echo "  GitHub Actions Build Monitor"
echo "================================================"
echo ""
echo "This script will:"
echo "  1. Wait for GitHub Actions builds to complete"
echo "  2. Verify Docker images are available"
echo "  3. Pull and test all images"
echo ""
echo "Max wait time: $MAX_WAIT_MINUTES minutes"
echo "Check interval: $CHECK_INTERVAL_SECONDS seconds"
echo ""

START_TIME=$(date +%s)

# Function to check if image exists on DockerHub
check_image() {
    local image=$1
    if docker manifest inspect "$image" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Wait for images to be available
echo "⏳ Waiting for Docker images to be published..."
echo ""

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    ELAPSED_MIN=$((ELAPSED / 60))
    
    if [ $ELAPSED_MIN -ge $MAX_WAIT_MINUTES ]; then
        echo ""
        echo "⏱️  Timeout: $MAX_WAIT_MINUTES minutes elapsed"
        echo ""
        echo "Some images may still be building. Check manually:"
        echo "  - GitHub Actions: https://github.com/nuniesmith/fks_api/actions"
        echo "  - DockerHub: https://hub.docker.com/u/nuniesmith"
        exit 1
    fi
    
    # Check all images
    AVAILABLE_COUNT=0
    TOTAL_COUNT=${#REPOS[@]}
    
    echo -ne "\r[${ELAPSED_MIN}m ${ELAPSED}s] Checking images... "
    
    for repo in "${REPOS[@]}"; do
        if check_image "$DOCKER_USERNAME/$repo:latest"; then
            AVAILABLE_COUNT=$((AVAILABLE_COUNT + 1))
        fi
    done
    
    echo -ne "$AVAILABLE_COUNT/$TOTAL_COUNT available"
    
    if [ $AVAILABLE_COUNT -eq $TOTAL_COUNT ]; then
        echo ""
        echo ""
        echo "✅ All images are now available!"
        break
    fi
    
    sleep $CHECK_INTERVAL_SECONDS
done

echo ""
echo "================================================"
echo "  Pulling Docker Images"
echo "================================================"
echo ""

SUCCESS_COUNT=0
FAILED_COUNT=0

for repo in "${REPOS[@]}"; do
    IMAGE="$DOCKER_USERNAME/$repo:latest"
    echo "📦 Pulling: $IMAGE"
    
    if docker pull "$IMAGE"; then
        SIZE=$(docker images "$IMAGE" --format "{{.Size}}")
        echo "   ✅ Success - Size: $SIZE"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo "   ❌ Failed"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
    echo ""
done

# Check fks_ai variants
echo "📦 Checking fks_ai variants..."
for variant in "cpu" "gpu" "arm64"; do
    IMAGE="$DOCKER_USERNAME/fks_ai:$variant"
    echo "   Pulling: $IMAGE"
    
    if docker pull "$IMAGE" 2>/dev/null; then
        echo "   ✅ Success"
    else
        echo "   ⚠️  Not available (may still be building)"
    fi
done

echo ""
echo "================================================"
echo "  Summary"
echo "================================================"
echo ""
echo "✅ Successfully pulled: $SUCCESS_COUNT/$TOTAL_COUNT images"
if [ $FAILED_COUNT -gt 0 ]; then
    echo "❌ Failed: $FAILED_COUNT"
fi
echo ""

if [ $SUCCESS_COUNT -eq $TOTAL_COUNT ]; then
    echo "🎉 All Docker images ready!"
    echo ""
    echo "Next steps:"
    echo "  1. Update K8s manifests:"
    echo "     ./scripts/update-k8s-images.sh"
    echo ""
    echo "  2. Apply to cluster:"
    echo "     kubectl apply -f k8s/manifests/all-services.yaml"
    echo ""
    echo "  3. Watch rollout:"
    echo "     kubectl rollout status deployment --all -n fks-trading"
    echo ""
    exit 0
else
    echo "⚠️  Some images failed to pull"
    echo "Check GitHub Actions for build status"
    exit 1
fi
