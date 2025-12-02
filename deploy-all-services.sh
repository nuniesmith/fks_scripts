#!/bin/bash
# Deploy All K8s Services - Simple Version
# Uses run.sh for deployment (which handles minikube and helm installation)

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_SCRIPT="$PROJECT_ROOT/run.sh"

echo ""
echo "╔═══════════════════════════════════════════════╗"
echo "║  FKS Platform - Deploy All 14 Services        ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""

# Check if run.sh exists
if [ ! -f "$RUN_SCRIPT" ]; then
    echo -e "${RED}❌ run.sh not found at $RUN_SCRIPT${NC}"
    echo ""
    echo -e "${YELLOW}Please run this script from repo/main directory${NC}"
    exit 1
fi

# Check if script is executable
if [ ! -x "$RUN_SCRIPT" ]; then
    echo -e "${BLUE}Making run.sh executable...${NC}"
    chmod +x "$RUN_SCRIPT"
fi

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed${NC}"
    echo ""
    echo -e "${YELLOW}Please install kubectl first:${NC}"
    echo "  https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

echo -e "${CYAN}Using run.sh for deployment...${NC}"
echo ""
echo -e "${BLUE}The run.sh script will:${NC}"
echo "  1. Check/install minikube (if needed)"
echo "  2. Start minikube cluster"
echo "  3. Pull images from Docker Hub"
echo "  4. Deploy all 14 services using Helm"
echo ""
echo -e "${YELLOW}Note: This may take 10-15 minutes${NC}"
echo ""

# Change to project root
cd "$PROJECT_ROOT"

# Check if cluster is already running
if kubectl cluster-info &> /dev/null 2>&1; then
    echo -e "${GREEN}✅ Kubernetes cluster is already running${NC}"
    echo ""
    echo -e "${BLUE}Current cluster status:${NC}"
    kubectl cluster-info | head -n 1
    echo ""
    
    # Check if namespace exists
    if kubectl get namespace fks-trading &> /dev/null 2>&1; then
        echo -e "${GREEN}✅ Namespace fks-trading exists${NC}"
        echo ""
        echo -e "${BLUE}Current pod status:${NC}"
        kubectl get pods -n fks-trading 2>/dev/null || echo -e "${YELLOW}No pods found in fks-trading namespace${NC}"
        echo ""
        
        # Ask if user wants to redeploy
        echo -e "${YELLOW}Do you want to redeploy all services? (y/n):${NC} "
        read -r redeploy_choice
        if [ "$redeploy_choice" != "y" ] && [ "$redeploy_choice" != "Y" ]; then
            echo -e "${BLUE}Skipping deployment. To redeploy later, run:${NC}"
            echo "  ./scripts/deploy-all-services.sh"
            echo ""
            echo -e "${CYAN}To check status:${NC}"
            echo "  kubectl get pods -n fks-trading"
            echo "  kubectl get svc -n fks-trading"
            echo "  kubectl get deployments -n fks-trading"
            exit 0
        fi
    fi
else
    echo -e "${YELLOW}⚠️  Kubernetes cluster is not running${NC}"
    echo ""
    echo -e "${BLUE}The run.sh script will start minikube for you${NC}"
    echo ""
fi

# Run run.sh option 8 (Kubernetes Start)
echo -e "${CYAN}Starting deployment via run.sh...${NC}"
echo ""
echo -e "${YELLOW}When prompted:${NC}"
echo "  - Choose option 8 (Kubernetes Start)"
echo "  - Choose 'p' to pull images from Docker Hub"
echo "  - Enter namespace: fks-trading (or press Enter for default)"
echo ""

# Create a simple wrapper script that provides input to run.sh
cat > /tmp/run-k8s.sh <<'EOF'
#!/bin/bash
# Wrapper script to run Kubernetes deployment

cd "$PROJECT_ROOT"

# Create input file for run.sh
echo "8" > /tmp/run-input.txt
echo "p" >> /tmp/run-input.txt
echo "" >> /tmp/run-input.txt  # Default namespace

# Run run.sh with input
"$RUN_SCRIPT" < /tmp/run-input.txt
EOF

chmod +x /tmp/run-k8s.sh

# Try to run, but if it fails, provide manual instructions
if bash /tmp/run-k8s.sh; then
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Deployment Complete!                        ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
    echo ""
else
    echo ""
    echo -e "${YELLOW}⚠️  Automated deployment failed. Please run manually:${NC}"
    echo ""
    echo -e "${CYAN}Manual deployment steps:${NC}"
    echo ""
    echo "1. Run run.sh:"
    echo "   cd $PROJECT_ROOT"
    echo "   ./run.sh"
    echo ""
    echo "2. Choose option 8 (Kubernetes Start)"
    echo ""
    echo "3. Choose 'p' to pull images from Docker Hub"
    echo ""
    echo "4. Enter namespace: fks-trading (or press Enter for default)"
    echo ""
    echo "5. Wait for deployment to complete"
    echo ""
    exit 1
fi

# Clean up
rm -f /tmp/run-k8s.sh /tmp/run-input.txt

# Show status
echo -e "${BLUE}Checking deployment status...${NC}"
echo ""

# Wait a bit for pods to start
sleep 5

# Show pod status
echo -e "${CYAN}Pod Status:${NC}"
kubectl get pods -n fks-trading -o wide 2>/dev/null || echo -e "${YELLOW}No pods found in fks-trading namespace${NC}"
echo ""

# Show service status
echo -e "${CYAN}Service Status:${NC}"
kubectl get svc -n fks-trading -o wide 2>/dev/null || echo -e "${YELLOW}No services found in fks-trading namespace${NC}"
echo ""

# Show deployment status
echo -e "${CYAN}Deployment Status:${NC}"
kubectl get deployments -n fks-trading -o wide 2>/dev/null || echo -e "${YELLOW}No deployments found in fks-trading namespace${NC}"
echo ""

# Show ingress status
echo -e "${CYAN}Ingress Status:${NC}"
kubectl get ingress -n fks-trading -o wide 2>/dev/null || echo -e "${YELLOW}No ingress found in fks-trading namespace${NC}"
echo ""

echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Deployment Complete!                        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}Useful commands:${NC}"
echo ""
echo "  Check pods:"
echo "    kubectl get pods -n fks-trading"
echo ""
echo "  Check services:"
echo "    kubectl get svc -n fks-trading"
echo ""
echo "  View logs:"
echo "    kubectl logs -n fks-trading -l app=fks-app -f"
echo "    kubectl logs -n fks-trading -l app=fks-data -f"
echo "    kubectl logs -n fks-trading -l app=fks-main -f"
echo ""
echo "  Access dashboard:"
echo "    ./scripts/dashboard-auto-login.sh"
echo ""
echo "  Port-forward services:"
echo "    kubectl port-forward -n fks-trading svc/fks-app 8002:8002 &"
echo "    kubectl port-forward -n fks-trading svc/fks-data 8003:8003 &"
echo "    kubectl port-forward -n fks-trading svc/fks-main 8010:8010 &"
echo "    kubectl port-forward -n fks-trading svc/fks-api 8001:8001 &"
echo ""
echo -e "${CYAN}To check pod health:${NC}"
echo "  kubectl get pods -n fks-trading -o wide"
echo "  kubectl describe pod <pod-name> -n fks-trading"
echo ""
echo -e "${CYAN}To restart a pod:${NC}"
echo "  kubectl delete pod <pod-name> -n fks-trading"
echo ""

