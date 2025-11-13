#!/bin/bash
# Create deployment workflow for a service
# Usage: ./create-deployment-workflow.sh <service-name> [deployment-name] [container-name]

set -e

SERVICE_NAME="${1:-}"
DEPLOYMENT_NAME="${2:-}"
CONTAINER_NAME="${3:-}"

if [ -z "$SERVICE_NAME" ]; then
    echo "Usage: $0 <service-name> [deployment-name] [container-name]"
    echo "   Example: $0 api fks-api api"
    exit 1
fi

# Set defaults
if [ -z "$DEPLOYMENT_NAME" ]; then
    DEPLOYMENT_NAME="fks-$SERVICE_NAME"
fi
if [ -z "$CONTAINER_NAME" ]; then
    CONTAINER_NAME="$DEPLOYMENT_NAME"
fi

# Create workflow file
WORKFLOW_DIR=".github/workflows"
WORKFLOW_FILE="$WORKFLOW_DIR/deploy-k8s.yml"

mkdir -p "$WORKFLOW_DIR"

cat > "$WORKFLOW_FILE" << EOF
name: Deploy to Kubernetes

# Deploy $SERVICE_NAME to Kubernetes via SSH jump server
# This workflow is triggered after a successful Docker build and push

on:
  workflow_call:
    inputs:
      image:
        description: 'Docker image to deploy'
        required: true
        type: string
    secrets:
      SSH_PRIVATE_KEY:
        description: 'SSH private key for jump server'
        required: true
      K8S_SSH_KEY:
        description: 'SSH private key for K8s server (optional)'
        required: false
      K8S_HOST:
        description: 'K8s server Tailscale IP or hostname (optional)'
        required: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Configure SSH
        run: |
          mkdir -p ~/.ssh
          chmod 700 ~/.ssh
          echo "\${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/jump_key
          chmod 600 ~/.ssh/jump_key
          
          # Add jump server to known hosts
          ssh-keyscan -H github.fkstrading.xyz >> ~/.ssh/known_hosts 2>/dev/null || true
          
          # Configure SSH
          cat >> ~/.ssh/config << 'SSH_CONFIG'
          Host jump-server
            HostName github.fkstrading.xyz
            User github-actions
            IdentityFile ~/.ssh/jump_key
            StrictHostKeyChecking no
            UserKnownHostsFile ~/.ssh/known_hosts
          SSH_CONFIG
          
          # If K8s host is provided, configure SSH to K8s via jump server
          if [ -n "\${{ secrets.K8S_HOST }}" ]; then
            K8S_KEY="\${{ secrets.K8S_SSH_KEY }}"
            if [ -z "\$K8S_KEY" ]; then
              K8S_KEY="\${{ secrets.SSH_PRIVATE_KEY }}"
            fi
            echo "\$K8S_KEY" > ~/.ssh/k8s_key
            chmod 600 ~/.ssh/k8s_key
            
            # Add K8s host to known hosts
            ssh -i ~/.ssh/jump_key -o StrictHostKeyChecking=no github-actions@github.fkstrading.xyz \
              "ssh-keyscan -H \${{ secrets.K8S_HOST }} 2>/dev/null" >> ~/.ssh/known_hosts || true
          fi

      - name: Deploy to Kubernetes
        run: |
          SERVICE_NAME="$SERVICE_NAME"
          IMAGE="\${{ inputs.image }}"
          NAMESPACE="fks-trading"
          DEPLOYMENT_NAME="$DEPLOYMENT_NAME"
          CONTAINER_NAME="$CONTAINER_NAME"
          K8S_HOST="\${{ secrets.K8S_HOST }}"
          
          echo "🚀 Deploying \$SERVICE_NAME to Kubernetes"
          echo "   Image: \$IMAGE"
          echo "   Deployment: \$DEPLOYMENT_NAME"
          echo "   Container: \$CONTAINER_NAME"
          echo "   Namespace: \$NAMESPACE"
          
          # Function to run kubectl command
          run_kubectl() {
            local cmd="\$1"
            if [ -n "\$K8S_HOST" ]; then
              # SSH into K8s server via jump server
              ssh -i ~/.ssh/k8s_key -o ProxyJump=jump-server -o StrictHostKeyChecking=no github-actions@\$K8S_HOST "\$cmd"
            else
              # Run kubectl on jump server
              ssh -i ~/.ssh/jump_key -o StrictHostKeyChecking=no github-actions@github.fkstrading.xyz "\$cmd"
            fi
          }
          
          # Check if deployment exists
          echo "📋 Checking if deployment exists..."
          if run_kubectl "kubectl get deployment \$DEPLOYMENT_NAME -n \$NAMESPACE" > /dev/null 2>&1; then
            echo "✅ Deployment \$DEPLOYMENT_NAME exists"
            
            # Get current image
            CURRENT_IMAGE=\$(run_kubectl "kubectl get deployment \$DEPLOYMENT_NAME -n \$NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].image}'" 2>/dev/null || echo "")
            if [ -n "\$CURRENT_IMAGE" ]; then
              echo "   Current image: \$CURRENT_IMAGE"
            fi
            echo "   New image: \$IMAGE"
            
            # Update deployment
            echo "🔄 Updating deployment..."
            if run_kubectl "kubectl set image deployment/\$DEPLOYMENT_NAME \$CONTAINER_NAME=\$IMAGE -n \$NAMESPACE"; then
              echo "✅ Image updated"
            else
              echo "⚠️  Failed to update image, trying alternative method..."
              # Try patching deployment
              PATCH_JSON="{\\\"spec\\\":{\\\"template\\\":{\\\"spec\\\":{\\\"containers\\\":[{\\\"name\\\":\\\"\$CONTAINER_NAME\\\",\\\"image\\\":\\\"\$IMAGE\\\"}]}}}}"
              if run_kubectl "kubectl patch deployment \$DEPLOYMENT_NAME -n \$NAMESPACE -p '\$PATCH_JSON'"; then
                echo "✅ Image updated via patch"
              else
                echo "❌ Failed to update deployment"
                exit 1
              fi
            fi
            
            # Restart deployment
            echo "🔄 Restarting deployment..."
            run_kubectl "kubectl rollout restart deployment/\$DEPLOYMENT_NAME -n \$NAMESPACE" || echo "⚠️  Failed to restart deployment"
            
            # Wait for rollout
            echo "⏳ Waiting for rollout to complete..."
            run_kubectl "kubectl rollout status deployment/\$DEPLOYMENT_NAME -n \$NAMESPACE --timeout=300s" || echo "⚠️  Rollout timeout"
            
            # Show status
            echo ""
            echo "📊 Deployment status:"
            run_kubectl "kubectl get deployment \$DEPLOYMENT_NAME -n \$NAMESPACE"
            echo ""
            echo "📊 Pod status:"
            run_kubectl "kubectl get pods -n \$NAMESPACE -l app=\$SERVICE_NAME" || \
            run_kubectl "kubectl get pods -n \$NAMESPACE | grep \$SERVICE_NAME" || \
            echo "   (No pods found)"
            
          else
            echo "❌ Deployment \$DEPLOYMENT_NAME not found in namespace \$NAMESPACE"
            echo "Available deployments:"
            run_kubectl "kubectl get deployments -n \$NAMESPACE" || true
            exit 1
          fi
          
          echo "✅ Deployment complete!"
EOF

echo "✅ Created deployment workflow: $WORKFLOW_FILE"
echo ""
echo "📋 Next steps:"
echo "   1. Update your docker-build-push.yml workflow to call this workflow:"
echo "      - name: Deploy to Kubernetes"
echo "        uses: ./.github/workflows/deploy-k8s.yml"
echo "        with:"
echo "          image: \${{ env.DOCKER_REPO }}:\${{ env.SERVICE_NAME }}-latest"
echo "        secrets:"
echo "          SSH_PRIVATE_KEY: \${{ secrets.SSH_PRIVATE_KEY }}"
echo "          K8S_SSH_KEY: \${{ secrets.K8S_SSH_KEY }}"
echo "          K8S_HOST: \${{ secrets.K8S_HOST }}"
echo ""
echo "   2. Add secrets to GitHub repository:"
echo "      - SSH_PRIVATE_KEY"
echo "      - K8S_SSH_KEY (optional)"
echo "      - K8S_HOST (optional)"
echo ""

