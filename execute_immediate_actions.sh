#!/bin/bash
# FKS Platform - Execute Immediate Actions
# Purpose: Run all immediate actions from the action plan
# Usage: ./execute_immediate_actions.sh

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOCS_DIR="$PROJECT_ROOT/infrastructure/docs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  FKS Platform - Immediate Actions Execution${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Timestamp: ${CYAN}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo ""

# Track results
ACTION_COUNT=0
SUCCESS_COUNT=0
FAILED_COUNT=0
FAILED_ACTIONS=()

# Function to execute an action
execute_action() {
    local action_name="$1"
    local action_script="$2"
    
    ACTION_COUNT=$((ACTION_COUNT + 1))
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Action $ACTION_COUNT: $action_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ ! -f "$action_script" ]; then
        echo -e "${RED}✗ Script not found: $action_script${NC}"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_ACTIONS+=("$action_name (script not found)")
        return 1
    fi
    
    if [ ! -x "$action_script" ]; then
        chmod +x "$action_script"
    fi
    
    if bash "$action_script"; then
        echo -e "${GREEN}✓ Action completed successfully${NC}"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        echo ""
        return 0
    else
        echo -e "${RED}✗ Action failed${NC}"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_ACTIONS+=("$action_name")
        echo ""
        return 1
    fi
}

# Action 1: Service Health Check
echo -e "${CYAN}Starting Action 1: Service Health Check${NC}"
if [ -f "$SCRIPT_DIR/check_all_services.sh" ]; then
    execute_action "Service Health Check" "$SCRIPT_DIR/check_all_services.sh"
else
    echo -e "${RED}✗ Service health check script not found${NC}"
    FAILED_COUNT=$((FAILED_COUNT + 1))
    FAILED_ACTIONS+=("Service Health Check (script not found)")
fi

echo ""

# Action 2: Test Status Verification
echo -e "${CYAN}Starting Action 2: Test Status Verification${NC}"
if [ -f "$SCRIPT_DIR/verify_test_status.sh" ]; then
    execute_action "Test Status Verification" "$SCRIPT_DIR/verify_test_status.sh"
else
    echo -e "${RED}✗ Test status verification script not found${NC}"
    FAILED_COUNT=$((FAILED_COUNT + 1))
    FAILED_ACTIONS+=("Test Status Verification (script not found)")
fi

echo ""

# Action 3: Check fks_monitor service
echo -e "${CYAN}Starting Action 3: fks_monitor Service Check${NC}"
echo -e "${BLUE}Checking fks_monitor service status...${NC}"

MONITOR_HEALTHY=false
if curl -sf --max-time 5 "http://localhost:8013/health" > /dev/null 2>&1; then
    MONITOR_HEALTHY=true
    echo -e "${GREEN}✓ fks_monitor is healthy${NC}"
elif curl -sf --max-time 5 "http://localhost:8013/health/health" > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ fks_monitor responds at /health/health but not /health${NC}"
    echo -e "${CYAN}Note: Compatibility endpoint should be added${NC}"
else
    echo -e "${YELLOW}⚠ fks_monitor is not responding${NC}"
    echo -e "${CYAN}Checking Docker container status...${NC}"
    
    if docker ps --format '{{.Names}}' | grep -q "^fks-monitor$"; then
        local status=$(docker inspect --format='{{.State.Status}}' "fks-monitor" 2>/dev/null)
        if [ "$status" = "running" ]; then
            echo -e "${YELLOW}⚠ Container is running but health endpoint not responding${NC}"
            echo -e "${CYAN}Recommendation: Restart the service${NC}"
            echo -e "${CYAN}Command: docker compose restart fks-monitor${NC}"
        else
            echo -e "${RED}✗ Container exists but is not running (status: $status)${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ fks-monitor container not found${NC}"
        echo -e "${CYAN}Service may not be running${NC}"
    fi
fi

echo ""

# Summary
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Execution Summary${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Total Actions: ${CYAN}$ACTION_COUNT${NC}"
echo -e "Successful: ${GREEN}$SUCCESS_COUNT${NC}"
echo -e "Failed: ${RED}$FAILED_COUNT${NC}"
echo ""

if [ ${#FAILED_ACTIONS[@]} -gt 0 ]; then
    echo -e "${YELLOW}Failed Actions:${NC}"
    for action in "${FAILED_ACTIONS[@]}"; do
        echo -e "  - ${RED}$action${NC}"
    done
    echo ""
fi

# Generate report
REPORT_FILE="$DOCS_DIR/IMMEDIATE_ACTIONS_REPORT_$(date +%Y%m%d_%H%M%S).md"
echo -e "${BLUE}Generating report: ${CYAN}$REPORT_FILE${NC}"

{
    echo "# FKS Platform - Immediate Actions Execution Report"
    echo ""
    echo "**Generated**: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "## Summary"
    echo ""
    echo "| Metric | Value |"
    echo "|--------|-------|"
    echo "| Total Actions | $ACTION_COUNT |"
    echo "| Successful | $SUCCESS_COUNT |"
    echo "| Failed | $FAILED_COUNT |"
    echo ""
    
    if [ ${#FAILED_ACTIONS[@]} -gt 0 ]; then
        echo "## Failed Actions"
        echo ""
        for action in "${FAILED_ACTIONS[@]}"; do
            echo "- $action"
        done
        echo ""
    fi
    
    echo "## Service Status"
    echo ""
    echo "### fks_monitor"
    if [ "$MONITOR_HEALTHY" = true ]; then
        echo "- Status: ✅ Healthy"
    else
        echo "- Status: ⚠️ Needs Attention"
        echo "- Recommendation: Check service logs or restart if needed"
    fi
    echo ""
    
    echo "---"
    echo ""
    echo "**Generated by**: execute_immediate_actions.sh"
} > "$REPORT_FILE"

echo -e "${GREEN}✓ Report saved to: ${CYAN}$REPORT_FILE${NC}"
echo ""

# Exit with appropriate code
if [ $FAILED_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ All actions completed successfully!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Some actions failed. Review report above.${NC}"
    exit 1
fi
