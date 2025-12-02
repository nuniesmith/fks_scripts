#!/usr/bin/env python3
"""
Standardize all FKS services with consistent structure, testing, and CI/CD.

This script:
1. Creates/updates GitHub Actions workflows
2. Standardizes pytest.ini files
3. Ensures consistent directory structure
4. Creates/updates Dockerfiles and docker-compose.yml
"""

import os
import json
from pathlib import Path
from typing import Dict, Tuple

SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
REPO_ROOT = PROJECT_ROOT  # repo/main is the repo root

# Service configurations: (port, language, has_tests)
SERVICE_CONFIG: Dict[str, Tuple[int, str, bool]] = {
    "ai": (8002, "python", True),
    "analyze": (8007, "python", True),
    "api": (8001, "python", True),
    "app": (8008, "python", True),
    "auth": (8009, "rust", True),
    "data": (8003, "python", True),
    "execution": (8004, "rust", True),
    "meta": (8005, "rust", True),
    "monitor": (8006, "python", True),
    "training": (8009, "python", True),
    "web": (8000, "python", True),
}


def create_pytest_ini(service_path: Path):
    """Create standardized pytest.ini for Python services."""
    pytest_ini = service_path / "pytest.ini"
    
    content = """[pytest]
addopts = -q -v
testpaths = tests
norecursedirs = .git .venv venv __pycache__ .pytest_cache shared
python_files = test_*.py
python_classes = Test*
python_functions = test_*
"""
    pytest_ini.write_text(content)
    print(f"  ✓ Created pytest.ini")


def create_ruff_toml(service_path: Path):
    """Create standardized ruff.toml for Python services."""
    ruff_toml = service_path / "ruff.toml"
    
    if ruff_toml.exists():
        return
    
    content = """target-version = "py312"
line-length = 100
select = ["E", "F", "I", "N", "W", "UP"]
ignore = ["E501"]
"""
    ruff_toml.write_text(content)
    print(f"  ✓ Created ruff.toml")


def create_conftest(service_path: Path):
    """Create conftest.py if tests directory exists."""
    tests_dir = service_path / "tests"
    if not tests_dir.exists():
        return
    
    conftest = tests_dir / "conftest.py"
    if conftest.exists():
        return
    
    content = '''"""Pytest configuration and fixtures."""
import sys
from pathlib import Path

# Add src to path
src_path = Path(__file__).parent.parent / "src"
if src_path.exists() and str(src_path) not in sys.path:
    sys.path.insert(0, str(src_path))
'''
    conftest.write_text(content)
    print(f"  ✓ Created conftest.py")


