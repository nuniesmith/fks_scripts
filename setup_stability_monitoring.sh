#!/bin/bash
# Setup Monitoring and Alerting for Stability Test
# Configures monitoring tools and alerting for 7-day stability test

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
MONITOR_CONFIG_DIR="${STABILITY_TEST_DIR}/monitoring"

echo -e "${BLUE}=== Setting Up Stability Test Monitoring ===${NC}\n"

# Create directories
mkdir -p "$MONITOR_CONFIG_DIR" "$STABILITY_TEST_DIR/logs" "$STABILITY_TEST_DIR/reports"

# Function to check if service is available
check_service_available() {
    local service_name=$1
    local port=$2
    
    if curl -sf --max-time 2 "http://localhost:${port}/health" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to create monitoring configuration
create_monitoring_config() {
    local config_file="${MONITOR_CONFIG_DIR}/monitoring_config.json"
    
    echo -e "${CYAN}Creating monitoring configuration...${NC}"
    
    cat > "$config_file" <<EOF
{
  "test_start_date": "$(date +%Y-%m-%d)",
  "test_duration_days": 7,
  "check_interval_seconds": 300,
  "alerting": {
    "enabled": true,
    "channels": {
      "discord": {
        "enabled": false,
        "webhook_url": "${DISCORD_WEBHOOK_URL:-}"
      },
      "email": {
        "enabled": false,
        "recipients": []
      },
      "log": {
        "enabled": true,
        "log_file": "${STABILITY_TEST_DIR}/logs/alerts.log"
      }
    },
    "thresholds": {
      "service_down_minutes": 5,
      "error_rate_percent": 10,
      "response_time_ms": 5000
    }
  },
  "services": {
EOF

    # Extract services from registry
    local services=$(jq -r '.services | keys[]' "$SERVICE_REGISTRY" 2>/dev/null || echo "")
    local first=true
    
    for service in $services; do
        local port=$(jq -r ".services[\"$service\"].port" "$SERVICE_REGISTRY" 2>/dev/null)
        local health_url=$(jq -r ".services[\"$service\"].health_url" "$SERVICE_REGISTRY" 2>/dev/null)
        
        if [ "$port" != "null" ] && [ "$health_url" != "null" ]; then
            if [ "$first" = true ]; then
                first=false
            else
                echo "," >> "$config_file"
            fi
            
            # Check if service is crypto-specific
            local is_crypto=false
            if [ "$service" == "fks_crypto" ]; then
                is_crypto=true
            fi
            
            cat >> "$config_file" <<EOF
    "$service": {
      "port": $port,
      "health_url": "$health_url",
      "monitoring_enabled": true,
      "crypto_specific": $is_crypto,
      "dependencies": $(jq -c ".services[\"$service\"].dependencies // []" "$SERVICE_REGISTRY")
    }
EOF
        fi
    done
    
    cat >> "$config_file" <<EOF
  }
}
EOF
    
    echo -e "${GREEN}✓ Monitoring configuration created${NC}"
}

# Function to create alerting script
create_alerting_script() {
    local script_file="${MONITOR_CONFIG_DIR}/send_alert.sh"
    
    echo -e "${CYAN}Creating alerting script...${NC}"
    
    cat > "$script_file" <<'EOF'
#!/bin/bash
# Send alert for stability test issues
# Usage: ./send_alert.sh <severity> <message>

SEVERITY=$1
MESSAGE=$2
TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%S)

# Log alert
echo "[$TIMESTAMP] [$SEVERITY] $MESSAGE" >> "${STABILITY_TEST_DIR}/logs/alerts.log"

# Send to Discord if configured
if [ -n "$DISCORD_WEBHOOK_URL" ] && [ "$SEVERITY" == "CRITICAL" ]; then
    curl -H "Content-Type: application/json" \
         -d "{\"content\": \"🚨 **Stability Test Alert**\n**Severity**: $SEVERITY\n**Time**: $TIMESTAMP\n**Message**: $MESSAGE\"}" \
         "$DISCORD_WEBHOOK_URL" 2>/dev/null || true
fi

# Print alert
case "$SEVERITY" in
    CRITICAL)
        echo -e "\033[0;31m[CRITICAL] $MESSAGE\033[0m"
        ;;
    WARNING)
        echo -e "\033[1;33m[WARNING] $MESSAGE\033[0m"
        ;;
    INFO)
        echo -e "\033[0;34m[INFO] $MESSAGE\033[0m"
        ;;
esac
EOF
    
    chmod +x "$script_file"
    echo -e "${GREEN}✓ Alerting script created${NC}"
}

# Function to verify monitoring setup
verify_monitoring() {
    echo -e "\n${CYAN}Verifying monitoring setup...${NC}"
    
    local all_ok=true
    
    # Check service registry
    if [ ! -f "$SERVICE_REGISTRY" ]; then
        echo -e "${RED}✗ Service registry not found${NC}"
        all_ok=false
    else
        echo -e "${GREEN}✓ Service registry found${NC}"
    fi
    
    # Check monitoring config
    if [ ! -f "${MONITOR_CONFIG_DIR}/monitoring_config.json" ]; then
        echo -e "${RED}✗ Monitoring config not found${NC}"
        all_ok=false
    else
        echo -e "${GREEN}✓ Monitoring config found${NC}"
    fi
    
    # Check alerting script
    if [ ! -f "${MONITOR_CONFIG_DIR}/send_alert.sh" ]; then
        echo -e "${RED}✗ Alerting script not found${NC}"
        all_ok=false
    else
        echo -e "${GREEN}✓ Alerting script found${NC}"
    fi
    
    # Check fks_monitor service
    if check_service_available "fks_monitor" 8013; then
        echo -e "${GREEN}✓ fks_monitor service is running${NC}"
    else
        echo -e "${YELLOW}⚠ fks_monitor service is not running (optional)${NC}"
    fi
    
    # Check fks_crypto service
    if check_service_available "fks_crypto" 8014; then
        echo -e "${GREEN}✓ fks_crypto service is running${NC}"
    else
        echo -e "${YELLOW}⚠ fks_crypto service is not running${NC}"
    fi
    
    if [ "$all_ok" = true ]; then
        echo -e "\n${GREEN}✓ Monitoring setup complete!${NC}"
        return 0
    else
        echo -e "\n${RED}✗ Some monitoring components are missing${NC}"
        return 1
    fi
}

# Main setup
main() {
    create_monitoring_config
    create_alerting_script
    verify_monitoring
    
    echo -e "\n${BLUE}=== Monitoring Setup Summary ===${NC}"
    echo -e "Configuration directory: ${CYAN}$MONITOR_CONFIG_DIR${NC}"
    echo -e "Log directory: ${CYAN}${STABILITY_TEST_DIR}/logs${NC}"
    echo -e "Report directory: ${CYAN}${STABILITY_TEST_DIR}/reports${NC}"
    echo -e "\n${GREEN}Ready to start stability test!${NC}"
    echo -e "Run: ${CYAN}./stability_test.sh${NC}"
}

main
