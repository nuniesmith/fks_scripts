#!/bin/bash
# Update all service workflows to include deployment step
# Usage: ./update-all-workflows.sh

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Services to update
SERVICES=(
    "ai:deployment:fks-ai:ai"
    "analyze:deployment:fks-analyze:analyze"
    "api:deployment:fks-api:api"
    "app:deployment:fks-app:app"
    "auth:deployment:fks-auth:auth"
    "data:deployment:fks-data:data"
    "execution:deployment:fks-execution:execution"
    "main:deployment:fks-main:main"
    "meta:deployment:fks-meta:meta"
    "monitor:deployment:fks-monitor:monitor"
    "ninja:deployment:fks-ninja:ninja"
    "portfolio:deployment:fks-portfolio:portfolio"
    "training:deployment:fks-training:training"
    "web:deployment:fks-web:web"
    "nginx:deployment:fks-nginx:nginx"
    "tailscale:statefulset:tailscale-connector:tailscale"
)

echo "🔄 Updating workflows for all services..."
echo ""

for service_config in "${SERVICES[@]}"; do
    IFS=':' read -r service_name resource_type deployment_name container_name <<< "$service_config"
    
    SERVICE_DIR="$REPO_ROOT/$service_name"
    WORKFLOW_FILE="$SERVICE_DIR/.github/workflows/docker-build-push.yml"
    
    if [ ! -d "$SERVICE_DIR" ]; then
        echo "⚠️  Service directory not found: $SERVICE_DIR"
        continue
    fi
    
    if [ ! -f "$WORKFLOW_FILE" ]; then
        echo "⚠️  Workflow file not found: $WORKFLOW_FILE"
        continue
    fi
    
    echo "📋 Updating $service_name..."
    
    # Check if deployment step already exists
    if grep -q "Deploy to Kubernetes" "$WORKFLOW_FILE"; then
        echo "   ⚠️  Deployment step already exists, skipping..."
        continue
    fi
    
    # Add deployment step using the script
    cd "$SERVICE_DIR"
    "$SCRIPT_DIR/add-deployment-step.sh" "$service_name" "$deployment_name" "$container_name" "$resource_type"
    
    echo "   ✅ Updated $service_name"
    echo ""
done

echo "✅ All workflows updated!"
echo ""
echo "📋 Next steps:"
echo "   1. Review the changes in each service repository"
echo "   2. Add secrets to each repository:"
echo "      - SSH_PRIVATE_KEY"
echo "      - K8S_SSH_KEY (optional)"
echo "      - K8S_HOST (optional)"
echo "   3. Commit and push changes"
echo "   4. Test the workflows"
echo ""

