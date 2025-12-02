#!/bin/bash
# Analyze Day 1 Stability Test Logs
# Reviews logs from Day 1 of the 7-day stability test
# Usage: ./analyze_day1_logs.sh [--date YYYY-MM-DD]

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
STABILITY_TEST_DIR="${STABILITY_TEST_DIR:-/home/jordan/Nextcloud/code/repos/fks/infrastructure/docs/06-PLANNING/stability-test}"
SERVICE_REGISTRY="/home/jordan/Nextcloud/code/repos/fks/services/config/service_registry.json"
LOG_DIR="${STABILITY_TEST_DIR}/logs"
REPORT_DIR="${STABILITY_TEST_DIR}/reports"

# Parse date argument
TEST_DATE=""
if [ "$1" == "--date" ] && [ -n "$2" ]; then
    TEST_DATE="$2"
else
    # Default to yesterday (Day 1 of test)
    TEST_DATE=$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d 2>/dev/null || echo "")
fi

if [ -z "$TEST_DATE" ]; then
    echo -e "${RED}Error: Could not determine test date${NC}"
    echo "Usage: $0 [--date YYYY-MM-DD]"
    exit 1
fi

echo -e "${BLUE}=== Day 1 Log Analysis ===${NC}\n"
echo -e "Test Date: ${CYAN}$TEST_DATE${NC}"
echo -e "Log Directory: ${CYAN}$LOG_DIR${NC}\n"

# Create report file
REPORT_FILE="${REPORT_DIR}/day1_analysis_${TEST_DATE}.md"
mkdir -p "$REPORT_DIR"

# Initialize report
cat > "$REPORT_FILE" <<EOF
# Day 1 Stability Test Analysis

**Date**: $TEST_DATE  
**Analysis Time**: $(date +%Y-%m-%d\ %H:%M:%S)  
**Day**: 1 of 7

---

## Executive Summary

EOF

# Function to analyze service logs
analyze_service_logs() {
    local service_name=$1
    local log_file="${LOG_DIR}/${service_name}_${TEST_DATE}.log"
    
    if [ ! -f "$log_file" ]; then
        echo -e "  ${YELLOW}⚠ No log file found for $service_name${NC}"
        return 1
    fi
    
    local total_checks=$(wc -l < "$log_file" 2>/dev/null || echo "0")
    local healthy_count=$(grep -c "|HEALTHY|" "$log_file" 2>/dev/null || echo "0")
    local unhealthy_count=$(grep -c "|UNHEALTHY|" "$log_file" 2>/dev/null || echo "0")
    
    if [ "$total_checks" -eq 0 ]; then
        echo -e "  ${YELLOW}⚠ No health checks found for $service_name${NC}"
        return 1
    fi
    
    local uptime_percent=0
    if [ "$total_checks" -gt 0 ]; then
        uptime_percent=$((healthy_count * 100 / total_checks))
    fi
    
    # Calculate average response time
    local avg_response_time=$(grep "|HEALTHY|" "$log_file" | awk -F'|' '{sum+=$3; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' 2>/dev/null || echo "0")
    
    # Find errors
    local errors=$(grep -c "|UNHEALTHY|" "$log_file" 2>/dev/null || echo "0")
    local error_details=""
    if [ "$errors" -gt 0 ]; then
        error_details=$(grep "|UNHEALTHY|" "$log_file" | tail -5 | awk -F'|' '{print $4}' | sort -u | tr '\n' '; ' | sed 's/; $//')
    fi
    
    # Status indicator
    local status_icon="✓"
    local status_color="${GREEN}"
    if [ "$uptime_percent" -lt 95 ]; then
        status_icon="✗"
        status_color="${RED}"
    elif [ "$uptime_percent" -lt 99 ]; then
        status_icon="⚠"
        status_color="${YELLOW}"
    fi
    
    echo -e "  ${status_color}${status_icon}${NC} $service_name:"
    echo -e "     Total Checks: $total_checks"
    echo -e "     Healthy: ${GREEN}$healthy_count${NC}"
    echo -e "     Unhealthy: ${RED}$unhealthy_count${NC}"
    echo -e "     Uptime: ${CYAN}${uptime_percent}%${NC}"
    echo -e "     Avg Response Time: ${CYAN}${avg_response_time}ms${NC}"
    
    if [ "$errors" -gt 0 ]; then
        echo -e "     ${RED}Errors: $errors${NC}"
        echo -e "     Error Details: ${YELLOW}$error_details${NC}"
    fi
    
    # Add to report
    cat >> "$REPORT_FILE" <<EOF
### $service_name

- **Total Checks**: $total_checks
- **Healthy**: $healthy_count
- **Unhealthy**: $unhealthy_count
- **Uptime**: ${uptime_percent}%
- **Average Response Time**: ${avg_response_time}ms

EOF

    if [ "$errors" -gt 0 ]; then
        cat >> "$REPORT_FILE" <<EOF
- **Errors**: $errors
- **Error Details**: $error_details

#### Issues Found:
EOF
        grep "|UNHEALTHY|" "$log_file" | tail -10 | while IFS='|' read -r timestamp status response_time error; do
            echo "- **$timestamp**: $error" >> "$REPORT_FILE"
        done
        echo "" >> "$REPORT_FILE"
    fi
    
    return 0
}

