#!/bin/bash
# Analyze Day 2-3 Stability Test Logs
# Reviews logs from Days 2-3, identifies patterns, and focuses on data collection and signal generation issues
# Usage: ./analyze_days2-3_logs.sh [--start-date YYYY-MM-DD]

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
START_DATE=""
if [ "$1" == "--start-date" ] && [ -n "$2" ]; then
    START_DATE="$2"
else
    # Default to 2 days ago (Day 2 of test)
    START_DATE=$(date -d "2 days ago" +%Y-%m-%d 2>/dev/null || date -v-2d +%Y-%m-%d 2>/dev/null || echo "")
fi

if [ -z "$START_DATE" ]; then
    echo -e "${RED}Error: Could not determine start date${NC}"
    echo "Usage: $0 [--start-date YYYY-MM-DD]"
    exit 1
fi

DAY2_DATE=$START_DATE
DAY3_DATE=$(date -d "$START_DATE + 1 day" +%Y-%m-%d 2>/dev/null || date -v+1d -j -f "%Y-%m-%d" "$START_DATE" +%Y-%m-%d 2>/dev/null || echo "")

if [ -z "$DAY3_DATE" ]; then
    echo -e "${RED}Error: Could not calculate Day 3 date${NC}"
    exit 1
fi

echo -e "${BLUE}=== Day 2-3 Log Analysis ===${NC}\n"
echo -e "Day 2 Date: ${CYAN}$DAY2_DATE${NC}"
echo -e "Day 3 Date: ${CYAN}$DAY3_DATE${NC}"
echo -e "Log Directory: ${CYAN}$LOG_DIR${NC}\n"

# Create report file
REPORT_FILE="${REPORT_DIR}/days2-3_analysis_${START_DATE}.md"
mkdir -p "$REPORT_DIR"

# Initialize report
cat > "$REPORT_FILE" <<EOF
# Day 2-3 Stability Test Analysis

**Day 2 Date**: $DAY2_DATE  
**Day 3 Date**: $DAY3_DATE  
**Analysis Time**: $(date +%Y-%m-%d\ %H:%M:%S)  
**Days**: 2-3 of 7

---

## Executive Summary

This analysis focuses on identifying patterns in errors, data collection issues, and signal generation problems across Days 2-3 of the stability test.

---

## Pattern Analysis

EOF

