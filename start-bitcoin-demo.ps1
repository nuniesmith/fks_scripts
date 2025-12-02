# Start Bitcoin Signal Demo Services
# PowerShell script for Windows

Write-Host "=== Starting Bitcoin Signal Demo ===" -ForegroundColor Green
Write-Host ""

# Check if Docker is running
try {
    docker info | Out-Null
} catch {
    Write-Host "Error: Docker is not running. Please start Docker first." -ForegroundColor Red
    exit 1
}

# Function to start service
function Start-Service {
    param (
        [string]$Name,
        [string]$Path
    )
    
    Write-Host "Starting $Name... " -NoNewline
    
    Push-Location $Path
    try {
        docker-compose up -d 2>&1 | Out-Null
        Write-Host "✓ Started" -ForegroundColor Green
        Pop-Location
        return $true
    } catch {
        Write-Host "⚠ Already running or error" -ForegroundColor Yellow
        Pop-Location
        return $false
    }
}

# Function to wait for service
function Wait-ForService {
    param (
        [string]$Name,
        [string]$Url
    )
    
    Write-Host "Waiting for $Name to be ready... " -NoNewline
    
    $maxAttempts = 30
    $attempt = 0
    
    while ($attempt -lt $maxAttempts) {
        try {
            $response = Invoke-WebRequest -Uri "$Url/health" -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-Host "✓ Ready" -ForegroundColor Green
                return $true
            }
        } catch {
            # Service not ready yet
        }
        
        $attempt++
        Start-Sleep -Seconds 2
    }
    
    Write-Host "⚠ Timeout" -ForegroundColor Yellow
    return $false
}

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir = Split-Path -Parent (Split-Path -Parent $ScriptDir)

Write-Host "Step 1: Creating Docker Network" -ForegroundColor Cyan
Write-Host "------------------------------"
try {
    docker network create fks-network 2>&1 | Out-Null
    Write-Host "✓ Network created or already exists" -ForegroundColor Green
} catch {
    Write-Host "⚠ Network may already exist" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "Step 2: Starting Services" -ForegroundColor Cyan
Write-Host "------------------------"
Start-Service "fks_data" "$RepoDir\data"
Start-Service "fks_app" "$RepoDir\app"
Start-Service "fks_web" "$RepoDir\web"
Write-Host ""

Write-Host "Step 3: Waiting for Services" -ForegroundColor Cyan
Write-Host "---------------------------"
Wait-ForService "fks_data" "http://localhost:8003"
Wait-ForService "fks_app" "http://localhost:8002"
Wait-ForService "fks_web" "http://localhost:8000"
Write-Host ""

Write-Host "=== Services Started! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Services:"
Write-Host "  - fks_data:  http://localhost:8003"
Write-Host "  - fks_app:   http://localhost:8002"
Write-Host "  - fks_web:   http://localhost:8000"
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Test Bitcoin signal: python repo\main\scripts\test-bitcoin-signal.py"
Write-Host "2. Open dashboard: http://localhost:8000/portfolio/signals/?symbols=BTCUSDT&category=swing"
Write-Host "3. Review Bitcoin signals"
Write-Host ""

