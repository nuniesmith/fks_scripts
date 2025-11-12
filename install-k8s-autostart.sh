#!/usr/bin/env bash
# Install systemd services to auto-start minikube and K8s dashboard on boot

set -e

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="/home/$USER_NAME"
MINIKUBE_PROFILE="minikube"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_info "Creating systemd service for minikube auto-start..."

# Create minikube systemd service
sudo tee /etc/systemd/system/minikube.service > /dev/null <<EOF
[Unit]
Description=Minikube Kubernetes Cluster
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=$USER_NAME
Group=$USER_NAME
WorkingDirectory=$USER_HOME
Environment="HOME=$USER_HOME"
Environment="KUBECONFIG=$USER_HOME/.kube/config"

# Start minikube with GPU support
ExecStart=/usr/bin/minikube start --cpus=6 --memory=16384 --disk-size=50g --driver=docker --gpus=all --container-runtime=docker

# Stop minikube
ExecStop=/usr/bin/minikube stop

# Check minikube is running
ExecStartPost=/bin/sleep 10
ExecStartPost=/usr/bin/minikube status

[Install]
WantedBy=multi-user.target
EOF

log_info "Creating systemd service for kubectl proxy (dashboard)..."

# Create kubectl proxy systemd service
sudo tee /etc/systemd/system/kubectl-proxy.service > /dev/null <<EOF
[Unit]
Description=Kubectl Proxy for Kubernetes Dashboard
After=minikube.service
Requires=minikube.service

[Service]
Type=simple
User=$USER_NAME
Group=$USER_NAME
WorkingDirectory=$USER_HOME
Environment="HOME=$USER_HOME"
Environment="KUBECONFIG=$USER_HOME/.kube/config"

# Wait for minikube to be ready
ExecStartPre=/bin/sleep 30

# Start kubectl proxy
ExecStart=/usr/bin/kubectl proxy --address=127.0.0.1 --port=8001 --accept-hosts='^localhost$,^127\\.0\\.0\\.1$'

# Stop proxy
ExecStop=/usr/bin/pkill -f "kubectl proxy"

Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

log_info "Reloading systemd daemon..."
sudo systemctl daemon-reload

log_info "Enabling services to start on boot..."
sudo systemctl enable minikube.service
sudo systemctl enable kubectl-proxy.service

log_info "Starting services now..."
sudo systemctl start minikube.service
sleep 15
sudo systemctl start kubectl-proxy.service

echo ""
echo "=============================================="
echo -e "${GREEN}✅ K8s Auto-Start Configured!${NC}"
echo "=============================================="
echo ""
echo "Services installed:"
echo "  - minikube.service (Kubernetes cluster)"
echo "  - kubectl-proxy.service (Dashboard access)"
echo ""
echo "Manage with:"
echo "  sudo systemctl status minikube"
echo "  sudo systemctl status kubectl-proxy"
echo "  sudo systemctl restart minikube"
echo "  sudo systemctl restart kubectl-proxy"
echo ""
echo "Dashboard URL:"
echo "  http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/kubernetes-dashboard:/proxy/"
echo ""
echo "Token location:"
echo "  $USER_HOME/Documents/fks/k8s/dashboard-token.txt"
echo ""
echo "To disable auto-start:"
echo "  sudo systemctl disable minikube"
echo "  sudo systemctl disable kubectl-proxy"
echo ""
