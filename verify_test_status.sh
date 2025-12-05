#!/bin/bash
# FKS Platform - Comprehensive Test Status Verification
# Purpose: Verify and document current test status across all services
# Usage: ./verify_test_status.sh [--json] [--output FILE]

set -e

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/infrastructure/docs"
SERVICE_REGISTRY="$PROJECT_ROOT/infrastructure/config/service_registry.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Options
JSON_OUTPUT=false
OUTPUT_FILE=""
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--json] [--output FILE] [--verbose]"
            exit 1
            ;;
    esac
done

# Counters
TOTAL_SERVICES=0
SERVICES_WITH_TESTS=0
SERVICES_WITHOUT_TESTS=0
TOTAL_TEST_FILES=0
TOTAL_TEST_FUNCTIONS=0

# Results arrays
declare -a SERVICES_CHECKED
declare -a SERVICES_WITH_TESTS_LIST
declare -a SERVICES_WITHOUT_TESTS_LIST
declare -A SERVICE_TEST_COUNTS
declare -A SERVICE_TEST_COMMANDS

# Function to find service directories
find_service_dirs() {
    local service_name=$1
    
    # Common service directory patterns
    local patterns=(
        "repo/core/${service_name#fks_}"
        "repo/gpu/${service_name#fks_}"
        "repo/tools/${service_name#fks_}"
        "services/${service_name#fks_}"
        "repo/${service_name#fks_}"
    )
    
    for pattern in "${patterns[@]}"; do
        local dir="$PROJECT_ROOT/$pattern"
        if [ -d "$dir" ]; then
            echo "$dir"
            return 0
        fi
    done
    
    return 1
}

# Function to count test files in directory
count_test_files() {
    local test_dir=$1
    if [ ! -d "$test_dir" ]; then
        echo 0
        return
    fi
    
    find "$test_dir" -name "test_*.py" -o -name "*_test.py" -o -name "test_*.rs" 2>/dev/null | wc -l | tr -d ' '
}

# Function to count test functions
count_test_functions() {
    local test_dir=$1
    if [ ! -d "$test_dir" ]; then
        echo 0
        return
    fi
    
    # Count Python test functions
    local python_tests=$(find "$test_dir" -name "test_*.py" -o -name "*_test.py" 2>/dev/null | xargs grep -h "^def test_\|^async def test_\|^    def test_\|^    async def test_" 2>/dev/null | wc -l | tr -d ' ')
    
    # Count Rust test functions
    local rust_tests=$(find "$test_dir" -name "test_*.rs" 2>/dev/null | xargs grep -h "^    fn test_\|^    #\[test\]" 2>/dev/null | wc -l | tr -d ' ')
    
    echo $((python_tests + rust_tests))
}

# Function to check if pytest is available
check_pytest() {
    if command -v pytest &> /dev/null; then
        return 0
    fi
    return 1
}

# Function to check if cargo is available (for Rust services)
check_cargo() {
    if command -v cargo &> /dev/null; then
        return 0
    fi
    return 1
}

# Function to get test command from service registry
get_test_command() {
    local service_name=$1
    
    if [ ! -f "$SERVICE_REGISTRY" ] || ! command -v jq &> /dev/null; then
        echo ""
        return
    fi
    
    jq -r ".services[\"$service_name\"].test_command // empty" "$SERVICE_REGISTRY" 2>/dev/null || echo ""
}

# Function to verify service tests
verify_service_tests() {
    local service_name=$1
    local service_dir=$2
    
    SERVICES_CHECKED+=("$service_name")
    TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
    
    local test_dirs=(
        "$service_dir/tests"
        "$service_dir/test"
        "$service_dir/__tests__"
        "$service_dir/tests/unit"
        "$service_dir/tests/integration"
    )
    
    local test_files_count=0
    local test_functions_count=0
    local found_tests=false
    
    for test_dir in "${test_dirs[@]}"; do
        if [ -d "$test_dir" ]; then
            local files=$(count_test_files "$test_dir")
            local functions=$(count_test_functions "$test_dir")
            
            if [ "$files" -gt 0 ]; then
                test_files_count=$((test_files_count + files))
                test_functions_count=$((test_functions_count + functions))
                found_tests=true
            fi
        fi
    done
    
    if [ "$found_tests" = true ]; then
        SERVICES_WITH_TESTS=$((SERVICES_WITH_TESTS + 1))
        SERVICES_WITH_TESTS_LIST+=("$service_name")
        SERVICE_TEST_COUNTS["$service_name"]="$test_files_count files, $test_functions_count functions"
        
        local test_cmd=$(get_test_command "$service_name")
        if [ -n "$test_cmd" ]; then
            SERVICE_TEST_COMMANDS["$service_name"]="$test_cmd"
        fi
        
        TOTAL_TEST_FILES=$((TOTAL_TEST_FILES + test_files_count))
        TOTAL_TEST_FUNCTIONS=$((TOTAL_TEST_FUNCTIONS + test_functions_count))
        
        echo -e "  ${GREEN}✓${NC} Tests found: ${CYAN}$test_files_count files${NC}, ${CYAN}$test_functions_count functions${NC}"
        return 0
    else
        SERVICES_WITHOUT_TESTS=$((SERVICES_WITHOUT_TESTS + 1))
        SERVICES_WITHOUT_TESTS_LIST+=("$service_name")
        echo -e "  ${YELLOW}⚠${NC} No tests found"
        return 1
    fi
}

