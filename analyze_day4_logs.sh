#!/bin/bash
# Analyze Day 4 Stability Test Logs
# Reviews Day 4 logs with focus on AI service, dashboard, and error recovery issues
# Usage: ./analyze_day4_logs.sh [--date YYYY-MM-DD]

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
    # Default to 3 days ago (Day 4 of test)
    TEST_DATE=$(date -d "3 days ago" +%Y-%m-%d 2>/dev/null || date -v-3d +%Y-%m-%d 2>/dev/null || echo "")
fi

if [ -z "$TEST_DATE" ]; then
    echo -e "${RED}Error: Could not determine test date${NC}"
    echo "Usage: $0 [--date YYYY-MM-DD]"
    exit 1
fi

echo -e "${BLUE}=== Day 4 Log Analysis ===${NC}\n"
echo -e "Test Date: ${CYAN}$TEST_DATE${NC}"
echo -e "Log Directory: ${CYAN}$LOG_DIR${NC}\n"

# Create report file
REPORT_FILE="${REPORT_DIR}/day4_analysis_${TEST_DATE}.md"
mkdir -p "$REPORT_DIR"

# Initialize report
cat > "$REPORT_FILE" <<EOF
# Day 4 Stability Test Analysis

**Date**: $TEST_DATE  
**Analysis Time**: $(date +%Y-%m-%d\ %H:%M:%S)  
**Day**: 4 of 7

---

## Executive Summary

This analysis focuses on Day 4 of the stability test, with special attention to:
- AI service (fks_ai) issues
- Dashboard (fks_web) issues
- Error recovery mechanisms
- Crypto service issues

---

## Service Health Summary

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

# Function to identify AI service issues
identify_ai_service_issues() {
    echo -e "\n${BLUE}=== AI Service Issues Analysis ===${NC}\n"
    
    local ai_log="${LOG_DIR}/fks_ai_${TEST_DATE}.log"
    
    if [ ! -f "$ai_log" ]; then
        echo -e "${YELLOW}⚠ No AI service logs found${NC}"
        return 1
    fi
    
    local ai_errors=$(grep -c "|UNHEALTHY|" "$ai_log" 2>/dev/null || echo "0")
    local ai_total=$(wc -l < "$ai_log" 2>/dev/null || echo "0")
    
    if [ "$ai_total" -gt 0 ]; then
        local failure_rate=$((ai_errors * 100 / ai_total))
        
        echo -e "${CYAN}fks_ai Service:${NC}"
        echo -e "  Total Checks: $ai_total"
        echo -e "  Errors: $ai_errors"
        echo -e "  Failure Rate: ${failure_rate}%"
        
        if [ "$failure_rate" -gt 5 ]; then
            echo -e "  ${RED}⚠ High failure rate detected${NC}"
            echo -e "  ${YELLOW}Common AI service issues:${NC}"
            echo -e "    - Model loading failures"
            echo -e "    - GPU/Ollama connection issues"
            echo -e "    - Timeout errors"
            echo -e "    - Memory issues"
            echo -e "    - Enhancement request failures"
        fi
        
        # Analyze error types
        local timeout_errors=$(grep -c "timeout\|Timeout\|TIMEOUT" "$ai_log" 2>/dev/null || echo "0")
        local connection_errors=$(grep -c "connection\|Connection\|CONNECTION" "$ai_log" 2>/dev/null || echo "0")
        local memory_errors=$(grep -c "memory\|Memory\|MEMORY" "$ai_log" 2>/dev/null || echo "0")
        
        if [ "$timeout_errors" -gt 0 ]; then
            echo -e "  ${YELLOW}Timeout Errors: $timeout_errors${NC}"
        fi
        if [ "$connection_errors" -gt 0 ]; then
            echo -e "  ${YELLOW}Connection Errors: $connection_errors${NC}"
        fi
        if [ "$memory_errors" -gt 0 ]; then
            echo -e "  ${YELLOW}Memory Errors: $memory_errors${NC}"
        fi
        
        # Add to report
        cat >> "$REPORT_FILE" <<EOF
## AI Service Issues

### fks_ai Service
- **Total Checks**: $ai_total
- **Errors**: $ai_errors
- **Failure Rate**: ${failure_rate}%

EOF

        if [ "$failure_rate" -gt 5 ]; then
            cat >> "$REPORT_FILE" <<EOF
**⚠ High failure rate detected**

Common issues to investigate:
- Model loading failures
- GPU/Ollama connection issues
- Timeout errors
- Memory issues
- Enhancement request failures

**Error Breakdown**:
- Timeout Errors: $timeout_errors
- Connection Errors: $connection_errors
- Memory Errors: $memory_errors

EOF
        fi
    fi
}

