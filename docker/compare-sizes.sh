#!/bin/bash
# Compare Docker image sizes between original and optimized versions

echo "=========================================="
echo "Docker Image Size Comparison"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Function to get image size in bytes
get_image_size() {
    local image=$1
    docker image inspect "$image" --format '{{.Size}}' 2>/dev/null || echo "0"
}

# Function to format size
format_size() {
    local bytes=$1
    if [ "$bytes" = "0" ] || [ -z "$bytes" ]; then
        echo "N/A"
    else
        # Convert bytes to human readable
        numfmt --to=iec-i --suffix=B "$bytes" 2>/dev/null || echo "${bytes}B"
    fi
}

echo "Service          | Original    | Optimized   | Savings"
echo "-----------------|-------------|-------------|----------"

# Training service
TRAIN_ORIG=$(get_image_size "fks_training:latest" 2>/dev/null || echo "0")
TRAIN_OPT=$(get_image_size "fks_training:optimized" 2>/dev/null || echo "0")
if [ "$TRAIN_ORIG" != "0" ] && [ "$TRAIN_OPT" != "0" ]; then
    SAVINGS=$((TRAIN_ORIG - TRAIN_OPT))
    PERCENT=$((SAVINGS * 100 / TRAIN_ORIG))
    printf "Training         | %-11s | %-11s | %s%%\n" \
        "$(format_size $TRAIN_ORIG)" \
        "$(format_size $TRAIN_OPT)" \
        "$PERCENT"
else
    TRAIN_OPT_FMT=$(format_size $TRAIN_OPT)
    printf "Training         | N/A         | %-11s | -\n" "$TRAIN_OPT_FMT"
fi

# AI service
AI_ORIG=$(get_image_size "fks_ai:latest" 2>/dev/null || echo "0")
AI_OPT=$(get_image_size "fks_ai:optimized" 2>/dev/null || echo "0")
if [ "$AI_ORIG" != "0" ] && [ "$AI_OPT" != "0" ]; then
    SAVINGS=$((AI_ORIG - AI_OPT))
    PERCENT=$((SAVINGS * 100 / AI_ORIG))
    printf "AI              | %-11s | %-11s | %s%%\n" \
        "$(format_size $AI_ORIG)" \
        "$(format_size $AI_OPT)" \
        "$PERCENT"
else
    AI_OPT_FMT=$(format_size $AI_OPT)
    printf "AI              | N/A         | %-11s | -\n" "$AI_OPT_FMT"
fi

# Analyze service
ANALYZE_ORIG=$(get_image_size "fks_analyze:latest" 2>/dev/null || echo "0")
ANALYZE_OPT=$(get_image_size "fks_analyze:optimized" 2>/dev/null || echo "0")
if [ "$ANALYZE_ORIG" != "0" ] && [ "$ANALYZE_OPT" != "0" ]; then
    SAVINGS=$((ANALYZE_ORIG - ANALYZE_OPT))
    PERCENT=$((SAVINGS * 100 / ANALYZE_ORIG))
    printf "Analyze         | %-11s | %-11s | %s%%\n" \
        "$(format_size $ANALYZE_ORIG)" \
        "$(format_size $ANALYZE_OPT)" \
        "$PERCENT"
else
    ANALYZE_OPT_FMT=$(format_size $ANALYZE_OPT)
    printf "Analyze         | N/A         | %-11s | -\n" "$ANALYZE_OPT_FMT"
fi

echo ""
echo "=========================================="
echo "Current Optimized Image Sizes:"
echo "=========================================="
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep -E "(fks_|REPOSITORY)" | head -5

