#!/usr/bin/env python3
"""
Verify Bitcoin Signal Demo Setup
Quick verification script to check if everything is ready
"""

import sys
import os

# Add repo paths to sys.path
repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
sys.path.insert(0, repo_root)

def check_docker():
    """Check if Docker is available"""
    import subprocess
    try:
        result = subprocess.run(["docker", "--version"], capture_output=True, text=True)
        if result.returncode == 0:
            print(f"✓ Docker: {result.stdout.strip()}")
            return True
        else:
            print("✗ Docker not found")
            return False
    except FileNotFoundError:
        print("✗ Docker not found")
        return False

def check_docker_compose():
    """Check if docker-compose is available"""
    import subprocess
    try:
        result = subprocess.run(["docker-compose", "--version"], capture_output=True, text=True)
        if result.returncode == 0:
            print(f"✓ Docker Compose: {result.stdout.strip()}")
            return True
        else:
            print("✗ Docker Compose not found")
            return False
    except FileNotFoundError:
        print("✗ Docker Compose not found")
        return False

def check_docker_network():
    """Check if fks-network exists"""
    import subprocess
    try:
        result = subprocess.run(
            ["docker", "network", "ls"],
            capture_output=True,
            text=True
        )
        if "fks-network" in result.stdout:
            print("✓ Docker network 'fks-network' exists")
            return True
        else:
            print("⚠ Docker network 'fks-network' does not exist (will be created)")
            return False
    except Exception as e:
        print(f"⚠ Error checking Docker network: {e}")
        return False

def check_services_running():
    """Check if services are running"""
    import subprocess
    services = ["fks_data", "fks_app", "fks_web"]
    running = []
    
    try:
        result = subprocess.run(
            ["docker", "ps", "--format", "{{.Names}}"],
            capture_output=True,
            text=True
        )
        running_containers = result.stdout.strip().split("\n")
        
        for service in services:
            if service in running_containers:
                print(f"✓ {service} is running")
                running.append(service)
            else:
                print(f"⚠ {service} is not running")
        
        return len(running) == len(services)
    except Exception as e:
        print(f"⚠ Error checking services: {e}")
        return False

def check_files():
    """Check if required files exist"""
    files = [
        "repo/data/docker-compose.yml",
        "repo/app/docker-compose.yml",
        "repo/web/docker-compose.yml",
        "repo/data/src/api/routes/data.py",
        "repo/app/src/api/routes/signals.py",
        "repo/app/src/domain/trading/signals/pipeline.py",
        "repo/app/src/domain/trading/strategies/rsi_strategy.py",
        "repo/web/src/portfolio/views.py",
    ]
    
    all_exist = True
    for file_path in files:
        full_path = os.path.join(repo_root, file_path)
        if os.path.exists(full_path):
            print(f"✓ {file_path}")
        else:
            print(f"✗ {file_path} not found")
            all_exist = False
    
    return all_exist

def check_dependencies():
    """Check if Python dependencies are available"""
    try:
        import httpx
        print("✓ httpx available")
    except ImportError:
        print("⚠ httpx not available (needed for fks_app)")
    
    try:
        import pandas
        print("✓ pandas available")
    except ImportError:
        print("⚠ pandas not available (needed for strategies)")
    
    try:
        import numpy
        print("✓ numpy available")
    except ImportError:
        print("⚠ numpy not available (needed for strategies)")
    
    try:
        import talib
        print("✓ talib available")
    except ImportError:
        print("⚠ talib not available (will use fallback RSI calculation)")

def main():
    """Main verification function"""
    print("=== Bitcoin Signal Demo - Setup Verification ===\n")
    
    print("Step 1: Checking Docker")
    print("-" * 40)
    docker_ok = check_docker()
    docker_compose_ok = check_docker_compose()
    network_ok = check_docker_network()
    print()
    
    print("Step 2: Checking Services")
    print("-" * 40)
    services_ok = check_services_running()
    print()
    
    print("Step 3: Checking Files")
    print("-" * 40)
    files_ok = check_files()
    print()
    
    print("Step 4: Checking Dependencies")
    print("-" * 40)
    check_dependencies()
    print()
    
    # Summary
    print("=== Summary ===")
    print("-" * 40)
    
    if docker_ok and docker_compose_ok:
        print("✓ Docker environment ready")
    else:
        print("✗ Docker environment not ready")
        print("  Install Docker Desktop: https://www.docker.com/products/docker-desktop")
    
    if network_ok or docker_ok:
        print("✓ Docker network can be created")
    else:
        print("⚠ Docker network may need manual creation")
    
    if services_ok:
        print("✓ Services are running")
        print("\nNext steps:")
        print("1. Test services: python repo/main/scripts/test-bitcoin-signal.py")
        print("2. Open dashboard: http://localhost:8000/portfolio/signals/?symbols=BTCUSDT&category=swing")
    else:
        print("⚠ Services are not running")
        print("\nNext steps:")
        print("1. Start services: ./repo/main/scripts/start-bitcoin-demo.sh")
        print("2. Or manually: docker network create fks-network && cd repo/data && docker-compose up -d")
    
    if files_ok:
        print("✓ Required files exist")
    else:
        print("✗ Some required files are missing")
        print("  Check repository structure")
    
    print("\n=== Verification Complete ===")
    print("\nFor detailed setup instructions, see:")
    print("  - BITCOIN-QUICK-START.md")
    print("  - BITCOIN-SIGNAL-DEMO-ACTION-PLAN.md")

if __name__ == "__main__":
    main()

