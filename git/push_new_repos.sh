#!/bin/bash
# Push all newly extracted repos to GitHub
# This script is part of the FKS scripts repository

set -e

BASE_DIR="/home/jordan/Nextcloud/code/repos/fks/repo"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Map local directory names to GitHub repo names
declare -A REPO_MAP=(
    ["docs"]="fks_docs"
    ["scripts"]="fks_scripts"
    ["nginx"]="fks_nginx"
    ["config"]="fks_config"
)

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Pushing extracted repos to GitHub${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

for local_dir in "${!REPO_MAP[@]}"; do
    github_repo="${REPO_MAP[$local_dir]}"
    repo_path="${BASE_DIR}/${local_dir}"
    
    if [ ! -d "$repo_path" ]; then
        echo -e "${RED}✗ ${local_dir} not found at ${repo_path}${NC}"
        continue
    fi
    
    echo -e "${YELLOW}Processing ${local_dir} → ${github_repo}...${NC}"
    cd "$repo_path"
    
    # Check if git repo
    if [ ! -d ".git" ]; then
        echo -e "${RED}✗ Not a git repository${NC}"
        continue
    fi
    
    # Rename branch to main if needed
    current_branch=$(git branch --show-current 2>/dev/null || echo "master")
    if [ "$current_branch" != "main" ]; then
        echo "  Renaming branch from ${current_branch} to main..."
        git branch -M main 2>/dev/null || true
        echo -e "${GREEN}  ✓ Branch renamed to main${NC}"
    fi
    
    # Check or set remote
    if ! git remote get-url origin >/dev/null 2>&1; then
        echo "  Adding remote: https://github.com/nuniesmith/${github_repo}.git"
        git remote add origin "https://github.com/nuniesmith/${github_repo}.git"
        echo -e "${GREEN}  ✓ Remote added${NC}"
    else
        remote_url=$(git remote get-url origin)
        echo "  Remote: ${remote_url}"
        
        # Update remote URL if it doesn't match
        expected_url="https://github.com/nuniesmith/${github_repo}.git"
        if [ "$remote_url" != "$expected_url" ] && [ "$remote_url" != "${expected_url%.git}" ]; then
            echo "  Updating remote URL to: ${expected_url}"
            git remote set-url origin "$expected_url"
            echo -e "${GREEN}  ✓ Remote URL updated${NC}"
        fi
    fi
    
    # Stage all changes
    echo "  Staging changes..."
    git add -A 2>/dev/null || true
    
    # Check if there are changes to commit
    if ! git diff --cached --quiet 2>/dev/null || ! git diff --quiet 2>/dev/null; then
        echo "  Committing changes..."
        git commit -m "Update: Sync from main repo" 2>/dev/null || echo "  (No new changes to commit)"
    fi
    
    # Push to GitHub
    echo "  Pushing to GitHub..."
    if git push -u origin main 2>&1; then
        echo -e "${GREEN}  ✓ ${github_repo} pushed successfully${NC}"
    else
        # If push fails, try with --force (for first push or empty repos)
        echo -e "${YELLOW}  First push failed, trying with --force...${NC}"
        if git push -u origin main --force 2>&1; then
            echo -e "${GREEN}  ✓ ${github_repo} pushed successfully (force)${NC}"
        else
            echo -e "${RED}  ✗ Failed to push ${github_repo}${NC}"
            echo "  Error details above. Check your GitHub credentials and repo permissions."
        fi
    fi
    
    echo ""
done

echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Push complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Repos pushed:"
for local_dir in "${!REPO_MAP[@]}"; do
    github_repo="${REPO_MAP[$local_dir]}"
    echo "  - ${local_dir} → https://github.com/nuniesmith/${github_repo}"
done

