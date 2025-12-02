#!/bin/bash
# FKS Service Manager - Unified service management utility
# Usage: ./service_manager.sh [command] [service_name]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SERVICE_REGISTRY="$REPO_ROOT/services/config/service_registry.json"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check if service registry exists
if [ ! -f "$SERVICE_REGISTRY" ]; then
    echo -e "${RED}Error: Service registry not found at $SERVICE_REGISTRY${NC}"
    exit 1
fi

# Function to get service info from registry
get_service_info() {
    local service_name=$1
    jq -r ".services.\"$service_name\" | \"\(.name)|\(.port)|\(.base_url)|\(.health_url // \"\")\"" "$SERVICE_REGISTRY" 2>/dev/null
}

# Function to list all services
list_services() {
    echo -e "${BLUE}=== FKS Services ===${NC}"
    echo ""
    jq -r '.services | to_entries[] | "\(.key)|\(.value.name)|\(.value.port)"' "$SERVICE_REGISTRY" | while IFS='|' read -r key name port; do
        echo -e "  ${CYAN}$key${NC} - $name (port $port)"
    done
    echo ""
}

# Function to check service status
check_status() {
    local service_name=$1
    
    if [ -z "$service_name" ]; then
        # Check all services
        echo -e "${BLUE}=== Service Status ===${NC}"
        echo ""
        
        TOTAL=0
        HEALTHY=0
        UNHEALTHY=0
        
        jq -r '.services | to_entries[] | "\(.key)|\(.value.port)|\(.value.health_url // \"\")|\(.value.base_url // \"\")"' "$SERVICE_REGISTRY" | while IFS='|' read -r key port health_url base_url; do
            TOTAL=$((TOTAL + 1))
            echo -n "  ${CYAN}$key${NC}... "
            
            if [ -n "$health_url" ]; then
                if curl -sf --max-time 5 "$health_url" > /dev/null 2>&1; then
                    echo -e "${GREEN}✓ HEALTHY${NC}"
                    HEALTHY=$((HEALTHY + 1))
                else
                    echo -e "${RED}✗ UNHEALTHY${NC}"
                    UNHEALTHY=$((UNHEALTHY + 1))
                fi
            else
                # Try base URL
                if [ -n "$base_url" ]; then
                    if curl -sf --max-time 5 "$base_url/health" > /dev/null 2>&1; then
                        echo -e "${GREEN}✓ HEALTHY${NC}"
                        HEALTHY=$((HEALTHY + 1))
                    else
                        echo -e "${YELLOW}? UNKNOWN${NC}"
                    fi
                else
                    echo -e "${YELLOW}? NO HEALTH URL${NC}"
                fi
            fi
        done
        
        echo ""
        echo -e "${GREEN}Healthy: $HEALTHY${NC} | ${RED}Unhealthy: $UNHEALTHY${NC} | ${YELLOW}Total: $TOTAL${NC}"
    else
        # Check specific service
        local info=$(get_service_info "$service_name")
        if [ -z "$info" ] || [ "$info" = "null|null|null|null" ]; then
            echo -e "${RED}Service '$service_name' not found in registry${NC}"
            exit 1
        fi
        
        IFS='|' read -r name port base_url health_url <<< "$info"
        
        echo -e "${BLUE}=== $service_name Status ===${NC}"
        echo "  Name: $name"
        echo "  Port: $port"
        echo "  Base URL: $base_url"
        echo "  Health URL: ${health_url:-N/A}"
        echo ""
        
        if [ -n "$health_url" ]; then
            echo -n "  Health Check: "
            if curl -sf --max-time 5 "$health_url" > /dev/null 2>&1; then
                echo -e "${GREEN}✓ HEALTHY${NC}"
                # Get health response
                response=$(curl -s --max-time 5 "$health_url" 2>/dev/null)
                echo "  Response: $response" | head -3
            else
                echo -e "${RED}✗ UNHEALTHY${NC}"
            fi
        fi
    fi
}

# Function to start service
start_service() {
    local service_name=$1
    
    if [ -z "$service_name" ]; then
        echo -e "${RED}Error: Service name required${NC}"
        echo "Usage: $0 start <service_name>"
        exit 1
    fi
    
    echo -e "${BLUE}Starting $service_name...${NC}"
    
    # Try docker compose
    if command -v docker-compose >/dev/null 2>&1 || command -v docker >/dev/null 2>&1; then
        if [ -f "$REPO_ROOT/docker-compose.yml" ]; then
            docker compose up -d "$service_name" 2>&1 || {
                echo -e "${YELLOW}Note: Service may use different naming convention${NC}"
            }
        else
            echo -e "${YELLOW}docker-compose.yml not found in repo root${NC}"
        fi
    else
        echo -e "${RED}Docker not available${NC}"
        exit 1
    fi
    
    # Wait and check status
    sleep 2
    check_status "$service_name"
}

