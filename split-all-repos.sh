#!/bin/bash
set -e

###############################################################################
# FKS Monorepo Split Script
# 
# Purpose: Split FKS monorepo into 9 independent service repositories
# Strategy: git-filter-repo with history preservation
# Date: 2025-11-07
###############################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SOURCE_REPO="/home/jordan/Documents/code/fks"
TEMP_BASE="/tmp/fks_split"
GIT_FILTER_REPO="$SOURCE_REPO/git-filter-repo"
GITHUB_USER="nuniesmith"

# Ensure temp directory exists
mkdir -p "$TEMP_BASE"

# Repository mappings (repo_name|paths_comma_separated)
REPO_CONFIGS=(
    "fks_ai|repo/ai/,src/services/ai/,notebooks/transformer/,tests/unit/test_rag/,tests/unit/test_sentiment/"
    "fks_api|repo/api/,tests/integration/test_api"
    "fks_app|repo/app/,data/asmbtr_real_data_optimization.json,tests/unit/test_asmbtr,tests/unit/strategies/asmbtr/"
    "fks_data|repo/data/,data/market_data/,tests/integration/test_data"
    "fks_execution|src/services/execution/,tests/unit/test_execution/,tests/integration/test_execution_pipeline.py"
    "fks_ninja|repo/ninja/"
    "fks_meta|scripts/devtools/scripts-meta/"
    "fks_web|repo/web/,tests/unit/test_web"
)

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if git-filter-repo exists
    if [ ! -x "$GIT_FILTER_REPO" ]; then
        print_error "git-filter-repo not found at $GIT_FILTER_REPO"
        exit 1
    fi
    print_success "git-filter-repo found"
    
    # Check if source repo exists
    if [ ! -d "$SOURCE_REPO/.git" ]; then
        print_error "Source repository not found at $SOURCE_REPO"
        exit 1
    fi
    print_success "Source repository found"
    
    # Check if backup exists
    if [ ! -f "$SOURCE_REPO/fks-backup-20251107.bundle" ]; then
        print_warning "Backup bundle not found - creating one now..."
        cd "$SOURCE_REPO"
        git bundle create fks-backup-20251107.bundle --all
        print_success "Backup created"
    else
        print_success "Backup exists"
    fi
    
    echo ""
}

# Function to copy shared code
copy_shared_code() {
    local target_dir=$1
    print_status "Copying shared code to $target_dir..."
    
    mkdir -p "$target_dir/shared/shared"
    mkdir -p "$target_dir/shared/core"
    mkdir -p "$target_dir/shared/framework"
    
    if [ -d "$SOURCE_REPO/src/shared" ]; then
        rsync -av --quiet "$SOURCE_REPO/src/shared/" "$target_dir/shared/shared/"
    fi
    
    if [ -d "$SOURCE_REPO/src/core" ]; then
        rsync -av --quiet "$SOURCE_REPO/src/core/" "$target_dir/shared/core/"
    fi
    
    if [ -d "$SOURCE_REPO/src/framework" ]; then
        rsync -av --quiet "$SOURCE_REPO/src/framework/" "$target_dir/shared/framework/"
    fi
    
    print_success "Shared code copied"
}

