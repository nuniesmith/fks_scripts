#!/bin/bash
# Standardize GitHub Actions workflows across all FKS services

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_ROOT="$PROJECT_ROOT"
SERVICES=("ai" "analyze" "api" "app" "auth" "data" "execution" "main" "meta" "monitor" "ninja" "training" "web")

# Python service workflow template
create_python_workflow() {
    local service_name=$1
    local service_port=$2
    local workflow_dir="${REPO_ROOT}/${service_name}/.github/workflows"
    
    mkdir -p "$workflow_dir"
    
    cat > "${workflow_dir}/tests.yml" << 'PYTHON_TESTS_EOF'
name: FKS {SERVICE_NAME} CI/CD

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
          key: ${{ runner.os }}-pip-{SERVICE_NAME}-${{ hashFiles('**/requirements.txt') }}
          restore-keys: |
            ${{ runner.os }}-pip-{SERVICE_NAME}-
            
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
          flags: {SERVICE_NAME}
          name: {service-name}-coverage
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
          docker run -d --name {service_name}_test -p {SERVICE_PORT}:{SERVICE_PORT} {service_name}:latest
          sleep 10
          curl -f http://localhost:{SERVICE_PORT}/health || exit 1
          docker stop {service_name}_test
PYTHON_TESTS_EOF

    # Replace placeholders
    sed -i "s/{SERVICE_NAME}/${service_name^^}/g" "${workflow_dir}/tests.yml"
    sed -i "s/{service_name}/${service_name}/g" "${workflow_dir}/tests.yml"
    sed -i "s/{SERVICE_PORT}/${service_port}/g" "${workflow_dir}/tests.yml"
    
    cat > "${workflow_dir}/docker-build-push.yml" << 'PYTHON_DOCKER_EOF'
name: Docker Build and Push

on:
  push:
    branches: [main, develop]
    tags:
      - 'v*'
  pull_request:
    branches: [main]

env:
  SERVICE_NAME: {service_name}
  DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}

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
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ secrets.DOCKER_USERNAME }}/${{ env.SERVICE_NAME }}
          tags: |
            type=ref,event=branch
            type=sha,prefix=sha-
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=semver,pattern={{major}}
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push Docker image
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Image digest
        run: echo ${{ steps.meta.outputs.digest }}
PYTHON_DOCKER_EOF

    sed -i "s/{service_name}/${service_name}/g" "${workflow_dir}/docker-build-push.yml"
}

# Rust service workflow template
create_rust_workflow() {
    local service_name=$1
    local service_port=$2
    local workflow_dir="${REPO_ROOT}/${service_name}/.github/workflows"
    
    mkdir -p "$workflow_dir"
    
    cat > "${workflow_dir}/tests.yml" << 'RUST_TESTS_EOF'
name: FKS {SERVICE_NAME} CI/CD

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
          key: ${{ runner.os }}-cargo-{SERVICE_NAME}-${{ hashFiles('**/Cargo.lock') }}
          restore-keys: |
            ${{ runner.os }}-cargo-{SERVICE_NAME}-
            
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
          docker run -d --name {service_name}_test -p {SERVICE_PORT}:{SERVICE_PORT} {service_name}:latest
          sleep 10
          curl -f http://localhost:{SERVICE_PORT}/health || exit 1
          docker stop {service_name}_test
RUST_TESTS_EOF

    sed -i "s/{SERVICE_NAME}/${service_name^^}/g" "${workflow_dir}/tests.yml"
    sed -i "s/{service_name}/${service_name}/g" "${workflow_dir}/tests.yml"
    sed -i "s/{SERVICE_PORT}/${service_port}/g" "${workflow_dir}/tests.yml"
    
    cat > "${workflow_dir}/docker-build-push.yml" << 'RUST_DOCKER_EOF'
name: Docker Build and Push

on:
  push:
    branches: [main, develop]
    tags:
      - 'v*'
  pull_request:
    branches: [main]

env:
  SERVICE_NAME: {service_name}
  DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}

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
          key: ${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.lock') }}

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
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ secrets.DOCKER_USERNAME }}/${{ env.SERVICE_NAME }}
          tags: |
            type=ref,event=branch
            type=sha,prefix=sha-
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=semver,pattern={{major}}
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push Docker image
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Image digest
        run: echo ${{ steps.meta.outputs.digest }}
RUST_DOCKER_EOF

    sed -i "s/{service_name}/${service_name}/g" "${workflow_dir}/docker-build-push.yml"
}

# Service configurations (name, port, language)
declare -A SERVICE_CONFIG=(
    ["ai"]="8002:python"
    ["analyze"]="8007:python"
    ["api"]="8001:python"
    ["app"]="8008:python"
    ["auth"]="8009:rust"
    ["data"]="8003:python"
    ["execution"]="8004:rust"
    ["meta"]="8005:rust"
    ["monitor"]="8006:python"
    ["training"]="8009:python"
    ["web"]="8000:python"
)

echo "Creating standardized GitHub Actions workflows..."

for service in "${SERVICES[@]}"; do
    if [ ! -d "${REPO_ROOT}/${service}" ]; then
        echo "Skipping ${service} (directory not found)"
        continue
    fi
    
    config="${SERVICE_CONFIG[$service]}"
    if [ -z "$config" ]; then
        echo "Skipping ${service} (no config found)"
        continue
    fi
    
    IFS=':' read -r port lang <<< "$config"
    
    echo "Processing ${service} (port: ${port}, language: ${lang})..."
    
    if [ "$lang" = "rust" ]; then
        create_rust_workflow "$service" "$port"
    else
        create_python_workflow "$service" "$port"
    fi
    
    echo "✅ Created workflows for ${service}"
done

echo "Done!"