# Function to identify critical issues
identify_critical_issues() {
    echo -e "\n${BLUE}=== Critical Issues Analysis ===${NC}\n"
    
    local critical_issues=0
    
    # Extract services from registry
    local services=$(jq -r '.services | keys[]' "$SERVICE_REGISTRY" 2>/dev/null || echo "")
    
    for service in $services; do
        local log_file="${LOG_DIR}/${service}_${TEST_DATE}.log"
        if [ -f "$log_file" ]; then
            local unhealthy_count=$(grep -c "|UNHEALTHY|" "$log_file" 2>/dev/null || echo "0")
            local total_checks=$(wc -l < "$log_file" 2>/dev/null || echo "0")
            
            if [ "$total_checks" -gt 0 ]; then
                local failure_rate=$((unhealthy_count * 100 / total_checks))
                
                # Critical if > 10% failure rate
                if [ "$failure_rate" -gt 10 ]; then
                    critical_issues=$((critical_issues + 1))
                    echo -e "${RED}✗ CRITICAL: $service has ${failure_rate}% failure rate${NC}"
                    echo -e "   Unhealthy checks: $unhealthy_count / $total_checks"
                fi
            fi
        fi
    done
    
    if [ "$critical_issues" -eq 0 ]; then
        echo -e "${GREEN}✓ No critical issues found${NC}"
    fi
    
    return $critical_issues
}

# Function to analyze crypto-specific logs
analyze_crypto_logs() {
    echo -e "\n${BLUE}=== Crypto Service Analysis ===${NC}\n"
    
    analyze_service_logs "fks_crypto"
    
    # Check crypto dependencies
    echo -e "\n${CYAN}Crypto Dependencies:${NC}"
    analyze_service_logs "fks_data"
    analyze_service_logs "fks_auth"
}

# Main analysis
main() {
    echo -e "${BLUE}Analyzing service logs...${NC}\n"
    
    # Extract services from registry
    local services=$(jq -r '.services | keys[]' "$SERVICE_REGISTRY" 2>/dev/null || echo "")
    
    local total_services=0
    local analyzed_services=0
    
    for service in $services; do
        total_services=$((total_services + 1))
        if analyze_service_logs "$service"; then
            analyzed_services=$((analyzed_services + 1))
        fi
        echo ""
    done
    
    # Identify critical issues
    identify_critical_issues
    
    # Crypto-specific analysis
    analyze_crypto_logs
    
    # Summary
    echo -e "\n${BLUE}=== Analysis Summary ===${NC}"
    echo -e "Total Services: $total_services"
    echo -e "Services Analyzed: $analyzed_services"
    echo -e "Report Generated: ${CYAN}$REPORT_FILE${NC}"
    
    # Add summary to report
    cat >> "$REPORT_FILE" <<EOF
---

## Summary

- **Total Services**: $total_services
- **Services Analyzed**: $analyzed_services
- **Analysis Date**: $(date +%Y-%m-%d\ %H:%M:%S)

## Recommendations

_(To be filled during review)_

## Next Steps

1. Review identified issues
2. Fix critical issues immediately
3. Improve error handling where needed
4. Continue monitoring
5. Update Day 1 stability report

EOF
    
    echo -e "\n${GREEN}✓ Day 1 log analysis complete!${NC}"
}

main
