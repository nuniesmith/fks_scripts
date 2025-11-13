#!/bin/bash
# Add deployment step to existing docker-build-push.yml workflow
# Usage: ./add-deployment-step.sh <service-name> [deployment-name] [container-name] [resource-type]

set -e

SERVICE_NAME="${1:-}"
DEPLOYMENT_NAME="${2:-}"
CONTAINER_NAME="${3:-}"
RESOURCE_TYPE="${4:-deployment}"  # deployment or statefulset

if [ -z "$SERVICE_NAME" ]; then
    echo "Usage: $0 <service-name> [deployment-name] [container-name] [resource-type]"
    echo "   Example: $0 api"
    echo "   Example: $0 tailscale tailscale-connector tailscale statefulset"
    exit 1
fi

# Set defaults
if [ -z "$DEPLOYMENT_NAME" ]; then
    DEPLOYMENT_NAME="fks-$SERVICE_NAME"
fi
if [ -z "$CONTAINER_NAME" ]; then
    CONTAINER_NAME="$DEPLOYMENT_NAME"
fi

WORKFLOW_FILE=".github/workflows/docker-build-push.yml"

if [ ! -f "$WORKFLOW_FILE" ]; then
    echo "❌ Workflow file not found: $WORKFLOW_FILE"
    exit 1
fi

# Check if deployment step already exists
if grep -q "Deploy to Kubernetes" "$WORKFLOW_FILE"; then
    echo "⚠️  Deployment step already exists in $WORKFLOW_FILE"
    read -p "Replace it? (y/N): " REPLACE
    if [[ ! "$REPLACE" =~ ^[Yy]$ ]]; then
        echo "❌ Aborted"
        exit 1
    fi
    # Remove existing deployment step
    sed -i '/- name: Deploy to Kubernetes/,/^$/d' "$WORKFLOW_FILE"
fi

