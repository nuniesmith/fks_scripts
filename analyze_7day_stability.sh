#!/bin/bash
# Analyze 7-Day Stability Test Results
# Comprehensive analysis of the full 7-day stability test
# Usage: ./analyze_7day_stability.sh [--start-date YYYY-MM-DD]

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
    # Default to 7 days ago (start of test)
    START_DATE=$(date -d "7 days ago" +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d 2>/dev/null || echo "")
fi

if [ -z "$START_DATE" ]; then
    echo -e "${RED}Error: Could not determine start date${NC}"
    echo "Usage: $0 [--start-date YYYY-MM-DD]"
    exit 1
fi

END_DATE=$(date -d "$START_DATE + 6 days" +%Y-%m-%d 2>/dev/null || date -v+6d -j -f "%Y-%m-%d" "$START_DATE" +%Y-%m-%d 2>/dev/null || echo "")

if [ -z "$END_DATE" ]; then
    echo -e "${RED}Error: Could not calculate end date${NC}"
    exit 1
fi

echo -e "${BLUE}=== 7-Day Stability Test Analysis ===${NC}\n"
echo -e "Test Period: ${CYAN}$START_DATE${NC} to ${CYAN}$END_DATE${NC}"
echo -e "Log Directory: ${CYAN}$LOG_DIR${NC}\n"

# Create report file
REPORT_FILE="${REPORT_DIR}/7day_stability_analysis_${START_DATE}.md"
mkdir -p "$REPORT_DIR"

# Initialize report
cat > "$REPORT_FILE" <<EOF
# 7-Day Stability Test Analysis

**Test Period**: $START_DATE to $END_DATE  
**Analysis Time**: $(date +%Y-%m-%d\ %H:%M:%S)  
**Duration**: 7 days

---

## Executive Summary

This comprehensive analysis covers the complete 7-day stability test, including all services, error patterns, fixes applied, and system readiness assessment.

---

## Overall Metrics

EOF

# Function to calculate 7-day metrics for a service
calculate_service_metrics() {
    local service_name=$1
    local total_checks=0
    local total_healthy=0
    local total_unhealthy=0
    local total_response_time=0
    local response_time_count=0
    
    # Aggregate across all 7 days
    for i in {0..6}; do
        local check_date=$(date -d "$START_DATE + $i days" +%Y-%m-%d 2>/dev/null || date -v+${i}d -j -f "%Y-%m-%d" "$START_DATE" +%Y-%m-%d 2>/dev/null || echo "")
        if [ -z "$check_date" ]; then
            continue
        fi
        
        local log_file="${LOG_DIR}/${service_name}_${check_date}.log"
        if [ -f "$log_file" ]; then
            local day_checks=$(wc -l < "$log_file" 2>/dev/null || echo "0")
            local day_healthy=$(grep -c "|HEALTHY|" "$log_file" 2>/dev/null || echo "0")
            local day_unhealthy=$(grep -c "|UNHEALTHY|" "$log_file" 2>/dev/null || echo "0")
            
            total_checks=$((total_checks + day_checks))
            total_healthy=$((total_healthy + day_healthy))
            total_unhealthy=$((total_unhealthy + day_unhealthy))
            
            # Calculate response times
            local day_response_times=$(grep "|HEALTHY|" "$log_file" | awk -F'|' '{sum+=$3; count++} END {if(count>0) print sum, count; else print "0 0"}' 2>/dev/null || echo "0 0")
            local day_sum=$(echo "$day_response_times" | awk '{print $1}')
            local day_count=$(echo "$day_response_times" | awk '{print $2}')
            total_response_time=$(echo "$total_response_time + $day_sum" | bc 2>/dev/null || echo "$total_response_time")
            response_time_count=$((response_time_count + day_count))
        fi
    done
    
    if [ "$total_checks" -eq 0 ]; then
        return 1
    fi
    
    local uptime_percent=0
    if [ "$total_checks" -gt 0 ]; then
        uptime_percent=$((total_healthy * 100 / total_checks))
    fi
    
    local avg_response_time=0
    if [ "$response_time_count" -gt 0 ] && command -v bc >/dev/null 2>&1; then
        avg_response_time=$(echo "scale=2; $total_response_time / $response_time_count" | bc 2>/dev/null || echo "0")
    elif [ "$response_time_count" -gt 0 ]; then
        avg_response_time=$((total_response_time / response_time_count))
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
    echo -e "     Total Checks (7 days): $total_checks"
    echo -e "     Healthy: ${GREEN}$total_healthy${NC}"
    echo -e "     Unhealthy: ${RED}$total_unhealthy${NC}"
    echo -e "     Uptime: ${CYAN}${uptime_percent}%${NC}"
    echo -e "     Avg Response Time: ${CYAN}${avg_response_time}ms${NC}"
    
    # Add to report
    cat >> "$REPORT_FILE" <<EOF
### $service_name

- **Total Checks (7 days)**: $total_checks
- **Healthy**: $total_healthy
- **Unhealthy**: $total_unhealthy
- **Uptime**: ${uptime_percent}%
- **Average Response Time**: ${avg_response_time}ms

EOF
    
    return 0
}