# Function to analyze service logs for patterns
analyze_service_patterns() {
    local service_name=$1
    local day2_log="${LOG_DIR}/${service_name}_${DAY2_DATE}.log"
    local day3_log="${LOG_DIR}/${service_name}_${DAY3_DATE}.log"
    
    if [ ! -f "$day2_log" ] && [ ! -f "$day3_log" ]; then
        echo -e "  ${YELLOW}⚠ No log files found for $service_name${NC}"
        return 1
    fi
    
    # Combine both days for pattern analysis
    local combined_log=$(mktemp)
    [ -f "$day2_log" ] && cat "$day2_log" >> "$combined_log"
    [ -f "$day3_log" ] && cat "$day3_log" >> "$combined_log"
    
    local total_checks=$(wc -l < "$combined_log" 2>/dev/null || echo "0")
    local healthy_count=$(grep -c "|HEALTHY|" "$combined_log" 2>/dev/null || echo "0")
    local unhealthy_count=$(grep -c "|UNHEALTHY|" "$combined_log" 2>/dev/null || echo "0")
    
    if [ "$total_checks" -eq 0 ]; then
        echo -e "  ${YELLOW}⚠ No health checks found for $service_name${NC}"
        rm -f "$combined_log"
        return 1
    fi
    
    local uptime_percent=0
    if [ "$total_checks" -gt 0 ]; then
        uptime_percent=$((healthy_count * 100 / total_checks))
    fi
    
    # Pattern analysis
    local error_patterns=$(grep "|UNHEALTHY|" "$combined_log" | awk -F'|' '{print $4}' | sort | uniq -c | sort -rn | head -5)
    local time_patterns=$(grep "|UNHEALTHY|" "$combined_log" | awk -F'|' '{print $1}' | awk -F'T' '{print $2}' | awk -F':' '{print $1}' | sort | uniq -c | sort -rn | head -5)
    
    # Trend analysis (Day 2 vs Day 3)
    local day2_healthy=0
    local day2_total=0
    local day3_healthy=0
    local day3_total=0
    
    if [ -f "$day2_log" ]; then
        day2_total=$(wc -l < "$day2_log" 2>/dev/null || echo "0")
        day2_healthy=$(grep -c "|HEALTHY|" "$day2_log" 2>/dev/null || echo "0")
    fi
    
    if [ -f "$day3_log" ]; then
        day3_total=$(wc -l < "$day3_log" 2>/dev/null || echo "0")
        day3_healthy=$(grep -c "|HEALTHY|" "$day3_log" 2>/dev/null || echo "0")
    fi
    
    local day2_uptime=0
    local day3_uptime=0
    if [ "$day2_total" -gt 0 ]; then
        day2_uptime=$((day2_healthy * 100 / day2_total))
    fi
    if [ "$day3_total" -gt 0 ]; then
        day3_uptime=$((day3_healthy * 100 / day3_total))
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
    echo -e "     Total Checks (Days 2-3): $total_checks"
    echo -e "     Healthy: ${GREEN}$healthy_count${NC}"
    echo -e "     Unhealthy: ${RED}$unhealthy_count${NC}"
    echo -e "     Overall Uptime: ${CYAN}${uptime_percent}%${NC}"
    echo -e "     Day 2 Uptime: ${CYAN}${day2_uptime}%${NC}"
    echo -e "     Day 3 Uptime: ${CYAN}${day3_uptime}%${NC}"
    
    # Trend indicator
    if [ "$day3_uptime" -gt "$day2_uptime" ]; then
        echo -e "     Trend: ${GREEN}↑ Improving${NC}"
    elif [ "$day3_uptime" -lt "$day2_uptime" ]; then
        echo -e "     Trend: ${RED}↓ Degrading${NC}"
    else
        echo -e "     Trend: ${YELLOW}→ Stable${NC}"
    fi
    
    if [ "$unhealthy_count" -gt 0 ]; then
        echo -e "     ${CYAN}Top Error Patterns:${NC}"
        echo "$error_patterns" | while read count pattern; do
            if [ -n "$pattern" ]; then
                echo -e "       ${YELLOW}$count${NC} occurrences: $pattern"
            fi
        done
        
        echo -e "     ${CYAN}Error Time Patterns:${NC}"
        echo "$time_patterns" | while read count hour; do
            if [ -n "$hour" ]; then
                echo -e "       ${YELLOW}$count${NC} errors at hour $hour:00"
            fi
        done
    fi
    
    # Add to report
    cat >> "$REPORT_FILE" <<EOF
### $service_name

- **Total Checks (Days 2-3)**: $total_checks
- **Healthy**: $healthy_count
- **Unhealthy**: $unhealthy_count
- **Overall Uptime**: ${uptime_percent}%
- **Day 2 Uptime**: ${day2_uptime}%
- **Day 3 Uptime**: ${day3_uptime}%

EOF

    if [ "$day3_uptime" -gt "$day2_uptime" ]; then
        echo "- **Trend**: ↑ Improving" >> "$REPORT_FILE"
    elif [ "$day3_uptime" -lt "$day2_uptime" ]; then
        echo "- **Trend**: ↓ Degrading" >> "$REPORT_FILE"
    else
        echo "- **Trend**: → Stable" >> "$REPORT_FILE"
    fi
    
    if [ "$unhealthy_count" -gt 0 ]; then
        cat >> "$REPORT_FILE" <<EOF
- **Error Patterns**:
EOF
        echo "$error_patterns" | while read count pattern; do
            if [ -n "$pattern" ]; then
                echo "  - $count occurrences: $pattern" >> "$REPORT_FILE"
            fi
        done
    fi
    
    echo "" >> "$REPORT_FILE"
    
    rm -f "$combined_log"
    return 0
}

