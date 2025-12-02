#!/bin/bash
# 2-Hour Stability Test
# TASK-083: Run system for 2 hours and monitor for crashes

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DURATION_HOURS=2
DURATION_SECONDS=$((DURATION_HOURS * 3600))
CHECK_INTERVAL=60  # Check every 60 seconds
LOG_FILE="stability_test_$(date +%Y%m%d_%H%M%S).log"
SERVICES_FILE="services_registry.json"

echo -e "${BLUE}=== FKS Platform Stability Test ===${NC}"
echo -e "${BLUE}Duration: ${DURATION_HOURS} hours${NC}"
echo -e "${BLUE}Check Interval: ${CHECK_INTERVAL} seconds${NC}"
echo -e "${BLUE}Log File: ${LOG_FILE}${NC}"
echo ""

# Function to check service health
check_service_health() {
    local service_name=$1
    local port=$2
    local health_url=$3
    
    if curl -s --max-time 5 "${health_url}" > /dev/null 2>&1; then
        return 0  # Healthy
    else
        return 1  # Unhealthy
    fi
}

# Function to get service status from Docker
get_docker_status() {
    local service_name=$1
    docker ps --filter "name=${service_name}" --format "{{.Status}}" 2>/dev/null || echo "not_running"
}

# Function to log with timestamp
log_message() {
    local message=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] ${message}" | tee -a "${LOG_FILE}"
}

# Function to check all services
check_all_services() {
    local failed_services=()
    local total_services=0
    local healthy_services=0
    
    log_message "=== Service Health Check ==="
    
    # Read services from registry or use hardcoded list
    declare -A services=(
        ["fks_web"]="8000:http://localhost:8000/health"
        ["fks_api"]="8001:http://localhost:8001/health"
        ["fks_app"]="8002:http://localhost:8002/health"
        ["fks_data"]="8003:http://localhost:8003/health"
        ["fks_execution"]="8004:http://localhost:8004/health"
        ["fks_meta"]="8005:http://localhost:8005/health"
        ["fks_ninja"]="8006:http://localhost:8006/health"
        ["fks_ai"]="8007:http://localhost:8007/health"
        ["fks_auth"]="8009:http://localhost:8009/health"
        ["fks_main"]="8010:http://localhost:8010/health"
        ["fks_training"]="8011:http://localhost:8011/health"
        ["fks_monitor"]="8013:http://localhost:8013/health/health"
        ["fks_crypto"]="8014:http://localhost:8014/health"
        ["fks_futures"]="8015:http://localhost:8015/health"
        ["fks_stocks"]="8016:http://localhost:8016/health"
        ["fks_data_ingestion"]="8020:http://localhost:8020/health"
        ["fks_feature_engineering"]="8021:http://localhost:8021/health"
    )
    
    for service_name in "${!services[@]}"; do
        total_services=$((total_services + 1))
        IFS=':' read -r port health_url <<< "${services[$service_name]}"
        
        # Check Docker status
        docker_status=$(get_docker_status "${service_name}")
        
        # Check health endpoint
        if check_service_health "${service_name}" "${port}" "${health_url}"; then
            healthy_services=$((healthy_services + 1))
            log_message "✓ ${service_name} (${port}): HEALTHY [Docker: ${docker_status}]"
        else
            failed_services+=("${service_name}")
            log_message "✗ ${service_name} (${port}): UNHEALTHY [Docker: ${docker_status}]"
        fi
    done
    
    log_message "Summary: ${healthy_services}/${total_services} services healthy"
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        log_message "Failed services: ${failed_services[*]}"
        return 1
    fi
    
    return 0
}

