# Build all optimized Docker images for FKS services (PowerShell)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "FKS Docker Image Optimization Build" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if shared base should be used
$UseSharedBase = $args[0]
if ($UseSharedBase -eq "true" -or $UseSharedBase -eq "shared") {
    Write-Host "Building with shared base image..." -ForegroundColor Yellow
    Write-Host ""
    
    # Check if base image exists
    $baseExists = docker image inspect nuniesmith/fks:builder-base 2>$null
    if (-not $baseExists) {
        Write-Host "Shared base image not found. Building it first..." -ForegroundColor Yellow
        Set-Location "$RepoRoot\repo\docker-base"
        docker build -t nuniesmith/fks:builder-base -f Dockerfile.builder .
        Write-Host "✅ Base image built" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "✅ Using existing base image" -ForegroundColor Green
        Write-Host ""
    }
    
    $DockerfileSuffix = "optimized-shared"
} else {
    Write-Host "Building standalone optimized images..." -ForegroundColor Yellow
    Write-Host ""
    $DockerfileSuffix = "optimized"
}

# Build training service
Write-Host "Building training service..." -ForegroundColor Cyan
Set-Location "$RepoRoot\repo\training"
if (Test-Path "Dockerfile.$DockerfileSuffix") {
    docker build -f "Dockerfile.$DockerfileSuffix" -t fks_training:optimized .
    Write-Host "✅ Training service built" -ForegroundColor Green
} else {
    Write-Host "⚠️  Dockerfile.$DockerfileSuffix not found, skipping" -ForegroundColor Yellow
}
Write-Host ""

# Build AI service
Write-Host "Building AI service..." -ForegroundColor Cyan
Set-Location "$RepoRoot\repo\ai"
if (Test-Path "Dockerfile.$DockerfileSuffix") {
    docker build -f "Dockerfile.$DockerfileSuffix" -t fks_ai:optimized .
    Write-Host "✅ AI service built" -ForegroundColor Green
} else {
    Write-Host "⚠️  Dockerfile.$DockerfileSuffix not found, using standalone" -ForegroundColor Yellow
    docker build -f Dockerfile.optimized -t fks_ai:optimized .
    Write-Host "✅ AI service built" -ForegroundColor Green
}
Write-Host ""

# Build analyze service
Write-Host "Building analyze service..." -ForegroundColor Cyan
Set-Location "$RepoRoot\repo\analyze"
docker build -f Dockerfile.optimized -t fks_analyze:optimized .
Write-Host "✅ Analyze service built" -ForegroundColor Green
Write-Host ""

# Show image sizes
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Image Sizes:" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | Select-String -Pattern "(fks_|REPOSITORY)" | Select-Object -First 5
Write-Host ""

Write-Host "✅ All optimized images built successfully!" -ForegroundColor Green