# Function to stop service
stop_service() {
    local service_name=$1
    
    if [ -z "$service_name" ]; then
        echo -e "${RED}Error: Service name required${NC}"
        echo "Usage: $0 stop <service_name>"
        exit 1
    fi
    
    echo -e "${BLUE}Stopping $service_name...${NC}"
    
    if command -v docker-compose >/dev/null 2>&1 || command -v docker >/dev/null 2>&1; then
        if [ -f "$REPO_ROOT/docker-compose.yml" ]; then
            docker compose stop "$service_name" 2>&1 || {
                echo -e "${YELLOW}Note: Service may use different naming convention${NC}"
            }
        fi
    fi
    
    echo -e "${GREEN}Service stopped${NC}"
}

# Function to restart service
restart_service() {
    local service_name=$1
    
    if [ -z "$service_name" ]; then
        echo -e "${RED}Error: Service name required${NC}"
        echo "Usage: $0 restart <service_name>"
        exit 1
    fi
    
    echo -e "${BLUE}Restarting $service_name...${NC}"
    stop_service "$service_name"
    sleep 1
    start_service "$service_name"
}

# Function to show service logs
show_logs() {
    local service_name=$1
    local lines=${2:-50}
    
    if [ -z "$service_name" ]; then
        echo -e "${RED}Error: Service name required${NC}"
        echo "Usage: $0 logs <service_name> [lines]"
        exit 1
    fi
    
    echo -e "${BLUE}=== $service_name Logs (last $lines lines) ===${NC}"
    
    if command -v docker >/dev/null 2>&1; then
        docker logs --tail "$lines" "$service_name" 2>&1 || {
            # Try with fks- prefix
            docker logs --tail "$lines" "fks-$service_name" 2>&1 || {
                docker logs --tail "$lines" "fks_$service_name" 2>&1 || {
                    echo -e "${RED}Could not find container for $service_name${NC}"
                    echo "Available containers:"
                    docker ps --format "{{.Names}}" | grep -i fks | head -10
                }
            }
        }
    else
        echo -e "${RED}Docker not available${NC}"
        exit 1
    fi
}

# Function to show service info
show_info() {
    local service_name=$1
    
    if [ -z "$service_name" ]; then
        echo -e "${RED}Error: Service name required${NC}"
        echo "Usage: $0 info <service_name>"
        exit 1
    fi
    
    local info=$(get_service_info "$service_name")
    if [ -z "$info" ] || [ "$info" = "null|null|null|null" ]; then
        echo -e "${RED}Service '$service_name' not found in registry${NC}"
        exit 1
    fi
    
    IFS='|' read -r name port base_url health_url <<< "$info"
    
    echo -e "${BLUE}=== $service_name Information ===${NC}"
    echo "  Name: $name"
    echo "  Port: $port"
    echo "  Base URL: $base_url"
    echo "  Health URL: ${health_url:-N/A}"
    
    # Get dependencies
    local deps=$(jq -r ".services.\"$service_name\".dependencies[]?" "$SERVICE_REGISTRY" 2>/dev/null | tr '\n' ', ' | sed 's/, $//')
    if [ -n "$deps" ]; then
        echo "  Dependencies: $deps"
    fi
    
    # Get databases
    local dbs=$(jq -r ".services.\"$service_name\".databases[]?.name" "$SERVICE_REGISTRY" 2>/dev/null | tr '\n' ', ' | sed 's/, $//')
    if [ -n "$dbs" ]; then
        echo "  Databases: $dbs"
    fi
    
    # Get note
    local note=$(jq -r ".services.\"$service_name\".note // \"\"" "$SERVICE_REGISTRY" 2>/dev/null)
    if [ -n "$note" ]; then
        echo "  Note: $note"
    fi
}

# Main command handler
case "${1:-}" in
    list)
        list_services
        ;;
    status|check)
        check_status "${2:-}"
        ;;
    start)
        start_service "${2:-}"
        ;;
    stop)
        stop_service "${2:-}"
        ;;
    restart)
        restart_service "${2:-}"
        ;;
    logs)
        show_logs "${2:-}" "${3:-50}"
        ;;
    info)
        show_info "${2:-}"
        ;;
    *)
        echo -e "${BLUE}=== FKS Service Manager ===${NC}"
        echo ""
        echo "Usage: $0 <command> [service_name]"
        echo ""
        echo "Commands:"
        echo "  list              - List all services"
        echo "  status [service]  - Check service status (all or specific)"
        echo "  start <service>   - Start a service"
        echo "  stop <service>    - Stop a service"
        echo "  restart <service> - Restart a service"
        echo "  logs <service>    - Show service logs"
        echo "  info <service>    - Show service information"
        echo ""
        echo "Examples:"
        echo "  $0 list"
        echo "  $0 status"
        echo "  $0 status fks_web"
        echo "  $0 start fks_web"
        echo "  $0 logs fks_web 100"
        echo "  $0 info fks_data"
        exit 1
        ;;
esac
