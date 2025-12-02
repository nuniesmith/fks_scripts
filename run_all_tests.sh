#!/bin/bash
# Comprehensive test runner for FKS platform
# Runs all available test scripts in sequence

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== FKS Platform Test Suite ===${NC}"
echo ""

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_script="$2"
    local required="$3"  # "required" or "optional"
    
    echo -e "${BLUE}Running: $test_name${NC}"
    
    if [ ! -f "$test_script" ]; then
        echo -e "${YELLOW}⚠️  Test script not found: $test_script${NC}"
        ((TESTS_SKIPPED++))
        return 1
    fi
    
    if [ ! -x "$test_script" ]; then
        chmod +x "$test_script"
    fi
    
    if bash "$test_script" 2>&1; then
        echo -e "${GREEN}✅ $test_name: PASSED${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}❌ $test_name: FAILED${NC}"
        ((TESTS_FAILED++))
        if [ "$required" = "required" ]; then
            echo -e "${RED}This is a required test. Fix issues before continuing.${NC}"
            return 1
        else
            echo -e "${YELLOW}This is an optional test. Continuing...${NC}"
            return 0
        fi
    fi
}

# Test 1: Service Health Checks
echo -e "${BLUE}📊 Test Suite 1: Service Health${NC}"
if [ -f "$SCRIPT_DIR/check_all_services.sh" ]; then
    run_test "Service Health Check" "$SCRIPT_DIR/check_all_services.sh" "required"
else
    echo -e "${YELLOW}⚠️  Service health check script not found${NC}"
    ((TESTS_SKIPPED++))
fi
echo ""

# Test 2: Database Tests
echo -e "${BLUE}📊 Test Suite 2: Database${NC}"

# fks_web database
if [ -f "$SCRIPT_DIR/test_fks_web_db.sh" ]; then
    run_test "fks_web Database Connection" "$SCRIPT_DIR/test_fks_web_db.sh" "optional"
else
    echo -e "${YELLOW}⚠️  fks_web database test not found${NC}"
    ((TESTS_SKIPPED++))
fi

# fks_auth database
if [ -f "$SCRIPT_DIR/test_fks_auth_db.sh" ]; then
    run_test "fks_auth Database Connection" "$SCRIPT_DIR/test_fks_auth_db.sh" "optional"
else
    echo -e "${YELLOW}⚠️  fks_auth database test not found${NC}"
    ((TESTS_SKIPPED++))
fi
echo ""

# Test 3: Authentication
echo -e "${BLUE}📊 Test Suite 3: Authentication${NC}"
if [ -f "$SCRIPT_DIR/test_authentication_flow.py" ]; then
    echo -e "${BLUE}Running: Authentication Flow Test${NC}"
    if python3 "$SCRIPT_DIR/test_authentication_flow.py" --skip-fks-auth 2>&1; then
        echo -e "${GREEN}✅ Authentication Flow Test: PASSED${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}⚠️  Authentication Flow Test: FAILED (optional)${NC}"
        ((TESTS_FAILED++))
    fi
else
    echo -e "${YELLOW}⚠️  Authentication flow test not found${NC}"
    ((TESTS_SKIPPED++))
fi
echo ""

# Test 4: API Tests (Optional - require API keys)
echo -e "${BLUE}📊 Test Suite 4: API Tests (Optional)${NC}"

# Massive.com Futures REST API
if [ -f "$SCRIPT_DIR/test_massive_futures_api.sh" ]; then
    if [ -n "${MASSIVE_API_KEY:-}" ] || [ -n "${FKS_MASSIVE_API_KEY:-}" ]; then
        run_test "Massive.com Futures REST API" "$SCRIPT_DIR/test_massive_futures_api.sh" "optional"
    else
        echo -e "${YELLOW}⚠️  Massive.com Futures API test skipped (no API key)${NC}"
        ((TESTS_SKIPPED++))
    fi
else
    echo -e "${YELLOW}⚠️  Massive.com Futures API test not found${NC}"
    ((TESTS_SKIPPED++))
fi

# Massive.com Futures WebSocket
if [ -f "$SCRIPT_DIR/test_massive_futures_websocket.py" ]; then
    if [ -n "${MASSIVE_API_KEY:-}" ] || [ -n "${FKS_MASSIVE_API_KEY:-}" ]; then
        echo -e "${BLUE}Running: Massive.com Futures WebSocket Test${NC}"
        if timeout 30 python3 "$SCRIPT_DIR/test_massive_futures_websocket.py" --timeout 20 --ticker ESU0 2>&1; then
            echo -e "${GREEN}✅ Massive.com Futures WebSocket: PASSED${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${YELLOW}⚠️  Massive.com Futures WebSocket: FAILED (optional)${NC}"
            ((TESTS_FAILED++))
        fi
    else
        echo -e "${YELLOW}⚠️  Massive.com Futures WebSocket test skipped (no API key)${NC}"
        ((TESTS_SKIPPED++))
    fi
else
    echo -e "${YELLOW}⚠️  Massive.com Futures WebSocket test not found${NC}"
    ((TESTS_SKIPPED++))
fi
echo ""

# Summary
echo -e "${BLUE}=== Test Summary ===${NC}"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo -e "${YELLOW}Skipped: $TESTS_SKIPPED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  Some tests failed. Review output above.${NC}"
    exit 1
fi
