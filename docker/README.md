# Docker Build Scripts

This directory contains scripts for building and managing optimized Docker images for FKS services.

## Scripts

### `build-optimized.sh` / `build-optimized.ps1`
Builds all optimized Docker images for training, AI, and analyze services.

**Usage:**
```bash
# Standalone builds
./build-optimized.sh

# With shared base (faster)
./build-optimized.sh shared
```

**What it does:**
1. Optionally builds/uses shared base image
2. Builds training service (optimized)
3. Builds AI service (optimized)
4. Builds analyze service (optimized)
5. Shows final image sizes

### `compare-sizes.sh`
Compares image sizes between original and optimized versions.

**Usage:**
```bash
./compare-sizes.sh
```

**What it does:**
- Shows size comparison table
- Calculates savings percentage
- Lists current optimized image sizes

### `test-services.sh`
Tests all optimized Docker images by starting them and checking health endpoints.

**Usage:**
```bash
./test-services.sh
```

**What it does:**
1. Starts each service container
2. Waits for service to be ready
3. Tests `/health` endpoint
4. Shows health check response
5. Cleans up containers

**Requirements:**
- `curl` installed
- Ports 8005, 8007, 8008 available

## Examples

### Build Everything
```bash
# Linux/WSL
cd repo/scripts/docker
chmod +x *.sh
./build-optimized.sh shared

# Windows PowerShell
cd repo\scripts\docker
.\build-optimized.ps1 shared
```

### Test After Building
```bash
./test-services.sh
```

### Check Sizes
```bash
./compare-sizes.sh
```

## Integration with CI/CD

These scripts can be used in GitHub Actions:

```yaml
- name: Build optimized images
  run: |
    cd repo/scripts/docker
    chmod +x *.sh
    ./build-optimized.sh shared
```

## Notes

- Scripts assume you're running from the repo root or scripts directory
- Shared base image must be built/pulled before using `shared` option
- Test script requires ports 8005, 8007, 8008 to be available
- All scripts use `set -e` to exit on errors (bash) or `$ErrorActionPreference = "Stop"` (PowerShell)

