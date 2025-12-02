#!/bin/bash
# Start Bitcoin Signal Demo Services
# Quick startup script for Bitcoin signal generation

set -e

echo "=== Starting Bitcoin Signal Demo ==="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker first."
    exit 1
fi

# Start services
start_service() {
    local name=$1
    local dir=$2
    echo -n "Starting $name... "
    
    cd "$dir" || exit 1
    if docker-compose up -d > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Started${NC}"
        cd - > /dev/null || exit 1
        return 0
    else
        echo -e "${YELLOW}⚠ Already running or error${NC}"
        cd - > /dev/null || exit 1
        return 1
    fi
}

# Wait for service to be ready
wait_for_service() {
    local name=$1
    local url=$2
    local max_attempts=30
    local attempt=0
    
    echo -n "Waiting for $name to be ready... "
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -f "$url/health" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Ready${NC}"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    echo -e "${YELLOW}⚠ Timeout${NC}"
    return 1
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Step 1: Starting Services"
echo "------------------------"
start_service "fks_data" "$REPO_DIR/data"
start_service "fks_app" "$REPO_DIR/app"
start_service "fks_web" "$REPO_DIR/web"
echo ""

echo "Step 2: Waiting for Services"
echo "---------------------------"
wait_for_service "fks_data" "http://localhost:8003"
wait_for_service "fks_app" "http://localhost:8002"
wait_for_service "fks_web" "http://localhost:8000"
echo ""

echo -e "${GREEN}=== Services Started! ===${NC}"
echo ""
echo "Services:"
echo "  - fks_data:  http://localhost:8003"
echo "  - fks_app:   http://localhost:8002"
echo "  - fks_web:   http://localhost:8000"
echo ""
echo "Next steps:"
echo "1. Test Bitcoin signal: curl \"http://localhost:8002/api/v1/signals/latest/BTCUSDT?category=swing\""
echo "2. Open dashboard: http://localhost:8000/portfolio/signals/?symbols=BTCUSDT&category=swing"
echo "3. Run test script: ./repo/main/scripts/test-bitcoin-signal.sh"
echo ""