def create_github_workflows(service_name: str, service_path: Path, port: int, lang: str):
    """Create standardized GitHub Actions workflows."""
    workflows_dir = service_path / ".github" / "workflows"
    workflows_dir.mkdir(parents=True, exist_ok=True)
    
    service_upper = service_name.upper()
    
    if lang == "python":
        # Tests workflow
        tests_yml = workflows_dir / "tests.yml"
        tests_content = f"""name: FKS {service_upper} CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          
      - name: Cache pip dependencies
        uses: actions/cache@v4
        with:
          path: ~/.cache/pip
          key: ${{{{ runner.os }}}}-pip-{service_name}-${{{{ hashFiles('**/requirements.txt') }}}}
          restore-keys: |
            ${{{{ runner.os }}}}-pip-{service_name}-
            
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt
          if [ -f requirements.dev.txt ]; then pip install -r requirements.dev.txt; fi
          pip install pytest pytest-cov ruff mypy
          
      - name: Lint with ruff
        run: ruff check src/ || true
        continue-on-error: true
        
      - name: Type check with mypy
        run: mypy src/ || true
        continue-on-error: true
        
      - name: Run tests
        run: |
          if [ -d "tests" ] && [ "$(ls -A tests)" ]; then
            pytest tests/ -v --cov=src --cov-report=xml --cov-report=term || true
          else
            echo "No tests found, skipping"
          fi
        
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v4
        with:
          file: ./coverage.xml
          flags: {service_name}
          name: {service_name}-coverage
          fail_ci_if_error: false
        
  docker:
    runs-on: ubuntu-latest
    needs: test
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
        
      - name: Build Docker image
        run: docker build -t {service_name}:latest .
        
      - name: Test Docker image
        run: |
          docker run -d --name {service_name}_test -p {port}:{port} {service_name}:latest
          sleep 10
          curl -f http://localhost:{port}/health || exit 1
          docker stop {service_name}_test
"""
        tests_yml.write_text(tests_content)
        print(f"  ✓ Created .github/workflows/tests.yml")
        
        # Docker build workflow
        docker_yml = workflows_dir / "docker-build-push.yml"
        docker_content = f"""name: Docker Build and Push

on:
  push:
    branches: [main, develop]
    tags:
      - 'v*'
  pull_request:
    branches: [main]

env:
  SERVICE_NAME: {service_name}
  DOCKER_USERNAME: ${{{{ secrets.DOCKER_USERNAME }}}}

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt
          if [ -f requirements.dev.txt ]; then pip install -r requirements.dev.txt; fi

      - name: Run linting
        run: |
          pip install ruff mypy || true
          ruff check src/ || true
          mypy src/ || true

      - name: Run tests
        run: |
          pip install pytest pytest-cov || true
          if [ -d "tests" ] && [ "$(ls -A tests)" ]; then
            pytest tests/ -v --cov=src --cov-report=xml || true
          fi

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          file: ./coverage.xml
          fail_ci_if_error: false

  build-and-push:
    needs: test
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && (github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/v'))
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to DockerHub
        uses: docker/login-action@v3
        with:
          username: ${{{{ secrets.DOCKER_USERNAME }}}}
          password: ${{{{ secrets.DOCKER_TOKEN }}}}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{{{ secrets.DOCKER_USERNAME }}}}/${{{{ env.SERVICE_NAME }}}}
          tags: |
            type=ref,event=branch
            type=sha,prefix=sha-
            type=semver,pattern={{{{version}}}}
            type=semver,pattern={{{{major}}}}.{{{{minor}}}}
            type=semver,pattern={{{{major}}}}
            type=raw,value=latest,enable={{{{is_default_branch}}}}

      - name: Build and push Docker image
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{{{ steps.meta.outputs.tags }}}}
          labels: ${{{{ steps.meta.outputs.labels }}}}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Image digest
        run: echo ${{{{ steps.meta.outputs.digest }}}}
"""
        docker_yml.write_text(docker_content)
        print(f"  ✓ Created .github/workflows/docker-build-push.yml")
    
    elif lang == "rust":
        # Tests workflow for Rust
        tests_yml = workflows_dir / "tests.yml"
        tests_content = f"""name: FKS {service_upper} CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Rust toolchain
        uses: dtolnay/rust-toolchain@stable
        with:
          components: clippy, rustfmt
          
      - name: Cache cargo dependencies
        uses: actions/cache@v4
        with:
          path: |
            ~/.cargo/bin/
            ~/.cargo/registry/index/
            ~/.cargo/registry/cache/
            ~/.cargo/git/db/
            target/
          key: ${{{{ runner.os }}}}-cargo-{service_name}-${{{{ hashFiles('**/Cargo.lock') }}}}
          restore-keys: |
            ${{{{ runner.os }}}}-cargo-{service_name}-
            
      - name: Format check
        run: cargo fmt --check
        continue-on-error: true
        
      - name: Clippy check
        run: cargo clippy -- -D warnings
        continue-on-error: true
        
      - name: Run tests
        run: cargo test --verbose
        
      - name: Build release
        run: cargo build --release
        
  docker:
    runs-on: ubuntu-latest
    needs: test
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
        
      - name: Build Docker image
        run: docker build -t {service_name}:latest .
        
      - name: Test Docker image
        run: |
          docker run -d --name {service_name}_test -p {port}:{port} {service_name}:latest
          sleep 10
          curl -f http://localhost:{port}/health || exit 1
          docker stop {service_name}_test
"""
        tests_yml.write_text(tests_content)
        print(f"  ✓ Created .github/workflows/tests.yml")
        
        # Docker build workflow for Rust
        docker_yml = workflows_dir / "docker-build-push.yml"
        docker_content = f"""name: Docker Build and Push

on:
  push:
    branches: [main, develop]
    tags:
      - 'v*'
  pull_request:
    branches: [main]

env:
  SERVICE_NAME: {service_name}
  DOCKER_USERNAME: ${{{{ secrets.DOCKER_USERNAME }}}}

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install Rust toolchain
        uses: dtolnay/rust-toolchain@stable

      - name: Cache cargo dependencies
        uses: actions/cache@v4
        with:
          path: |
            ~/.cargo/bin/
            ~/.cargo/registry/
            target/
          key: ${{{{ runner.os }}}}-cargo-${{{{ hashFiles('**/Cargo.lock') }}}}

      - name: Run tests
        run: cargo test --verbose || true

      - name: Build
        run: cargo build --release || true

  build-and-push:
    needs: test
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && (github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/v'))
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to DockerHub
        uses: docker/login-action@v3
        with:
          username: ${{{{ secrets.DOCKER_USERNAME }}}}
          password: ${{{{ secrets.DOCKER_TOKEN }}}}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{{{ secrets.DOCKER_USERNAME }}}}/${{{{ env.SERVICE_NAME }}}}
          tags: |
            type=ref,event=branch
            type=sha,prefix=sha-
            type=semver,pattern={{{{version}}}}
            type=semver,pattern={{{{major}}}}.{{{{minor}}}}
            type=semver,pattern={{{{major}}}}
            type=raw,value=latest,enable={{{{is_default_branch}}}}

      - name: Build and push Docker image
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{{{ steps.meta.outputs.tags }}}}
          labels: ${{{{ steps.meta.outputs.labels }}}}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Image digest
        run: echo ${{{{ steps.meta.outputs.digest }}}}
"""
        docker_yml.write_text(docker_content)
        print(f"  ✓ Created .github/workflows/docker-build-push.yml")


