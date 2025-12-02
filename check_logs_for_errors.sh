#!/bin/bash
# Check logs for errors and warnings
# TASK-084: Check logs for errors and warnings

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
LOG_LOOKBACK="1h"  # Check last hour of logs
ERROR_PATTERNS=("error" "exception" "fatal" "panic" "critical" "failed" "failure")
WARNING_PATTERNS=("warning" "warn" "deprecated" "deprecation")
REPORT_FILE="error_log_report_$(date +%Y%m%d_%H%M%S).txt"

echo -e "${BLUE}=== Error and Warning Log Check ===${NC}"
echo -e "${BLUE}Time Range: Last ${LOG_LOOKBACK}${NC}"
echo -e "${BLUE}Report File: ${REPORT_FILE}${NC}"
echo ""

# Function to check container logs
check_container_logs() {
    local container_name=$1
    local error_count=0
    local warning_count=0
    
    echo -e "${YELLOW}Checking ${container_name}...${NC}"
    
    # Get logs
    local logs=$(docker logs --since "${LOG_LOOKBACK}" "${container_name}" 2>&1 || echo "")
    
    if [ -z "${logs}" ]; then
        echo -e "${YELLOW}  No logs found${NC}"
        return
    fi
    
    # Check for errors
    for pattern in "${ERROR_PATTERNS[@]}"; do
        local matches=$(echo "${logs}" | grep -i "${pattern}" | wc -l)
        if [ "${matches}" -gt 0 ]; then
            error_count=$((error_count + matches))
            echo -e "${RED}  ✗ Found ${matches} '${pattern}' entries${NC}"
            echo "${container_name} - ERROR - ${pattern}: ${matches} occurrences" >> "${REPORT_FILE}"
            echo "${logs}" | grep -i "${pattern}" | head -5 >> "${REPORT_FILE}"
        fi
    done
    
    # Check for warnings
    for pattern in "${WARNING_PATTERNS[@]}"; do
        local matches=$(echo "${logs}" | grep -i "${pattern}" | wc -l)
        if [ "${matches}" -gt 0 ]; then
            warning_count=$((warning_count + matches))
            echo -e "${YELLOW}  ⚠ Found ${matches} '${pattern}' entries${NC}"
            echo "${container_name} - WARNING - ${pattern}: ${matches} occurrences" >> "${REPORT_FILE}"
            echo "${logs}" | grep -i "${pattern}" | head -5 >> "${REPORT_FILE}"
        fi
    done
    
    if [ "${error_count}" -eq 0 ] && [ "${warning_count}" -eq 0 ]; then
        echo -e "${GREEN}  ✓ No errors or warnings found${NC}"
    fi
    
    echo "${container_name}: ${error_count} errors, ${warning_count} warnings" >> "${REPORT_FILE}"
    echo "" >> "${REPORT_FILE}"
}

# Function to check system logs
check_system_logs() {
    echo -e "${YELLOW}Checking system logs...${NC}"
    
    # Check journalctl for system errors (if available)
    if command -v journalctl > /dev/null 2>&1; then
        local system_errors=$(journalctl --since "${LOG_LOOKBACK}" --priority=err --no-pager 2>/dev/null | wc -l)
        if [ "${system_errors}" -gt 0 ]; then
            echo -e "${RED}  ✗ Found ${system_errors} system errors${NC}"
            echo "System - ERROR: ${system_errors} errors" >> "${REPORT_FILE}"
        else
            echo -e "${GREEN}  ✓ No system errors found${NC}"
        fi
    fi
    
    # Check Docker daemon logs
    if [ -f /var/log/docker.log ] || [ -f /var/log/syslog ]; then
        echo -e "${YELLOW}  Checking Docker daemon logs...${NC}"
    fi
}

# Main function
main() {
    local total_errors=0
    local total_warnings=0
    local containers_checked=0
    
    echo "Error and Warning Log Report" > "${REPORT_FILE}"
    echo "Generated: $(date)" >> "${REPORT_FILE}"
    echo "Time Range: Last ${LOG_LOOKBACK}" >> "${REPORT_FILE}"
    echo "" >> "${REPORT_FILE}"
    
    # Get all running containers
    local containers=$(docker ps --format "{{.Names}}" 2>/dev/null || echo "")
    
    if [ -z "${containers}" ]; then
        echo -e "${RED}No Docker containers found${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Checking ${containers} containers...${NC}"
    echo ""
    
    # Check each container
    for container in ${containers}; do
        if [[ "${container}" =~ ^fks- ]]; then
            containers_checked=$((containers_checked + 1))
            check_container_logs "${container}"
        fi
    done
    
    # Check system logs
    check_system_logs
    echo ""
    
    # Summary
    echo -e "${BLUE}=== Summary ===${NC}"
    echo -e "${BLUE}Containers Checked: ${containers_checked}${NC}"
    echo -e "${BLUE}Report File: ${REPORT_FILE}${NC}"
    echo ""
    
    # Count total errors and warnings from report
    total_errors=$(grep -c "ERROR" "${REPORT_FILE}" 2>/dev/null || echo "0")
    total_warnings=$(grep -c "WARNING" "${REPORT_FILE}" 2>/dev/null || echo "0")
    
    if [ "${total_errors}" -eq 0 ] && [ "${total_warnings}" -eq 0 ]; then
        echo -e "${GREEN}✓ No critical errors or warnings found${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Found ${total_errors} error entries and ${total_warnings} warning entries${NC}"
        echo -e "${YELLOW}  Review report file: ${REPORT_FILE}${NC}"
        return 1
    fi
}

# Run the check
main "$@"