# Function to analyze trends
analyze_trends() {
    echo -e "\n${BLUE}=== Trend Analysis ===${NC}\n"
    
    local services=$(jq -r '.services | keys[]' "$SERVICE_REGISTRY" 2>/dev/null || echo "")
    local improving_services=0
    local stable_services=0
    local degrading_services=0
    
    for service in $services; do
        # Calculate Day 1-3 vs Day 4-7 uptime
        local early_uptime=0
        local late_uptime=0
        
        # Days 1-3
        local early_checks=0
        local early_healthy=0
        for i in {0..2}; do
            local check_date=$(date -d "$START_DATE + $i days" +%Y-%m-%d 2>/dev/null || date -v+${i}d -j -f "%Y-%m-%d" "$START_DATE" +%Y-%m-%d 2>/dev/null || echo "")
            if [ -n "$check_date" ]; then
                local log_file="${LOG_DIR}/${service}_${check_date}.log"
                if [ -f "$log_file" ]; then
                    local day_checks=$(wc -l < "$log_file" 2>/dev/null || echo "0")
                    local day_healthy=$(grep -c "|HEALTHY|" "$log_file" 2>/dev/null || echo "0")
                    early_checks=$((early_checks + day_checks))
                    early_healthy=$((early_healthy + day_healthy))
                fi
            fi
        done
        
        if [ "$early_checks" -gt 0 ]; then
            early_uptime=$((early_healthy * 100 / early_checks))
        fi
        
        # Days 4-7
        local late_checks=0
        local late_healthy=0
        for i in {3..6}; do
            local check_date=$(date -d "$START_DATE + $i days" +%Y-%m-%d 2>/dev/null || date -v+${i}d -j -f "%Y-%m-%d" "$START_DATE" +%Y-%m-%d 2>/dev/null || echo "")
            if [ -n "$check_date" ]; then
                local log_file="${LOG_DIR}/${service}_${check_date}.log"
                if [ -f "$log_file" ]; then
                    local day_checks=$(wc -l < "$log_file" 2>/dev/null || echo "0")
                    local day_healthy=$(grep -c "|HEALTHY|" "$log_file" 2>/dev/null || echo "0")
                    late_checks=$((late_checks + day_checks))
                    late_healthy=$((late_healthy + day_healthy))
                fi
            fi
        done
        
        if [ "$late_checks" -gt 0 ]; then
            late_uptime=$((late_healthy * 100 / late_checks))
        fi
        
        if [ "$early_uptime" -gt 0 ] && [ "$late_uptime" -gt 0 ]; then
            if [ "$late_uptime" -gt "$early_uptime" ]; then
                improving_services=$((improving_services + 1))
                echo -e "  ${GREEN}↑${NC} $service: Improving (${early_uptime}% → ${late_uptime}%)"
            elif [ "$late_uptime" -lt "$early_uptime" ]; then
                degrading_services=$((degrading_services + 1))
                echo -e "  ${RED}↓${NC} $service: Degrading (${early_uptime}% → ${late_uptime}%)"
            else
                stable_services=$((stable_services + 1))
                echo -e "  ${YELLOW}→${NC} $service: Stable (${early_uptime}% → ${late_uptime}%)"
            fi
        fi
    done
    
    echo -e "\n${CYAN}Trend Summary:${NC}"
    echo -e "  Improving: ${GREEN}$improving_services${NC}"
    echo -e "  Stable: ${YELLOW}$stable_services${NC}"
    echo -e "  Degrading: ${RED}$degrading_services${NC}"
    
    # Add to report
    cat >> "$REPORT_FILE" <<EOF
## Trend Analysis

- **Improving Services**: $improving_services
- **Stable Services**: $stable_services
- **Degrading Services**: $degrading_services

### Trend Summary
Services showing improvement over the 7-day period indicate successful fixes and stability improvements.

EOF
}