# Function to create basic README
create_readme() {
    local repo_name=$1
    local target_dir=$2
    
    cat > "$target_dir/README.md" << EOF
# $repo_name

Part of the FKS Trading Platform.

## Overview

This repository contains the ${repo_name#fks_} service for the FKS trading platform.

## Installation

\`\`\`bash
# Clone repository
git clone https://github.com/$GITHUB_USER/$repo_name.git
cd $repo_name

# Install dependencies
pip install -r requirements.txt
\`\`\`

## Development

\`\`\`bash
# Run tests
pytest tests/ -v

# Run linting
ruff check src/

# Build Docker image
docker build -t $GITHUB_USER/$repo_name:latest .
\`\`\`

## Deployment

\`\`\`bash
# Run with docker-compose
docker-compose up -d

# Or deploy to Kubernetes
kubectl apply -f k8s/
\`\`\`

## Documentation

See main FKS documentation at: https://github.com/$GITHUB_USER/fks_main

## License

See main FKS repository for license information.
EOF
    
    print_success "README created for $repo_name"
}

# Function to split a single repository
split_repository() {
    local repo_name=$1
    local paths=$2
    
    echo ""
    echo "=========================================================================="
    print_status "STARTING SPLIT: $repo_name"
    print_status "Paths: $paths"
    echo "=========================================================================="
    
    # Create temp directory for this repo
    local temp_dir="$TEMP_BASE/${repo_name}_temp"
    rm -rf "$temp_dir"
    
    print_status "Cloning source repository to $temp_dir..."
    git clone "$SOURCE_REPO" "$temp_dir"
    cd "$temp_dir"
    
    # Build filter-repo command
    print_status "Filtering repository history..."
    local filter_cmd="$GIT_FILTER_REPO --force"
    
    # Split paths by comma and add to filter command
    IFS=',' read -ra PATH_ARRAY <<< "$paths"
    for path in "${PATH_ARRAY[@]}"; do
        # Trim whitespace
        path=$(echo "$path" | xargs)
        if [ -n "$path" ]; then
            filter_cmd="$filter_cmd --path $path"
            print_status "  Including: $path"
        fi
    done
    
    # Execute filter
    eval "$filter_cmd"
    
    # Copy shared code
    copy_shared_code "$temp_dir"
    
    # Create README
    create_readme "$repo_name" "$temp_dir"
    
    # Create .gitignore
    cat > "$temp_dir/.gitignore" << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# Virtual environments
.venv/
venv/
ENV/
env/

# IDE
.vscode/
.idea/
*.swp
*.swo

# Testing
.pytest_cache/
.coverage
htmlcov/
.tox/

# Docker
.dockerignore

# Logs
*.log
logs/

# OS
.DS_Store
Thumbs.db
EOF
    
    # Add all changes
    git add .
    git commit -m "Add shared code, README, and .gitignore" || true
    
    # Get commit count
    local commit_count=$(git log --oneline | wc -l)
    print_success "Repository filtered: $commit_count commits preserved"
    
    # Add remote
    print_status "Adding GitHub remote..."
    git remote remove origin 2>/dev/null || true
    git remote add origin "https://github.com/$GITHUB_USER/$repo_name.git"
    
    # Show summary
    echo ""
    print_status "Repository Summary:"
    echo "  Commits: $commit_count"
    echo "  Files: $(find . -type f | wc -l)"
    echo "  Remote: https://github.com/$GITHUB_USER/$repo_name.git"
    echo ""
    
    print_warning "Ready to push to GitHub (run manually):"
    echo "  cd $temp_dir"
    echo "  git push -u origin main --force"
    echo ""
    
    print_success "$repo_name split complete!"
}

# Function to display summary
display_summary() {
    echo ""
    echo "=========================================================================="
    print_success "ALL REPOSITORIES SPLIT SUCCESSFULLY!"
    echo "=========================================================================="
    echo ""
    print_status "Split repositories are located in: $TEMP_BASE"
    echo ""
    print_status "Next steps:"
    echo "  1. Review each repository in $TEMP_BASE"
    echo "  2. Push to GitHub (see commands below)"
    echo "  3. Create Dockerfiles for each service"
    echo "  4. Set up GitHub Actions workflows"
    echo ""
    
    print_status "Push commands:"
    for config in "${REPO_CONFIGS[@]}"; do
        IFS='|' read -r repo_name paths <<< "$config"
        echo "  cd $TEMP_BASE/${repo_name}_temp && git push -u origin main --force"
    done
    echo ""
    
    print_status "Or push all at once (requires GitHub authentication):"
    echo "  cd $TEMP_BASE"
    echo "  for dir in *_temp; do"
    echo "    cd \$dir && git push -u origin main --force && cd .."
    echo "  done"
    echo ""
}

# Main execution
main() {
    echo ""
    echo "=========================================================================="
    echo "          FKS Monorepo Split - Starting Process"
    echo "=========================================================================="
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    # Process each repository
    local total=${#REPO_CONFIGS[@]}
    local current=0
    
    print_status "Found $total repositories to process"
    
    for config in "${REPO_CONFIGS[@]}"; do
        ((current++))
        IFS='|' read -r repo_name paths <<< "$config"
        print_status "Processing repository $current of $total: $repo_name"
        split_repository "$repo_name" "$paths"
    done
    
    # Display summary
    display_summary
    
    print_success "Script complete!"
}

# Run main function
main "$@"