# Function to identify dashboard issues
identify_dashboard_issues() {
    echo -e "\n${BLUE}=== Dashboard Issues Analysis ===${NC}\n"
    
    local web_log="${LOG_DIR}/fks_web_${TEST_DATE}.log"
    
    if [ ! -f "$web_log" ]; then
        echo -e "${YELLOW}⚠ No web dashboard logs found${NC}"
        return 1
    fi
    
    local web_errors=$(grep -c "|UNHEALTHY|" "$web_log" 2>/dev/null || echo "0")
    local web_total=$(wc -l < "$web_log" 2>/dev/null || echo "0")
    
    if [ "$web_total" -gt 0 ]; then
        local failure_rate=$((web_errors * 100 / web_total))
        
        echo -e "${CYAN}fks_web Service:${NC}"
        echo -e "  Total Checks: $web_total"
        echo -e "  Errors: $web_errors"
        echo -e "  Failure Rate: ${failure_rate}%"
        
        if [ "$failure_rate" -gt 5 ]; then
            echo -e "  ${RED}⚠ High failure rate detected${NC}"
            echo -e "  ${YELLOW}Common dashboard issues:${NC}"
            echo -e "    - Database connection problems"
            echo -e "    - Template rendering errors"
            echo -e "    - API endpoint failures"
            echo -e "    - Static file serving issues"
            echo -e "    - Session management problems"
        fi
        
        # Analyze error types
        local db_errors=$(grep -c "database\|Database\|DATABASE\|db\|DB" "$web_log" 2>/dev/null || echo "0")
        local template_errors=$(grep -c "template\|Template\|TEMPLATE" "$web_log" 2>/dev/null || echo "0")
        local api_errors=$(grep -c "api\|API\|endpoint\|Endpoint" "$web_log" 2>/dev/null || echo "0")
        
        if [ "$db_errors" -gt 0 ]; then
            echo -e "  ${YELLOW}Database Errors: $db_errors${NC}"
        fi
        if [ "$template_errors" -gt 0 ]; then
            echo -e "  ${YELLOW}Template Errors: $template_errors${NC}"
        fi
        if [ "$api_errors" -gt 0 ]; then
            echo -e "  ${YELLOW}API Errors: $api_errors${NC}"
        fi
        
        # Add to report
        cat >> "$REPORT_FILE" <<EOF
## Dashboard Issues

### fks_web Service
- **Total Checks**: $web_total
- **Errors**: $web_errors
- **Failure Rate**: ${failure_rate}%

EOF

        if [ "$failure_rate" -gt 5 ]; then
            cat >> "$REPORT_FILE" <<EOF
**⚠ High failure rate detected**

Common issues to investigate:
- Database connection problems
- Template rendering errors
- API endpoint failures
- Static file serving issues
- Session management problems

**Error Breakdown**:
- Database Errors: $db_errors
- Template Errors: $template_errors
- API Errors: $api_errors

EOF
        fi
    fi
}

