# Kubernetes Dashboard Auto-Login Script (PowerShell)
# This script automatically starts kubectl proxy and opens the dashboard with saved token

$ErrorActionPreference = "Stop"

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$TokenFile = Join-Path $ProjectRoot "k8s\dashboard-token.txt"
$ProxyPort = 8001
$DashboardNamespace = "kubernetes-dashboard"

# Functions
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

# Check if kubectl is available
function Test-Kubectl {
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        Write-Error "kubectl is not installed"
        exit 1
    }
}

# Check if cluster is running
function Test-Cluster {
    $null = kubectl cluster-info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Kubernetes cluster is not running"
        Write-Info "Please start your cluster first: minikube start"
        exit 1
    }
}

# Get or create admin token
function Get-AdminToken {
    Write-Info "Getting admin token..."
    
    # Check if token file exists and is recent (less than 24 hours old)
    if (Test-Path $TokenFile) {
        $fileAge = (Get-Date) - (Get-Item $TokenFile).LastWriteTime
        if ($fileAge.TotalHours -lt 24) {
            Write-Info "Using existing token from $TokenFile"
            $tokenLine = Get-Content $TokenFile | Select-String -Pattern "^Token:" -Context 0,1
            if ($tokenLine) {
                $token = ($tokenLine.Line -split "Token:")[1].Trim()
                if ($token) {
                    return $token
                }
            }
        }
    }
    
    # Create admin user if it doesn't exist
    Write-Info "Creating admin user..."
    $adminUserYaml = @"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: $DashboardNamespace
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: $DashboardNamespace
---
apiVersion: v1
kind: Secret
metadata:
  name: admin-user-token
  namespace: $DashboardNamespace
  annotations:
    kubernetes.io/service-account.name: admin-user
type: kubernetes.io/service-account-token
"@
    
    $adminUserYaml | kubectl apply -f - 2>&1 | Out-Null
    
    # Wait for token to be created
    Write-Info "Waiting for token to be created..."
    Start-Sleep -Seconds 5
    
    # Get token from secret
    $tokenBase64 = kubectl get secret admin-user-token -n $DashboardNamespace -o jsonpath='{.data.token}' 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to get admin token"
        exit 1
    }
    
    $tokenBytes = [Convert]::FromBase64String($tokenBase64)
    $token = [System.Text.Encoding]::UTF8.GetString($tokenBytes)
    
    # Save token to file
    $tokenDir = Split-Path -Parent $TokenFile
    if (-not (Test-Path $tokenDir)) {
        New-Item -ItemType Directory -Path $tokenDir -Force | Out-Null
    }
    
    $tokenContent = @"
Kubernetes Dashboard Admin Token
================================

Token:
$token

Access URL:
http://localhost:$ProxyPort/api/v1/namespaces/$DashboardNamespace/services/https:kubernetes-dashboard:/proxy/

Generated: $(Get-Date)
"@
    
    Set-Content -Path $TokenFile -Value $tokenContent
    Write-Success "Token saved to $TokenFile"
    
    return $token
}

# Start kubectl proxy
function Start-Proxy {
    Write-Info "Checking for existing kubectl proxy..."
    
    # Kill any existing kubectl proxy on the port
    $existingProxy = Get-NetTCPConnection -LocalPort $ProxyPort -ErrorAction SilentlyContinue
    if ($existingProxy) {
        $processId = $existingProxy.OwningProcess
        Write-Warning "Stopping existing kubectl proxy (PID: $processId)..."
        Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
    
    Write-Info "Starting kubectl proxy on port $ProxyPort..."
    $proxyProcess = Start-Process -FilePath "kubectl" -ArgumentList "proxy", "--port=$ProxyPort", "--address=127.0.0.1", "--disable-filter=true" -PassThru -WindowStyle Hidden
    
    # Wait for proxy to start
    Start-Sleep -Seconds 3
    
    # Check if proxy is running
    if ($proxyProcess.HasExited) {
        Write-Error "Failed to start kubectl proxy"
        exit 1
    }
    
    Write-Success "kubectl proxy started (PID: $proxyProcess.Id)"
    return $proxyProcess.Id
}

# Open dashboard in browser
function Open-Dashboard {
    param(
        [string]$Token
    )
    
    $dashboardUrl = "http://localhost:$ProxyPort/api/v1/namespaces/$DashboardNamespace/services/https:kubernetes-dashboard:/proxy/"
    
    Write-Info "Dashboard URL: $dashboardUrl"
    Write-Info "Opening dashboard in browser..."
    
    # Copy token to clipboard
    Set-Clipboard -Value $Token
    Write-Info "Token copied to clipboard"
    
    # Open browser
    Start-Process $dashboardUrl
    
    Write-Info "Dashboard opened. Token is in clipboard - paste it when prompted."
}

# Main execution
function Main {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  Kubernetes Dashboard - Auto Login Setup     ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Test-Kubectl
    Test-Cluster
    
    # Deploy dashboard if not already deployed
    $namespaceExists = kubectl get namespace $DashboardNamespace 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Info "Deploying Kubernetes Dashboard..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
        
        # Wait for dashboard to be ready
        Write-Info "Waiting for dashboard to be ready..."
        kubectl wait --for=condition=available --timeout=300s deployment/kubernetes-dashboard -n $DashboardNamespace 2>&1 | Out-Null
    }
    
    # Get admin token
    $token = Get-AdminToken
    
    # Start kubectl proxy
    $proxyPid = Start-Proxy
    
    # Open dashboard
    Open-Dashboard -Token $token
    
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  Dashboard Started Successfully!             ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Success "Dashboard URL: http://localhost:$ProxyPort/api/v1/namespaces/$DashboardNamespace/services/https:kubernetes-dashboard:/proxy/"
    Write-Success "Token saved to: $TokenFile"
    Write-Success "kubectl proxy PID: $proxyPid"
    Write-Host ""
    Write-Info "Token has been copied to clipboard. Paste it when prompted."
    Write-Host ""
    Write-Info "To stop the dashboard:"
    Write-Host "  Stop-Process -Id $proxyPid"
    Write-Host "  or run: Get-Process kubectl | Where-Object { `$_.CommandLine -like '*proxy*' } | Stop-Process"
    Write-Host ""
    Write-Info "To restart with auto-login:"
    Write-Host "  .\scripts\k8s-dashboard-auto-login.ps1"
    Write-Host ""
}

# Run main function
Main