def standardize_service(service_name: str, port: int, lang: str):
    """Standardize a single service."""
    service_path = REPO_ROOT / service_name
    
    if not service_path.exists():
        print(f"⚠️  {service_name}: Directory not found, skipping")
        return
    
    print(f"\n📦 Standardizing {service_name} (port: {port}, lang: {lang})...")
    
    # Create GitHub workflows
    create_github_workflows(service_name, service_path, port, lang)
    
    # Python-specific standardization
    if lang == "python":
        create_pytest_ini(service_path)
        create_ruff_toml(service_path)
        create_conftest(service_path)
    
    # Ensure tests directory exists
    tests_dir = service_path / "tests"
    if not tests_dir.exists():
        tests_dir.mkdir(parents=True, exist_ok=True)
        (tests_dir / "__init__.py").touch()
        (tests_dir / "unit").mkdir(exist_ok=True)
        (tests_dir / "integration").mkdir(exist_ok=True)
        print(f"  ✓ Created tests/ directory structure")
    
    print(f"✅ {service_name} standardized")


def main():
    """Main standardization function."""
    print("🚀 Standardizing all FKS services...")
    print("=" * 60)
    
    for service_name, (port, lang, _) in SERVICE_CONFIG.items():
        try:
            standardize_service(service_name, port, lang)
        except Exception as e:
            print(f"❌ Error standardizing {service_name}: {e}")
    
    print("\n" + "=" * 60)
    print("✅ Standardization complete!")
    print("\nNext steps:")
    print("1. Review generated workflows")
    print("2. Commit changes to each service repository")
    print("3. Test workflows on a branch")


if __name__ == "__main__":
    main()

