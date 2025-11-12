#!/bin/bash
# Wait for Docker images to be published and test local pulls

set -e

DOCKER_USERNAME="nuniesmith"
REPOS=("fks_api" "fks_app" "fks_data" "fks_execution" "fks_ai" "fks_ninja" "fks_web" "fks_training" "fks_auth")

echo "================================================"
echo "  Docker Image Pull Test - FKS Platform"
echo "================================================"
echo ""
echo "This script will attempt to pull all FKS Docker images"
echo "from DockerHub and verify they exist."
echo ""

SUCCESS_COUNT=0
FAILED_COUNT=0
FAILED_IMAGES=()

for repo in "${REPOS[@]}"; do
    IMAGE="$DOCKER_USERNAME/$repo:latest"
    echo "📦 Testing: $IMAGE"
    
    if docker pull "$IMAGE" 2>/dev/null; then
        echo "   ✅ Success: Image pulled"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        
        # Get image info
        SIZE=$(docker images "$IMAGE" --format "{{.Size}}")
        echo "   📊 Size: $SIZE"
    else
        echo "   ❌ Failed: Image not available yet"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_IMAGES+=("$IMAGE")
    fi
    echo ""
done

# Test fks_ai variants
echo "📦 Testing fks_ai variants..."
for variant in "cpu" "gpu" "arm64"; do
    IMAGE="$DOCKER_USERNAME/fks_ai:$variant"
    echo "   Testing: $IMAGE"
    
    if docker pull "$IMAGE" 2>/dev/null; then
        echo "   ✅ Success"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo "   ❌ Failed: Not available yet"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_IMAGES+=("$IMAGE")
    fi
done
echo ""

echo "================================================"
echo "  Summary"
echo "================================================"
echo "✅ Successful pulls: $SUCCESS_COUNT"
echo "❌ Failed pulls: $FAILED_COUNT"
echo ""

if [ $FAILED_COUNT -gt 0 ]; then
    echo "⏳ Images not yet available (builds may still be running):"
    for img in "${FAILED_IMAGES[@]}"; do
        echo "   - $img"
    done
    echo ""
    echo "💡 Wait a few minutes and run this script again:"
    echo "   $0"
    exit 1
else
    echo "🎉 All images successfully pulled!"
    echo ""
    echo "Next steps:"
    echo "1. Update K8s manifests to use DockerHub images"
    echo "2. Deploy to cluster"
    exit 0
fi