# Function to identify data collection issues
identify_data_collection_issues() {
    echo -e "\n${BLUE}=== Data Collection Issues Analysis ===${NC}\n"
    
    local data_log2="${LOG_DIR}/fks_data_${DAY2_DATE}.log"
    local data_log3="${LOG_DIR}/fks_data_${DAY3_DATE}.log"
    
    if [ ! -f "$data_log2" ] && [ ! -f "$data_log3" ]; then
        echo -e "${YELLOW}⚠ No data service logs found${NC}"
        return 1
    fi
    
    local combined_log=$(mktemp)
    [ -f "$data_log2" ] && cat "$data_log2" >> "$combined_log"
    [ -f "$data_log3" ] && cat "$data_log3" >> "$combined_log"
    
    local data_errors=$(grep -c "|UNHEALTHY|" "$combined_log" 2>/dev/null || echo "0")
    local data_total=$(wc -l < "$combined_log" 2>/dev/null || echo "0")
    
    if [ "$data_total" -gt 0 ]; then
        local failure_rate=$((data_errors * 100 / data_total))
        
        echo -e "${CYAN}fks_data Service:${NC}"
        echo -e "  Total Checks: $data_total"
        echo -e "  Errors: $data_errors"
        echo -e "  Failure Rate: ${failure_rate}%"
        
        if [ "$failure_rate" -gt 5 ]; then
            echo -e "  ${RED}⚠ High failure rate detected${NC}"
            echo -e "  ${YELLOW}Common data collection issues:${NC}"
            echo -e "    - API rate limits"
            echo -e "    - Network connectivity"
            echo -e "    - Data provider issues"
            echo -e "    - Database connection problems"
        fi
        
        # Add to report
        cat >> "$REPORT_FILE" <<EOF
## Data Collection Issues

### fks_data Service
- **Total Checks**: $data_total
- **Errors**: $data_errors
- **Failure Rate**: ${failure_rate}%

EOF

        if [ "$failure_rate" -gt 5 ]; then
            cat >> "$REPORT_FILE" <<EOF
**⚠ High failure rate detected**

Common issues to investigate:
- API rate limits
- Network connectivity
- Data provider issues
- Database connection problems

EOF
        fi
    fi
    
    rm -f "$combined_log"
}

