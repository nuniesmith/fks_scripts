# Start Kubernetes and Deploy FKS Platform for Bitcoin Signal Demo
# PowerShell version for Windows/WSL

# Configuration
$NAMESPACE = "fks-trading"
$RELEASE_NAME = "fks-platform"
$DOCKER_USERNAME = "nuniesmith"
$DOCKER_REPO = "fks"

# Colors for output
function Write-Info {
    Write-Host "[INFO] $args" -ForegroundColor Blue
}

function Write-Success {
    Write-Host "[SUCCESS] $args" -ForegroundColor Green
}

function Write-Warning {
    Write-Host "[WARNING] $args" -ForegroundColor Yellow
}

function Write-Error {
    Write-Host "[ERROR] $args" -ForegroundColor Red
}

# Check prerequisites
function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    # Check kubectl
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        Write-Error "kubectl is not installed. Please install kubectl first."
        exit 1
    }
    
    # Check helm
    if (-not (Get-Command helm -ErrorAction SilentlyContinue)) {
        Write-Error "helm is not installed. Please install Helm 3.x first."
        exit 1
    }
    
    # Check minikube
    if (-not (Get-Command minikube -ErrorAction SilentlyContinue)) {
        Write-Warning "minikube is not installed."
        $install = Read-Host "Install minikube now? (y/n)"
        if ($install -eq "y") {
            Write-Info "Please install minikube manually: https://minikube.sigs.k8s.io/docs/start/"
            exit 1
        } else {
            Write-Error "Cannot proceed without minikube."
            exit 1
        }
    }
    
    Write-Success "Prerequisites check passed ✓"
}

# Start minikube
function Start-Minikube {
    Write-Info "Starting minikube cluster..."
    
    # Check if minikube is already running
    $status = minikube status 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Warning "Minikube is already running."
        $restart = Read-Host "Stop and restart minikube? (y/n)"
        if ($restart -eq "y") {
            minikube stop
            minikube delete
        } else {
            Write-Info "Using existing minikube cluster."
            return
        }
    }
    
    # Start minikube with sufficient resources
    Write-Info "Starting minikube with 6 CPUs, 16GB RAM, 50GB disk..."
    minikube start --cpus=6 --memory=16384 --disk-size=50g --driver=docker --addons=ingress --addons=metrics-server
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to start minikube."
        exit 1
    }
    
    Write-Success "Minikube started ✓"
}

# Pull images from DockerHub
function Pull-Images {
    Write-Info "Pulling images from DockerHub..."
    
    # Set minikube Docker context
    $env:DOCKER_HOST = (minikube docker-env | Select-String -Pattern "DOCKER_HOST").ToString().Split("=")[1].Trim('"')
    $env:DOCKER_TLS_VERIFY = (minikube docker-env | Select-String -Pattern "DOCKER_TLS_VERIFY").ToString().Split("=")[1].Trim('"')
    $env:DOCKER_CERT_PATH = (minikube docker-env | Select-String -Pattern "DOCKER_CERT_PATH").ToString().Split("=")[1].Trim('"')
    $env:MINIKUBE_ACTIVE_DOCKERD = (minikube docker-env | Select-String -Pattern "MINIKUBE_ACTIVE_DOCKERD").ToString().Split("=")[1].Trim('"')
    
    # Services needed for Bitcoin signal demo
    $services = @("app", "data", "web", "api", "main")
    
    $successCount = 0
    $failedServices = @()
    
    foreach ($service in $services) {
        $imageName = "$DOCKER_USERNAME/$DOCKER_REPO`:${service}-latest"
        Write-Info "Pulling $imageName..."
        
        docker pull $imageName 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Pulled $imageName ✓"
            $successCount++
        } else {
            Write-Warning "Failed to pull $imageName"
            $failedServices += $service
        }
    }
    
    Write-Info "Image pull complete: $successCount/$($services.Count) services"
    if ($failedServices.Count -gt 0) {
        Write-Warning "Failed to pull: $($failedServices -join ', ')"
        Write-Info "These images may not exist on DockerHub yet."
    }
}