# Function to analyze error recovery
analyze_error_recovery() {
    echo -e "\n${BLUE}=== Error Recovery Analysis ===${NC}\n"
    
    echo -e "${CYAN}Error Recovery Patterns:${NC}"
    
    # Check for services that recover quickly after errors
    local services=$(jq -r '.services | keys[]' "$SERVICE_REGISTRY" 2>/dev/null || echo "")
    local recovery_issues=0
    
    for service in $services; do
        local log_file="${LOG_DIR}/${service}_${TEST_DATE}.log"
        if [ -f "$log_file" ]; then
            # Count consecutive errors
            local consecutive_errors=$(grep "|UNHEALTHY|" "$log_file" | awk -F'|' '{print $1}' | uniq -c | awk '$1 > 3 {print $1}' | wc -l)
            
            if [ "$consecutive_errors" -gt 0 ]; then
                recovery_issues=$((recovery_issues + 1))
                echo -e "  ${YELLOW}⚠ $service: Multiple consecutive errors detected${NC}"
            fi
        fi
    done
    
    if [ "$recovery_issues" -eq 0 ]; then
        echo -e "  ${GREEN}✓ No significant error recovery issues detected${NC}"
    else
        echo -e "  ${RED}✗ $recovery_issues service(s) with error recovery issues${NC}"
    fi
    
    # Add to report
    cat >> "$REPORT_FILE" <<EOF
## Error Recovery Analysis

- **Services with Recovery Issues**: $recovery_issues

### Recommendations:
1. Implement automatic retry mechanisms
2. Add circuit breakers for failing services
3. Improve error handling and logging
4. Add health check recovery logic
5. Implement exponential backoff for retries

EOF
}

# Function to analyze crypto service
analyze_crypto_service() {
    echo -e "\n${BLUE}=== Crypto Service Analysis ===${NC}\n"
    
    analyze_service_logs "fks_crypto"
    
    # Check crypto dependencies
    echo -e "\n${CYAN}Crypto Dependencies:${NC}"
    analyze_service_logs "fks_data"
    analyze_service_logs "fks_auth"
    
    # Check crypto dashboard issues
    local crypto_log="${LOG_DIR}/fks_crypto_${TEST_DATE}.log"
    if [ -f "$crypto_log" ]; then
        local crypto_errors=$(grep -c "|UNHEALTHY|" "$crypto_log" 2>/dev/null || echo "0")
        local crypto_total=$(wc -l < "$crypto_log" 2>/dev/null || echo "0")
        
        if [ "$crypto_total" -gt 0 ]; then
            local failure_rate=$((crypto_errors * 100 / crypto_total))
            
            if [ "$failure_rate" -gt 5 ]; then
                echo -e "  ${RED}⚠ Crypto service has high failure rate: ${failure_rate}%${NC}"
                echo -e "  ${YELLOW}Common crypto dashboard issues:${NC}"
                echo -e "    - Crypto signal API failures"
                echo -e "    - Crypto data dependency issues"
                echo -e "    - Crypto authentication problems"
            fi
        fi
    fi
}

# Main analysis
main() {
    echo -e "${BLUE}Analyzing service logs for Day 4...${NC}\n"
    
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
    
    # Identify specific issues
    identify_ai_service_issues
    identify_dashboard_issues
    analyze_error_recovery
    analyze_crypto_service
    
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

1. Review AI service issues and improve model loading/reliability
2. Fix dashboard issues (database, templates, API endpoints)
3. Improve error recovery mechanisms
4. Address crypto service and dashboard issues
5. Continue monitoring
6. Test fixes applied
7. Document all improvements

## Next Steps

1. Review identified issues
2. Apply fixes for AI service problems
3. Apply fixes for dashboard problems
4. Improve error recovery
5. Fix crypto dashboard issues
6. Continue monitoring
7. Test all fixes
8. Document all changes
9. Prepare stability report

EOF
    
    echo -e "\n${GREEN}✓ Day 4 log analysis complete!${NC}"
}

main