# Function to identify signal generation issues
identify_signal_generation_issues() {
    echo -e "\n${BLUE}=== Signal Generation Issues Analysis ===${NC}\n"
    
    # Check fks_app (traditional signals)
    local app_log2="${LOG_DIR}/fks_app_${DAY2_DATE}.log"
    local app_log3="${LOG_DIR}/fks_app_${DAY3_DATE}.log"
    
    # Check fks_crypto (crypto signals)
    local crypto_log2="${LOG_DIR}/fks_crypto_${DAY2_DATE}.log"
    local crypto_log3="${LOG_DIR}/fks_crypto_${DAY3_DATE}.log"
    
    echo -e "${CYAN}Signal Generation Services:${NC}\n"
    
    # fks_app analysis
    if [ -f "$app_log2" ] || [ -f "$app_log3" ]; then
        local combined_app=$(mktemp)
        [ -f "$app_log2" ] && cat "$app_log2" >> "$combined_app"
        [ -f "$app_log3" ] && cat "$app_log3" >> "$combined_app"
        
        local app_errors=$(grep -c "|UNHEALTHY|" "$combined_app" 2>/dev/null || echo "0")
        local app_total=$(wc -l < "$combined_app" 2>/dev/null || echo "0")
        
        if [ "$app_total" -gt 0 ]; then
            local app_failure_rate=$((app_errors * 100 / app_total))
            echo -e "  ${CYAN}fks_app (Traditional Signals):${NC}"
            echo -e "    Total Checks: $app_total"
            echo -e "    Errors: $app_errors"
            echo -e "    Failure Rate: ${app_failure_rate}%"
            
            if [ "$app_failure_rate" -gt 5 ]; then
                echo -e "    ${RED}⚠ High failure rate detected${NC}"
            fi
        fi
        
        rm -f "$combined_app"
    fi
    
    # fks_crypto analysis
    if [ -f "$crypto_log2" ] || [ -f "$crypto_log3" ]; then
        local combined_crypto=$(mktemp)
        [ -f "$crypto_log2" ] && cat "$crypto_log2" >> "$combined_crypto"
        [ -f "$crypto_log3" ] && cat "$crypto_log3" >> "$combined_crypto"
        
        local crypto_errors=$(grep -c "|UNHEALTHY|" "$combined_crypto" 2>/dev/null || echo "0")
        local crypto_total=$(wc -l < "$combined_crypto" 2>/dev/null || echo "0")
        
        if [ "$crypto_total" -gt 0 ]; then
            local crypto_failure_rate=$((crypto_errors * 100 / crypto_total))
            echo -e "  ${CYAN}fks_crypto (Crypto Signals):${NC}"
            echo -e "    Total Checks: $crypto_total"
            echo -e "    Errors: $crypto_errors"
            echo -e "    Failure Rate: ${crypto_failure_rate}%"
            
            if [ "$crypto_failure_rate" -gt 5 ]; then
                echo -e "    ${RED}⚠ High failure rate detected${NC}"
            fi
        fi
        
        rm -f "$combined_crypto"
    fi
    
    # Add to report
    cat >> "$REPORT_FILE" <<EOF
## Signal Generation Issues

### fks_app (Traditional Signals)
EOF

    if [ -f "$app_log2" ] || [ -f "$app_log3" ]; then
        local combined_app=$(mktemp)
        [ -f "$app_log2" ] && cat "$app_log2" >> "$combined_app"
        [ -f "$app_log3" ] && cat "$app_log3" >> "$combined_app"
        local app_errors=$(grep -c "|UNHEALTHY|" "$combined_app" 2>/dev/null || echo "0")
        local app_total=$(wc -l < "$combined_app" 2>/dev/null || echo "0")
        local app_failure_rate=0
        if [ "$app_total" -gt 0 ]; then
            app_failure_rate=$((app_errors * 100 / app_total))
        fi
        cat >> "$REPORT_FILE" <<EOF
- **Total Checks**: $app_total
- **Errors**: $app_errors
- **Failure Rate**: ${app_failure_rate}%

EOF
        rm -f "$combined_app"
    else
        echo "No logs available" >> "$REPORT_FILE"
    fi
    
    cat >> "$REPORT_FILE" <<EOF
### fks_crypto (Crypto Signals)
EOF

    if [ -f "$crypto_log2" ] || [ -f "$crypto_log3" ]; then
        local combined_crypto=$(mktemp)
        [ -f "$crypto_log2" ] && cat "$crypto_log2" >> "$combined_crypto"
        [ -f "$crypto_log3" ] && cat "$crypto_log3" >> "$combined_crypto"
        local crypto_errors=$(grep -c "|UNHEALTHY|" "$combined_crypto" 2>/dev/null || echo "0")
        local crypto_total=$(wc -l < "$combined_crypto" 2>/dev/null || echo "0")
        local crypto_failure_rate=0
        if [ "$crypto_total" -gt 0 ]; then
            crypto_failure_rate=$((crypto_errors * 100 / crypto_total))
        fi
        cat >> "$REPORT_FILE" <<EOF
- **Total Checks**: $crypto_total
- **Errors**: $crypto_errors
- **Failure Rate**: ${crypto_failure_rate}%

EOF
        rm -f "$combined_crypto"
    else
        echo "No logs available" >> "$REPORT_FILE"
    fi
}

# Main analysis
main() {
    echo -e "${BLUE}Analyzing service logs for Days 2-3...${NC}\n"
    
    # Extract services from registry
    local services=$(jq -r '.services | keys[]' "$SERVICE_REGISTRY" 2>/dev/null || echo "")
    
    local total_services=0
    local analyzed_services=0
    
    for service in $services; do
        total_services=$((total_services + 1))
        if analyze_service_patterns "$service"; then
            analyzed_services=$((analyzed_services + 1))
        fi
        echo ""
    done
    
    # Identify specific issues
    identify_data_collection_issues
    identify_signal_generation_issues
    
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

1. Review identified patterns in errors
2. Fix data collection issues (fks_data)
3. Fix signal generation issues (fks_app, fks_crypto)
4. Improve reliability in identified areas
5. Continue monitoring
6. Test fixes applied
7. Document improvements

## Next Steps

1. Review identified issues
2. Apply fixes for data collection problems
3. Apply fixes for signal generation problems
4. Improve reliability based on patterns
5. Continue monitoring
6. Test fixes
7. Document improvements
8. Update Day 2-3 stability report

EOF
    
    echo -e "\n${GREEN}✓ Day 2-3 log analysis complete!${NC}"
}

main
