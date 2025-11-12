# Kubernetes Dashboard Auto-Login (PowerShell)
# One command to start dashboard with token ready to paste

$ErrorActionPreference = "Stop"

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$TokenFile = Join-Path $ProjectRoot "k8s\dashboard-token.txt"
$ProxyPort = 8001
$DashboardNamespace = "kubernetes-dashboard"

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Kubernetes Dashboard - Auto Login           ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Check if token file exists
if (-not (Test-Path $TokenFile)) {
    Write-Host "⚠️  Token file not found. Creating admin user..." -ForegroundColor Yellow
    & "$ScriptDir\setup-k8s-dashboard.sh"
}

# Get token
$Token = ""
if (Test-Path $TokenFile) {
    $TokenLine = Get-Content $TokenFile | Select-String -Pattern "^Token:" -Context 0,1
    if ($TokenLine) {
        $Token = ($TokenLine.Line -split "Token:")[1].Trim()
    }
}

if ([string]::IsNullOrEmpty($Token)) {
    Write-Host "⚠️  Could not get token. Creating admin user..." -ForegroundColor Yellow
    $AdminUserYaml = Join-Path $ProjectRoot "k8s\manifests\dashboard-admin-user.yaml"
    if (Test-Path $AdminUserYaml) {
        kubectl apply -f $AdminUserYaml 2>&1 | Out-Null
        Start-Sleep -Seconds 5
        $TokenBase64 = kubectl get secret admin-user-token -n $DashboardNamespace -o jsonpath='{.data.token}' 2>&1
        if ($LASTEXITCODE -eq 0) {
            $TokenBytes = [Convert]::FromBase64String($TokenBase64)
            $Token = [System.Text.Encoding]::UTF8.GetString($TokenBytes)
        }
    }
    
    if ([string]::IsNullOrEmpty($Token)) {
        Write-Host "❌ Could not get token. Please run: .\scripts\setup-k8s-dashboard.sh" -ForegroundColor Red
        exit 1
    }
}

# Kill existing proxy
Write-Host "🛑 Stopping existing kubectl proxy..." -ForegroundColor Blue
$ExistingProxy = Get-Process kubectl -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*proxy*" }
if ($ExistingProxy) {
    $ExistingProxy | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

# Start kubectl proxy
Write-Host "🚀 Starting kubectl proxy on port $ProxyPort..." -ForegroundColor Blue
$ProxyProcess = Start-Process -FilePath "kubectl" -ArgumentList "proxy", "--port=$ProxyPort", "--address=127.0.0.1", "--disable-filter=true" -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 3

# Verify proxy is running
if ($ProxyProcess.HasExited) {
    Write-Host "❌ Failed to start kubectl proxy" -ForegroundColor Red
    exit 1
}

# Copy token to clipboard
Write-Host "📋 Copying token to clipboard..." -ForegroundColor Blue
Set-Clipboard -Value $Token
$ClipboardSuccess = $true

# Dashboard URL
$DashboardUrl = "http://localhost:$ProxyPort/api/v1/namespaces/$DashboardNamespace/services/https:kubernetes-dashboard:/proxy/"

# Open browser
Write-Host "🌐 Opening dashboard in browser..." -ForegroundColor Blue
Start-Process $DashboardUrl

# Display info
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  Dashboard Started Successfully!              ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Dashboard URL:" -ForegroundColor Cyan
Write-Host "  $DashboardUrl"
Write-Host ""
Write-Host "Token:" -ForegroundColor Cyan
if ($ClipboardSuccess) {
    Write-Host "  ✅ Copied to clipboard!" -ForegroundColor Green
    Write-Host "  Just paste it when prompted (Ctrl+V)" -ForegroundColor Yellow
} else {
    Write-Host "  ⚠️  Could not copy to clipboard. Token:" -ForegroundColor Yellow
    Write-Host "  $Token"
}
Write-Host ""
Write-Host "Proxy PID: $($ProxyProcess.Id)" -ForegroundColor Cyan
Write-Host ""
Write-Host "To stop dashboard:" -ForegroundColor Yellow
Write-Host "  Stop-Process -Id $($ProxyProcess.Id)"
Write-Host "  or: Get-Process kubectl | Where-Object { `$_.CommandLine -like '*proxy*' } | Stop-Process"
Write-Host ""
Write-Host "To restart:" -ForegroundColor Yellow
Write-Host "  .\scripts\dashboard-auto-login.ps1"
Write-Host ""