# Main execution
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  FKS Platform - Test Status Verification${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Timestamp: ${CYAN}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "Project Root: ${CYAN}$PROJECT_ROOT${NC}"
echo ""

# Check dependencies
PYTEST_AVAILABLE=false
CARGO_AVAILABLE=false

if check_pytest; then
    PYTEST_AVAILABLE=true
    echo -e "${GREEN}✓${NC} pytest is available"
else
    echo -e "${YELLOW}⚠${NC} pytest not found (Python tests may not be runnable)"
fi

if check_cargo; then
    CARGO_AVAILABLE=true
    echo -e "${GREEN}✓${NC} cargo is available"
else
    echo -e "${YELLOW}⚠${NC} cargo not found (Rust tests may not be runnable)"
fi

echo ""

# Get services from registry
if [ ! -f "$SERVICE_REGISTRY" ]; then
    echo -e "${RED}Error: Service registry not found at $SERVICE_REGISTRY${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not found${NC}"
    exit 1
fi

echo -e "${BLUE}Checking services from registry...${NC}\n"

# Get all services
services=$(jq -r '.services | keys[]' "$SERVICE_REGISTRY" 2>/dev/null)

for service_name in $services; do
    echo -e "${CYAN}Checking: $service_name${NC}"
    
    # Find service directory
    service_dir=$(find_service_dirs "$service_name")
    
    if [ -z "$service_dir" ] || [ ! -d "$service_dir" ]; then
        echo -e "  ${RED}✗${NC} Service directory not found"
        SERVICES_WITHOUT_TESTS_LIST+=("$service_name")
        SERVICES_WITHOUT_TESTS=$((SERVICES_WITHOUT_TESTS + 1))
        continue
    fi
    
    if [ "$VERBOSE" = true ]; then
        echo -e "  Directory: ${CYAN}$service_dir${NC}"
    fi
    
    verify_service_tests "$service_name" "$service_dir"
    echo ""
done

# Generate summary
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Test Status Summary${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Total Services Checked: ${CYAN}$TOTAL_SERVICES${NC}"
echo -e "Services with Tests: ${GREEN}$SERVICES_WITH_TESTS${NC}"
echo -e "Services without Tests: ${RED}$SERVICES_WITHOUT_TESTS${NC}"
echo ""
echo -e "Total Test Files: ${CYAN}$TOTAL_TEST_FILES${NC}"
echo -e "Total Test Functions: ${CYAN}$TOTAL_TEST_FUNCTIONS${NC}"
echo ""

# Services with tests details
if [ ${#SERVICES_WITH_TESTS_LIST[@]} -gt 0 ]; then
    echo -e "${GREEN}Services with Tests:${NC}"
    for service in "${SERVICES_WITH_TESTS_LIST[@]}"; do
        echo -e "  - ${CYAN}$service${NC}: ${SERVICE_TEST_COUNTS[$service]}"
        if [ -n "${SERVICE_TEST_COMMANDS[$service]:-}" ]; then
            echo -e "    Command: ${YELLOW}${SERVICE_TEST_COMMANDS[$service]}${NC}"
        fi
    done
    echo ""
fi

# Services without tests
if [ ${#SERVICES_WITHOUT_TESTS_LIST[@]} -gt 0 ]; then
    echo -e "${YELLOW}Services without Tests:${NC}"
    for service in "${SERVICES_WITHOUT_TESTS_LIST[@]}"; do
        echo -e "  - ${RED}$service${NC}"
    done
    echo ""
fi

# Test environment status
echo -e "${BLUE}Test Environment Status:${NC}"
if [ "$PYTEST_AVAILABLE" = true ]; then
    echo -e "  ${GREEN}✓${NC} pytest: Available"
else
    echo -e "  ${RED}✗${NC} pytest: Not available"
fi

if [ "$CARGO_AVAILABLE" = true ]; then
    echo -e "  ${GREEN}✓${NC} cargo: Available"
else
    echo -e "  ${RED}✗${NC} cargo: Not available"
fi
echo ""

# Generate JSON output if requested
if [ "$JSON_OUTPUT" = true ]; then
    JSON_FILE="${OUTPUT_FILE:-$OUTPUT_DIR/TEST_STATUS_$(date +%Y%m%d_%H%M%S).json}"
    
    echo -e "${BLUE}Generating JSON report: ${CYAN}$JSON_FILE${NC}"
    
    {
        echo "{"
        echo "  \"timestamp\": \"$(date -Iseconds)\","
        echo "  \"summary\": {"
        echo "    \"total_services\": $TOTAL_SERVICES,"
        echo "    \"services_with_tests\": $SERVICES_WITH_TESTS,"
        echo "    \"services_without_tests\": $SERVICES_WITHOUT_TESTS,"
        echo "    \"total_test_files\": $TOTAL_TEST_FILES,"
        echo "    \"total_test_functions\": $TOTAL_TEST_FUNCTIONS,"
        echo "    \"test_environment\": {"
        echo "      \"pytest_available\": $PYTEST_AVAILABLE,"
        echo "      \"cargo_available\": $CARGO_AVAILABLE"
        echo "    }"
        echo "  },"
        echo "  \"services_with_tests\": ["
        
        first=true
        for service in "${SERVICES_WITH_TESTS_LIST[@]}"; do
            if [ "$first" = true ]; then
                first=false
            else
                echo ","
            fi
            echo -n "    {"
            echo -n "\"name\": \"$service\","
            echo -n "\"test_count\": \"${SERVICE_TEST_COUNTS[$service]}\""
            if [ -n "${SERVICE_TEST_COMMANDS[$service]:-}" ]; then
                echo -n ",\"test_command\": \"${SERVICE_TEST_COMMANDS[$service]}\""
            fi
            echo -n "}"
        done
        
        echo ""
        echo "  ],"
        echo "  \"services_without_tests\": ["
        
        first=true
        for service in "${SERVICES_WITHOUT_TESTS_LIST[@]}"; do
            if [ "$first" = true ]; then
                first=false
            else
                echo ","
            fi
            echo -n "    \"$service\""
        done
        
        echo ""
        echo "  ]"
        echo "}"
    } > "$JSON_FILE"
    
    echo -e "${GREEN}✓${NC} JSON report saved to: ${CYAN}$JSON_FILE${NC}"
    echo ""
fi

# Generate markdown report
MD_FILE="${OUTPUT_FILE:-$OUTPUT_DIR/TEST_STATUS_REPORT_$(date +%Y%m%d).md}"
if [ "$OUTPUT_FILE" = "" ] || [ "$JSON_OUTPUT" = false ]; then
    echo -e "${BLUE}Generating Markdown report: ${CYAN}$MD_FILE${NC}"
    
    {
        echo "# FKS Platform - Test Status Report"
        echo ""
        echo "**Generated**: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "## Summary"
        echo ""
        echo "| Metric | Value |"
        echo "|--------|-------|"
        echo "| Total Services | $TOTAL_SERVICES |"
        echo "| Services with Tests | $SERVICES_WITH_TESTS |"
        echo "| Services without Tests | $SERVICES_WITHOUT_TESTS |"
        echo "| Total Test Files | $TOTAL_TEST_FILES |"
        echo "| Total Test Functions | $TOTAL_TEST_FUNCTIONS |"
        echo ""
        echo "## Test Environment"
        echo ""
        echo "- pytest: $([ "$PYTEST_AVAILABLE" = true ] && echo "✅ Available" || echo "❌ Not Available")"
        echo "- cargo: $([ "$CARGO_AVAILABLE" = true ] && echo "✅ Available" || echo "❌ Not Available")"
        echo ""
        
        if [ ${#SERVICES_WITH_TESTS_LIST[@]} -gt 0 ]; then
            echo "## Services with Tests"
            echo ""
            for service in "${SERVICES_WITH_TESTS_LIST[@]}"; do
                echo "### $service"
                echo ""
                echo "- Test Count: ${SERVICE_TEST_COUNTS[$service]}"
                if [ -n "${SERVICE_TEST_COMMANDS[$service]:-}" ]; then
                    echo "- Test Command: \`${SERVICE_TEST_COMMANDS[$service]}\`"
                fi
                echo ""
            done
        fi
        
        if [ ${#SERVICES_WITHOUT_TESTS_LIST[@]} -gt 0 ]; then
            echo "## Services without Tests"
            echo ""
            for service in "${SERVICES_WITHOUT_TESTS_LIST[@]}"; do
                echo "- $service"
            done
            echo ""
        fi
        
        echo "---"
        echo ""
        echo "**Generated by**: verify_test_status.sh"
    } > "$MD_FILE"
    
    echo -e "${GREEN}✓${NC} Markdown report saved to: ${CYAN}$MD_FILE${NC}"
    echo ""
fi

# Exit with appropriate code
if [ $SERVICES_WITHOUT_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ All services have tests!${NC}"
    exit 0
elif [ $SERVICES_WITH_TESTS -gt 0 ]; then
    echo -e "${YELLOW}⚠ Some services are missing tests${NC}"
    exit 0
else
    echo -e "${RED}✗ No tests found in any service${NC}"
    exit 1
fi
