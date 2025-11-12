#!/bin/bash
# FKS Trading Platform - Auto Commit and Push All Repositories (Non-Interactive)

# Don't exit on error - we want to process all repos even if one fails
set +e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Calculate repo root (go up two levels from repo/main to fks root)
# Resolve symlink to actual script location
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_SOURCE" ]; do
    SCRIPT_SOURCE="$(readlink -f "$SCRIPT_SOURCE")"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPOS=(
    "repo/ai"
    "repo/analyze"
    "repo/api"
    "repo/app"
    "repo/auth"
    "repo/data"
    "repo/execution"
    "repo/main"
    "repo/meta"
    "repo/monitor"
    "repo/ninja"
    "repo/portfolio"
    "repo/training"
    "repo/web"
)

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

cd "$REPO_ROOT"

processed=0
skipped=0
failed=0

for repo in "${REPOS[@]}"; do
    repo_path="$REPO_ROOT/$repo"
    repo_name=$(basename "$repo")
    
    if [ ! -d "$repo_path/.git" ]; then
        continue
    fi
    
    cd "$repo_path"
    
    # Check for changes
    if git diff --quiet && git diff --cached --quiet && [ -z "$(git status --porcelain)" ]; then
        continue
    fi
    
    echo ""
    echo "=========================================="
    log_info "Processing: $repo_name"
    echo "=========================================="
    
    # Stage all
    git add -A
    
    # Generate commit message
    commit_msg="chore: Update files ($(date +'%Y-%m-%d %H:%M:%S'))"
    
    if git diff --cached --name-only 2>/dev/null | grep -q "README.md"; then
        commit_msg="docs: Update README and documentation"
    elif git diff --cached --name-only 2>/dev/null | grep -q "Dockerfile\|docker-compose"; then
        commit_msg="build: Update Docker configuration"
    elif git diff --cached --name-only 2>/dev/null | grep -q "\.github"; then
        commit_msg="ci: Update GitHub Actions workflows"
    fi
    
     # Commit (don't fail script if nothing to commit)
     if git commit -m "$commit_msg" 2>&1; then
         log_success "✓ Committed: $repo_name"
     else
         local exit_code=$?
         if [ $exit_code -eq 1 ]; then
             # Exit code 1 usually means nothing to commit
             log_warning "Nothing to commit in $repo_name"
             ((skipped++))
             cd "$REPO_ROOT"
             continue
         else
             log_warning "Commit failed in $repo_name (exit code: $exit_code)"
             ((failed++))
             cd "$REPO_ROOT"
             continue
         fi
     fi
     
     # Push
     if git remote | grep -q .; then
         branch=$(git branch --show-current)
         if git push origin "$branch" 2>&1; then
             log_success "✓ Pushed: $repo_name"
             ((processed++))
         else
             log_warning "✗ Failed to push: $repo_name"
             ((failed++))
         fi
     else
         log_warning "No remote configured for $repo_name"
         ((skipped++))
     fi
     
     cd "$REPO_ROOT"
done

echo ""
echo "=========================================="
log_success "Summary: Processed=$processed, Skipped=$skipped, Failed=$failed"
echo "=========================================="