# Deploy FKS platform
function Deploy-Platform {
    Write-Info "Deploying FKS platform to Kubernetes..."
    
    $k8sDir = Join-Path $PSScriptRoot "..\k8s"
    if (-not (Test-Path $k8sDir)) {
        Write-Error "K8s directory not found: $k8sDir"
        exit 1
    }
    
    Push-Location $k8sDir
    
    try {
        # Create namespace if it doesn't exist
        kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f - | Out-Null
        
        # Deploy using Helm
        Write-Info "Deploying with Helm..."
        helm upgrade --install $RELEASE_NAME `
            .\charts\fks-platform `
            --namespace $NAMESPACE `
            --create-namespace `
            --wait `
            --timeout 10m `
            --set fks_app.enabled=true `
            --set fks_data.enabled=true `
            --set fks_web.enabled=false `
            --set fks_api.enabled=true `
            --set fks_main.enabled=true `
            --set fks_ai.enabled=false `
            --set fks_execution.enabled=false `
            --set fks_ninja.enabled=false `
            --set postgresql.enabled=true `
            --set redis.enabled=true
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to deploy platform."
            exit 1
        }
        
        Write-Success "Platform deployed ✓"
    } finally {
        Pop-Location
    }
}

# Wait for pods to be ready
function Wait-ForPods {
    Write-Info "Waiting for pods to be ready..."
    
    # Wait for all pods in namespace
    kubectl wait --for=condition=ready pod `
        --all `
        -n $NAMESPACE `
        --timeout=600s
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Some pods are not ready yet"
    }
    
    # Show pod status
    Write-Info "Pod status:"
    kubectl get pods -n $NAMESPACE
}

# Set up port-forwarding
function Setup-PortForwarding {
    Write-Info "Setting up port-forwarding for web interface..."
    
    # Kill any existing port-forwards
    Get-Process | Where-Object { $_.ProcessName -like "*kubectl*" -and $_.CommandLine -like "*port-forward*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    
    # Port-forward services
    Write-Info "Port-forwarding services..."
    Start-Process kubectl -ArgumentList "port-forward -n $NAMESPACE svc/fks-app 8002:8002" -WindowStyle Hidden
    Start-Process kubectl -ArgumentList "port-forward -n $NAMESPACE svc/fks-data 8003:8003" -WindowStyle Hidden
    Start-Process kubectl -ArgumentList "port-forward -n $NAMESPACE svc/fks-main 8000:8000" -WindowStyle Hidden
    Start-Process kubectl -ArgumentList "port-forward -n $NAMESPACE svc/fks-api 8001:8001" -WindowStyle Hidden
    
    Start-Sleep -Seconds 3
    
    Write-Success "Port-forwarding set up ✓"
}

# Show access information
function Show-AccessInfo {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  FKS Platform - Bitcoin Signal Demo          ║" -ForegroundColor Cyan
    Write-Host "║  Kubernetes Deployment Complete               ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Info "=== Access Information ==="
    Write-Host ""
    Write-Host "Web Interface:"
    Write-Host "  URL: http://localhost:8000"
    Write-Host ""
    Write-Host "API Services:"
    Write-Host "  fks_app (Signals): http://localhost:8002"
    Write-Host "  fks_data (Data): http://localhost:8003"
    Write-Host "  fks_api (Gateway): http://localhost:8001"
    Write-Host "  fks_main (Main): http://localhost:8000"
    Write-Host ""
    Write-Host "Test Bitcoin Signal Generation:"
    Write-Host "  curl `"http://localhost:8002/api/v1/signals/latest/BTCUSDT?category=swing&use_ai=false`""
    Write-Host ""
    Write-Host "View Pod Status:"
    Write-Host "  kubectl get pods -n $NAMESPACE"
    Write-Host ""
    Write-Host "View Logs:"
    Write-Host "  kubectl logs -n $NAMESPACE -l app=fks-app -f"
    Write-Host "  kubectl logs -n $NAMESPACE -l app=fks-data -f"
    Write-Host ""
}

# Main execution
function Main {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  FKS Platform - Bitcoin Signal Demo          ║" -ForegroundColor Cyan
    Write-Host "║  Kubernetes Deployment                        ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # Check prerequisites
    Test-Prerequisites
    
    # Start minikube
    Start-Minikube
    
    # Pull images
    Pull-Images
    
    # Deploy platform
    Deploy-Platform
    
    # Wait for pods
    Wait-ForPods
    
    # Set up port-forwarding
    Setup-PortForwarding
    
    # Show access information
    Show-AccessInfo
}

# Run main function
Main