# Create deployment step
DEPLOY_STEP=$(cat << EOF
      - name: Deploy to Kubernetes
        if: success()
        run: |
          # Configure SSH
          mkdir -p ~/.ssh
          chmod 700 ~/.ssh
          echo "\${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/jump_key
          chmod 600 ~/.ssh/jump_key
          
          # Add jump server to known hosts
          ssh-keyscan -H github.fkstrading.xyz >> ~/.ssh/known_hosts 2>/dev/null || true
          
          # Configuration
          SERVICE_NAME="$SERVICE_NAME"
          IMAGE="\${{ env.DOCKER_REPO }}:\${{ env.SERVICE_NAME }}-latest"
          NAMESPACE="fks-trading"
          DEPLOYMENT_NAME="$DEPLOYMENT_NAME"
          CONTAINER_NAME="$CONTAINER_NAME"
          JUMP_SERVER="github.fkstrading.xyz"
          JUMP_USER="github-actions"
          K8S_HOST="\${{ secrets.K8S_HOST }}"
          K8S_USER="github-actions"
          
          echo "🚀 Deploying \$SERVICE_NAME to Kubernetes"
          echo "   Image: \$IMAGE"
          echo "   Deployment: \$DEPLOYMENT_NAME"
          echo "   Namespace: \$NAMESPACE"
          
          # Function to run kubectl command
          run_kubectl() {
            local cmd="\$1"
            if [ -n "\$K8S_HOST" ]; then
              # Setup K8s SSH key if provided
              if [ -n "\${{ secrets.K8S_SSH_KEY }}" ]; then
                echo "\${{ secrets.K8S_SSH_KEY }}" > ~/.ssh/k8s_key
                chmod 600 ~/.ssh/k8s_key
                K8S_KEY_FILE="~/.ssh/k8s_key"
              else
                K8S_KEY_FILE="~/.ssh/jump_key"
              fi
              # SSH into K8s server via jump server
              ssh -i \$K8S_KEY_FILE -o ProxyJump=\$JUMP_USER@\$JUMP_SERVER -o StrictHostKeyChecking=no \$K8S_USER@\$K8S_HOST "\$cmd"
            else
              # Run kubectl on jump server
              ssh -i ~/.ssh/jump_key -o StrictHostKeyChecking=no \$JUMP_USER@\$JUMP_SERVER "\$cmd"
            fi
          }
          
          # Check if $RESOURCE_TYPE exists
          echo "📋 Checking if $RESOURCE_TYPE exists..."
          if run_kubectl "kubectl get $RESOURCE_TYPE \$DEPLOYMENT_NAME -n \$NAMESPACE" > /dev/null 2>&1; then
            echo "✅ $RESOURCE_TYPE \$DEPLOYMENT_NAME exists"
            
            # Get current image
            CURRENT_IMAGE=\$(run_kubectl "kubectl get $RESOURCE_TYPE \$DEPLOYMENT_NAME -n \$NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].image}'" 2>/dev/null || echo "")
            if [ -n "\$CURRENT_IMAGE" ]; then
              echo "   Current image: \$CURRENT_IMAGE"
            fi
            echo "   New image: \$IMAGE"
            
            # Update $RESOURCE_TYPE
            echo "🔄 Updating $RESOURCE_TYPE..."
            if run_kubectl "kubectl set image $RESOURCE_TYPE/\$DEPLOYMENT_NAME \$CONTAINER_NAME=\$IMAGE -n \$NAMESPACE"; then
              echo "✅ Image updated"
            else
              echo "⚠️  Failed to update image, trying alternative method..."
              PATCH_JSON="{\\\"spec\\\":{\\\"template\\\":{\\\"spec\\\":{\\\"containers\\\":[{\\\"name\\\":\\\"\$CONTAINER_NAME\\\",\\\"image\\\":\\\"\$IMAGE\\\"}]}}}}"
              if run_kubectl "kubectl patch $RESOURCE_TYPE \$DEPLOYMENT_NAME -n \$NAMESPACE -p '\$PATCH_JSON'"; then
                echo "✅ Image updated via patch"
              else
                echo "❌ Failed to update $RESOURCE_TYPE"
                exit 1
              fi
            fi
            
            # Restart $RESOURCE_TYPE
            echo "🔄 Restarting $RESOURCE_TYPE..."
            run_kubectl "kubectl rollout restart $RESOURCE_TYPE/\$DEPLOYMENT_NAME -n \$NAMESPACE" || echo "⚠️  Failed to restart $RESOURCE_TYPE"
            
            # Wait for rollout
            echo "⏳ Waiting for rollout to complete..."
            run_kubectl "kubectl rollout status $RESOURCE_TYPE/\$DEPLOYMENT_NAME -n \$NAMESPACE --timeout=300s" || echo "⚠️  Rollout timeout"
            
            # Show status
            echo ""
            echo "📊 $RESOURCE_TYPE status:"
            run_kubectl "kubectl get $RESOURCE_TYPE \$DEPLOYMENT_NAME -n \$NAMESPACE"
            echo ""
            echo "📊 Pod status:"
            run_kubectl "kubectl get pods -n \$NAMESPACE -l app=\$SERVICE_NAME" || \
            run_kubectl "kubectl get pods -n \$NAMESPACE | grep \$SERVICE_NAME" || \
            echo "   (No pods found)"
          else
            echo "❌ $RESOURCE_TYPE \$DEPLOYMENT_NAME not found in namespace \$NAMESPACE"
            echo "Available $RESOURCE_TYPE:"
            run_kubectl "kubectl get ${RESOURCE_TYPE}s -n \$NAMESPACE" || true
            exit 1
          fi
          
          echo "✅ Deployment complete!"

EOF
)

# Add deployment step after "Image digest" step
if grep -q "Image digest" "$WORKFLOW_FILE"; then
    # Insert after "Image digest" step
    awk -v deploy_step="$DEPLOY_STEP" '
      /- name: Image digest/ {
        print
        getline
        print
        print deploy_step
        next
      }
      { print }
    ' "$WORKFLOW_FILE" > "$WORKFLOW_FILE.tmp" && mv "$WORKFLOW_FILE.tmp" "$WORKFLOW_FILE"
else
    # Append to end of build-and-push job
    sed -i '/      - name: Image digest/,/^$/a\
'"$DEPLOY_STEP" "$WORKFLOW_FILE"
fi

echo "✅ Added deployment step to $WORKFLOW_FILE"
echo ""
echo "📋 Next steps:"
echo "   1. Add secrets to GitHub repository:"
echo "      - SSH_PRIVATE_KEY (required)"
echo "      - K8S_SSH_KEY (optional, uses SSH_PRIVATE_KEY if not set)"
echo "      - K8S_HOST (optional, Tailscale IP of K8s server)"
echo ""
echo "   2. Commit and push changes"
echo "   3. Test the workflow"
echo ""

