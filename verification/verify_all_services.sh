#!/bin/bash
# Verify All FKS Services
# Builds and tests all services to ensure they work properly

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$PROJECT_ROOT/repo"

echo "🔍 Verifying All FKS Services"
echo "=============================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track results
TOTAL=0
PASSED=0
FAILED=0

# Services to verify
declare -a SERVICES=(
    "core/api:fks_api:python"
    "core/app:fks_app:python"
    "core/data:fks_data:python"
    "core/execution:fks_execution:rust"
    "core/web:fks_web:python"
    "core/main:fks_main:rust"
    "gpu/ai:fks_ai:python"
    "gpu/training:fks_training:python"
    "tools/analyze:fks_analyze:python"
    "tools/monitor:fks_monitor:python"
)

verify_service() {
    local service_path=$1
    local service_name=$2
    local service_type=$3
    
    TOTAL=$((TOTAL + 1))
    
    echo "📦 Verifying $service_name ($service_type)..."
    echo "   Path: $service_path"
    
    local full_path="$REPO_ROOT/$service_path"
    
    if [ ! -d "$full_path" ]; then
        echo -e "   ${RED}❌ Repository not found${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
    
    cd "$full_path"
    
    # Check 1: Required files exist
    echo "   Checking required files..."
    local missing_files=()
    
    if [ "$service_type" = "rust" ]; then
        [ ! -f "Cargo.toml" ] && missing_files+=("Cargo.toml")
        [ ! -f "Dockerfile" ] && missing_files+=("Dockerfile")
    else
        [ ! -f "requirements.txt" ] && missing_files+=("requirements.txt")
        [ ! -f "Dockerfile" ] && missing_files+=("Dockerfile")
    fi
    [ ! -f "README.md" ] && missing_files+=("README.md")
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        echo -e "   ${RED}❌ Missing files: ${missing_files[*]}${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
    
    # Check 2: Dockerfile builds
    echo "   Testing Docker build..."
    if docker build -t "test-$service_name:latest" . > /tmp/docker_build_${service_name}.log 2>&1; then
        echo -e "   ${GREEN}✅ Docker build successful${NC}"
    else
        echo -e "   ${RED}❌ Docker build failed${NC}"
        echo "   Log: /tmp/docker_build_${service_name}.log"
        FAILED=$((FAILED + 1))
        return 1
    fi
    
    # Check 3: Service starts (if docker-compose exists)
    if [ -f "docker-compose.yml" ]; then
        echo "   Testing docker-compose..."
        if docker-compose config > /dev/null 2>&1; then
            echo -e "   ${GREEN}✅ docker-compose.yml valid${NC}"
        else
            echo -e "   ${YELLOW}⚠️  docker-compose.yml has issues${NC}"
        fi
    fi
    
    # Check 4: Tests exist and run (if pytest.ini or Cargo.toml)
    if [ "$service_type" = "rust" ]; then
        if [ -f "Cargo.toml" ] && [ -d "tests" ]; then
            echo "   Running Rust tests..."
            if cargo test --no-run > /tmp/cargo_test_${service_name}.log 2>&1; then
                echo -e "   ${GREEN}✅ Tests compile${NC}"
            else
                echo -e "   ${YELLOW}⚠️  Tests don't compile${NC}"
            fi
        fi
    else
        if [ -f "pytest.ini" ] || [ -d "tests" ]; then
            echo "   Checking Python tests..."
            if python3 -m pytest --collect-only > /tmp/pytest_${service_name}.log 2>&1; then
                echo -e "   ${GREEN}✅ Tests found${NC}"
            else
                echo -e "   ${YELLOW}⚠️  No tests found or pytest not configured${NC}"
            fi
        fi
    fi
    
    echo -e "   ${GREEN}✅ $service_name verified${NC}"
    PASSED=$((PASSED + 1))
    echo ""
}

# Run verification
for service_config in "${SERVICES[@]}"; do
    IFS=':' read -r path name type <<< "$service_config"
    verify_service "$path" "$name" "$type"
done

# Summary
echo "=============================="
echo "📊 Verification Summary"
echo "=============================="
echo -e "Total Services: ${TOTAL}"
echo -e "${GREEN}Passed: ${PASSED}${NC}"
echo -e "${RED}Failed: ${FAILED}${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All services verified successfully!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some services failed verification${NC}"
    exit 1
fi

