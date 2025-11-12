#!/bin/bash
# Commit and push all repos (including new extracted repos)
# This script is part of the FKS scripts repository

set -e

BASE_DIR="/home/jordan/Nextcloud/code/repos/fks/repo"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# All repos to process
# Note: Local directories use short names, GitHub repos use fks_ prefix
REPOS=(
    # Service repos (14)
    "ai" "analyze" "api" "app" "auth" "data" "execution" "main" 
    "meta" "monitor" "ninja" "portfolio" "training" "web"
    # Extracted repos (4) - local names
    "docs" "scripts" "nginx" "config"
)

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Committing and Pushing All Repos${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

SUCCESS_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0

for repo in "${REPOS[@]}"; do
    repo_path="${BASE_DIR}/${repo}"
    
    if [ ! -d "$repo_path" ]; then
        echo -e "${YELLOW}⚠ ${repo} not found, skipping...${NC}"
        ((SKIP_COUNT++))
        continue
    fi
    
    echo -e "${YELLOW}Processing ${repo}...${NC}"
    cd "$repo_path"
    
    # Check if git repo
    if [ ! -d ".git" ]; then
        echo -e "${RED}✗ Not a git repository${NC}"
        ((FAIL_COUNT++))
        continue
    fi
    
    # Check for changes
    if git diff --quiet && git diff --cached --quiet && [ -z "$(git status --porcelain)" ]; then
        echo -e "${GREEN}  ✓ No changes to commit${NC}"
        
        # Still try to push in case there are unpushed commits
        if git push 2>&1 | grep -q "Everything up-to-date\|Already up to date"; then
            echo -e "${GREEN}  ✓ Already up to date on remote${NC}"
        else
            echo -e "${GREEN}  ✓ Pushed to remote${NC}"
        fi
        ((SUCCESS_COUNT++))
        echo ""
        continue
    fi
    
    # Show status
    echo "  Changes detected:"
    git status --short | head -10 | sed 's/^/    /'
    if [ $(git status --short | wc -l) -gt 10 ]; then
        echo "    ... and more"
    fi
    
    # Add all changes
    git add -A
    
    # Commit
    COMMIT_MSG="Update: $(date +%Y-%m-%d)"
    if git commit -m "$COMMIT_MSG" 2>&1; then
        echo -e "${GREEN}  ✓ Committed changes${NC}"
    else
        echo -e "${YELLOW}  ⚠ No changes to commit or commit failed${NC}"
    fi
    
    # Push
    current_branch=$(git branch --show-current 2>/dev/null || echo "main")
    if [ "$current_branch" != "main" ] && [ "$current_branch" != "master" ]; then
        echo -e "${YELLOW}  ⚠ On branch ${current_branch}, not pushing${NC}"
        ((SKIP_COUNT++))
    else
        if git push 2>&1; then
            echo -e "${GREEN}  ✓ Pushed to remote${NC}"
            ((SUCCESS_COUNT++))
        else
            # Try with upstream if first push
            if git push -u origin "$current_branch" 2>&1; then
                echo -e "${GREEN}  ✓ Pushed to remote (with upstream)${NC}"
                ((SUCCESS_COUNT++))
            else
                echo -e "${RED}  ✗ Failed to push${NC}"
                ((FAIL_COUNT++))
            fi
        fi
    fi
    
    echo ""
done

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Summary:${NC}"
echo -e "  ${GREEN}✓ Success: ${SUCCESS_COUNT}${NC}"
echo -e "  ${YELLOW}⚠ Skipped: ${SKIP_COUNT}${NC}"
echo -e "  ${RED}✗ Failed: ${FAIL_COUNT}${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

