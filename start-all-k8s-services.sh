#!/bin/bash
# Start All K8s Services - Simple Version
# Uses run.sh if available, otherwise uses kubectl directly

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_SCRIPT="$PROJECT_ROOT/run.sh"

echo ""
echo "╔═══════════════════════════════════════════════╗"
echo "║  FKS Platform - Start All K8s Services       ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""

# Check if run.sh exists and use it
if [ -f "$RUN_SCRIPT" ]; then
    echo -e "${CYAN}Using run.sh script for deployment...${NC}"
    echo ""
    
    # Check if script is executable
    if [ ! -x "$RUN_SCRIPT" ]; then
        chmod +x "$RUN_SCRIPT"
    fi
    
    # Run the Kubernetes start option
    cd "$PROJECT_ROOT"
    
    echo -e "${BLUE}Starting Kubernetes deployment via run.sh...${NC}"
    echo -e "${YELLOW}Note: This will start minikube and deploy all services${NC}"
    echo ""
    
    # Use run.sh option 8 (Kubernetes Start)
    # We'll need to provide input to the script
    echo "8" | "$RUN_SCRIPT" || {
        echo -e "${YELLOW}⚠️  run.sh may require interactive input. Trying direct deployment...${NC}"
        
        # Try to start minikube directly
        if command -v minikube &> /dev/null; then
            echo -e "${BLUE}Starting minikube...${NC}"
            minikube start --cpus=6 --memory=16384 --disk-size=50g --driver=docker || {
                echo -e "${YELLOW}Minikube may already be running or needs manual start${NC}"
            }
            
            # Enable addons
            minikube addons enable ingress || true
            minikube addons enable metrics-server || true
            minikube addons enable dashboard || true
            
            # Check if we can deploy with kubectl directly
            echo -e "${BLUE}Checking for existing deployments...${NC}"
            kubectl get namespace fks-trading 2>/dev/null || kubectl create namespace fks-trading
            
            echo -e "${YELLOW}⚠️  Helm is required for full deployment. Please install Helm:${NC}"
            echo "  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
            echo ""
            echo -e "${YELLOW}Or use run.sh option 8 (Kubernetes Start) which handles Helm installation${NC}"
            exit 1
        else
            echo -e "${YELLOW}⚠️  minikube is not installed. Please install minikube first${NC}"
            exit 1
        fi
    }
else
    echo -e "${YELLOW}⚠️  run.sh not found. Checking for direct kubectl deployment...${NC}"
    echo ""
    
    # Check for minikube
    if command -v minikube &> /dev/null; then
        echo -e "${BLUE}Starting minikube...${NC}"
        minikube start --cpus=6 --memory=16384 --disk-size=50g --driver=docker || {
            echo -e "${YELLOW}Minikube may already be running${NC}"
        }
        
        # Enable addons
        minikube addons enable ingress || true
        minikube addons enable metrics-server || true
        minikube addons enable dashboard || true
        
        # Check for Helm
        if command -v helm &> /dev/null; then
            echo -e "${BLUE}Helm found. Deploying services...${NC}"
            cd "$PROJECT_ROOT/k8s"
            helm upgrade --install fks-platform ./charts/fks-platform \
                --namespace fks-trading \
                --create-namespace \
                --set fks_main.enabled=true \
                --set fks_api.enabled=true \
                --set fks_app.enabled=true \
                --set fks_data.enabled=true \
                --set fks_auth.enabled=true \
                --set fks_portfolio.enabled=true \
                --set fks_monitor.enabled=true \
                --set fks_meta.enabled=true \
                --set fks_analyze.enabled=true \
                --set fks_training.enabled=true \
                --set fks_execution.enabled=true \
                --set fks_ai.enabled=false \
                --set fks_web.enabled=false \
                --set fks_ninja.enabled=false \
                --set postgresql.enabled=true \
                --set redis.enabled=true \
                --set ingress.enabled=false \
                --wait \
                --timeout 15m
        else
            echo -e "${YELLOW}⚠️  Helm is not installed. Please install Helm:${NC}"
            echo "  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
            echo ""
            echo -e "${YELLOW}Or use run.sh which handles Helm installation${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}⚠️  minikube is not installed. Please install minikube first${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Deployment Complete!                        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
echo ""

# Show status
echo -e "${BLUE}Checking pod status...${NC}"
kubectl get pods -n fks-trading -o wide 2>/dev/null || echo -e "${YELLOW}No pods found in fks-trading namespace${NC}"

echo ""
echo -e "${CYAN}To check status:${NC}"
echo "  kubectl get pods -n fks-trading"
echo "  kubectl get svc -n fks-trading"
echo "  kubectl get deployments -n fks-trading"
echo ""
echo -e "${CYAN}To view logs:${NC}"
echo "  kubectl logs -n fks-trading -l app=fks-app -f"
echo "  kubectl logs -n fks-trading -l app=fks-data -f"
echo "  kubectl logs -n fks-trading -l app=fks-main -f"
echo ""
echo -e "${CYAN}To access dashboard:${NC}"
echo "  ./scripts/dashboard-auto-login.sh"
echo ""