# Function to check Docker container crashes
check_container_crashes() {
    log_message "=== Checking for Container Crashes ==="
    
    local crashed_containers=$(docker ps -a --filter "status=exited" --filter "status=dead" --format "{{.Names}}" 2>/dev/null || echo "")
    
    if [ -z "${crashed_containers}" ]; then
        log_message "✓ No crashed containers found"
        return 0
    else
        log_message "✗ Crashed containers found: ${crashed_containers}"
        for container in ${crashed_containers}; do
            log_message "  - ${container}: $(docker ps -a --filter "name=${container}" --format "{{.Status}}" 2>/dev/null)"
        done
        return 1
    fi
}

# Function to check system resources
check_system_resources() {
    log_message "=== System Resources Check ==="
    
    # CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    log_message "CPU Usage: ${cpu_usage}%"
    
    # Memory usage
    local mem_info=$(free -h | grep Mem)
    log_message "Memory: ${mem_info}"
    
    # Disk usage
    local disk_usage=$(df -h / | tail -1 | awk '{print $5}')
    log_message "Disk Usage: ${disk_usage}"
    
    # Docker stats
    log_message "Docker Containers: $(docker ps -q | wc -l) running"
}

# Function to check for errors in logs
check_recent_errors() {
    log_message "=== Checking Recent Errors ==="
    
    # Check Docker logs for errors in last 5 minutes
    local error_count=0
    
    for container in $(docker ps --format "{{.Names}}" 2>/dev/null); do
        local errors=$(docker logs --since 5m "${container}" 2>&1 | grep -i "error\|exception\|fatal\|panic" | wc -l)
        if [ "${errors}" -gt 0 ]; then
            log_message "⚠ ${container}: ${errors} errors in last 5 minutes"
            error_count=$((error_count + errors))
        fi
    done
    
    if [ "${error_count}" -eq 0 ]; then
        log_message "✓ No recent errors found"
    else
        log_message "⚠ Total errors found: ${error_count}"
    fi
}

# Main stability test loop
main() {
    local start_time=$(date +%s)
    local end_time=$((start_time + DURATION_SECONDS))
    local check_count=0
    local total_checks=$((DURATION_SECONDS / CHECK_INTERVAL))
    local all_healthy=true
    
    log_message "=== Stability Test Started ==="
    log_message "Start Time: $(date)"
    log_message "End Time: $(date -d "@${end_time}")"
    log_message "Total Checks: ${total_checks}"
    echo ""
    
    # Initial system check
    check_system_resources
    echo ""
    
    # Main monitoring loop
    while [ $(date +%s) -lt ${end_time} ]; do
        check_count=$((check_count + 1))
        local elapsed=$(($(date +%s) - start_time))
        local elapsed_hours=$((elapsed / 3600))
        local elapsed_minutes=$(((elapsed % 3600) / 60))
        
        echo -e "${BLUE}[Check ${check_count}/${total_checks}] Elapsed: ${elapsed_hours}h ${elapsed_minutes}m${NC}"
        
        # Check services
        if ! check_all_services; then
            all_healthy=false
        fi
        echo ""
        
        # Check for crashes
        if ! check_container_crashes; then
            all_healthy=false
        fi
        echo ""
        
        # Check for errors
        check_recent_errors
        echo ""
        
        # Periodic system resource check (every 10 checks)
        if [ $((check_count % 10)) -eq 0 ]; then
            check_system_resources
            echo ""
        fi
        
        # Wait for next check
        if [ $(date +%s) -lt ${end_time} ]; then
            sleep ${CHECK_INTERVAL}
        fi
    done
    
    # Final summary
    log_message "=== Stability Test Completed ==="
    log_message "End Time: $(date)"
    log_message "Total Checks: ${check_count}"
    log_message "Duration: ${DURATION_HOURS} hours"
    
    if [ "${all_healthy}" = true ]; then
        log_message "✓ RESULT: All services remained healthy throughout the test"
        echo -e "${GREEN}✓ Stability test PASSED${NC}"
        return 0
    else
        log_message "✗ RESULT: Some services had issues during the test"
        echo -e "${RED}✗ Stability test FAILED - Check log file: ${LOG_FILE}${NC}"
        return 1
    fi
}

# Run the test
main "$@"