# Function to calculate overall metrics
calculate_overall_metrics() {
    echo -e "\n${BLUE}=== Overall Metrics ===${NC}\n"
    
    local services=$(jq -r '.services | keys[]' "$SERVICE_REGISTRY" 2>/dev/null || echo "")
    local total_checks=0
    local total_healthy=0
    local total_unhealthy=0
    local services_analyzed=0
    
    for service in $services; do
        local service_checks=0
        local service_healthy=0
        local service_unhealthy=0
        
        for i in {0..6}; do
            local check_date=$(date -d "$START_DATE + $i days" +%Y-%m-%d 2>/dev/null || date -v+${i}d -j -f "%Y-%m-%d" "$START_DATE" +%Y-%m-%d 2>/dev/null || echo "")
            if [ -n "$check_date" ]; then
                local log_file="${LOG_DIR}/${service}_${check_date}.log"
                if [ -f "$log_file" ]; then
                    local day_checks=$(wc -l < "$log_file" 2>/dev/null || echo "0")
                    local day_healthy=$(grep -c "|HEALTHY|" "$log_file" 2>/dev/null || echo "0")
                    local day_unhealthy=$(grep -c "|UNHEALTHY|" "$log_file" 2>/dev/null || echo "0")
                    service_checks=$((service_checks + day_checks))
                    service_healthy=$((service_healthy + day_healthy))
                    service_unhealthy=$((service_unhealthy + day_unhealthy))
                fi
            fi
        done
        
        if [ "$service_checks" -gt 0 ]; then
            total_checks=$((total_checks + service_checks))
            total_healthy=$((total_healthy + service_healthy))
            total_unhealthy=$((total_unhealthy + service_unhealthy))
            services_analyzed=$((services_analyzed + 1))
        fi
    done
    
    local overall_uptime=0
    if [ "$total_checks" -gt 0 ]; then
        overall_uptime=$((total_healthy * 100 / total_checks))
    fi
    
    echo -e "${CYAN}Overall 7-Day Metrics:${NC}"
    echo -e "  Total Checks: $total_checks"
    echo -e "  Healthy: ${GREEN}$total_healthy${NC}"
    echo -e "  Unhealthy: ${RED}$total_unhealthy${NC}"
    echo -e "  Overall Uptime: ${CYAN}${overall_uptime}%${NC}"
    echo -e "  Services Analyzed: $services_analyzed"
    
    # Add to report
    cat >> "$REPORT_FILE" <<EOF
## Overall Metrics

- **Total Health Checks**: $total_checks
- **Successful Checks**: $total_healthy
- **Failed Checks**: $total_unhealthy
- **Overall Uptime**: ${overall_uptime}%
- **Services Analyzed**: $services_analyzed

EOF
}

# Function to analyze crypto stability
analyze_crypto_stability() {
    echo -e "\n${BLUE}=== Crypto Service Stability Analysis ===${NC}\n"
    
    calculate_service_metrics "fks_crypto"
    
    # Check crypto dependencies
    echo -e "\n${CYAN}Crypto Dependencies:${NC}"
    calculate_service_metrics "fks_data"
    calculate_service_metrics "fks_auth"
    
    # Add to report
    cat >> "$REPORT_FILE" <<EOF
## Crypto Service Stability

### fks_crypto 7-Day Analysis
_(See service metrics above)_

### Crypto Dependencies
- **fks_data**: _(See service metrics above)_
- **fks_auth**: _(See service metrics above)_

EOF
}

# Main analysis
main() {
    echo -e "${BLUE}Analyzing 7-day stability test results...${NC}\n"
    
    # Calculate overall metrics
    calculate_overall_metrics
    
    # Analyze each service
    echo -e "\n${BLUE}=== Service Metrics (7-Day) ===${NC}\n"
    local services=$(jq -r '.services | keys[]' "$SERVICE_REGISTRY" 2>/dev/null || echo "")
    
    for service in $services; do
        if calculate_service_metrics "$service"; then
            echo ""
        fi
    done
    
    # Analyze trends
    analyze_trends
    
    # Analyze crypto stability
    analyze_crypto_stability
    
    # Summary
    echo -e "\n${BLUE}=== Analysis Summary ===${NC}"
    echo -e "Report Generated: ${CYAN}$REPORT_FILE${NC}"
    
    # Add summary to report
    cat >> "$REPORT_FILE" <<EOF
---

## Summary

- **Test Period**: $START_DATE to $END_DATE
- **Duration**: 7 days
- **Analysis Date**: $(date +%Y-%m-%d\ %H:%M:%S)

## Key Findings

_(To be filled during review)_

## Recommendations

1. Review all service metrics
2. Address services with low uptime
3. Continue monitoring improving services
4. Fix issues in degrading services
5. Document all fixes applied
6. Assess system readiness

## Next Steps

1. Review this analysis
2. Create comprehensive stability report
3. Document all fixes
4. Verify system stability
5. Plan Week 9

EOF
    
    echo -e "\n${GREEN}✓ 7-day stability analysis complete!${NC}"
}

main
