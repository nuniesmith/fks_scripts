#!/bin/bash
# Extract docs, scripts, nginx, config from main repo into separate repos
# This script helps set up the new repos and add remotes
# This script is part of the FKS scripts repository

set -e

MAIN_REPO="/home/jordan/Nextcloud/code/repos/fks/repo/main"
BASE_DIR="/home/jordan/Nextcloud/code/repos/fks/repo"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Extracting repos from main...${NC}"

# Function to extract a directory to a new repo
extract_repo() {
    local dir_name=$1
    local repo_name=$2
    local github_user="nuniesmith"
    local github_url="https://github.com/${github_user}/${repo_name}.git"
    
    echo -e "${YELLOW}Extracting ${dir_name} to ${repo_name}...${NC}"
    
    # Create the new repo directory
    local new_repo_path="${BASE_DIR}/${repo_name}"
    
    if [ -d "$new_repo_path" ]; then
        echo -e "${YELLOW}Directory ${new_repo_path} already exists.${NC}"
        read -p "Do you want to continue and update it? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping ${repo_name}..."
            return
        fi
    else
        # Create new directory
        mkdir -p "$new_repo_path"
    fi
    
    # Copy the directory contents
    if [ -d "${MAIN_REPO}/${dir_name}" ]; then
        echo "Copying files from ${MAIN_REPO}/${dir_name}..."
        cp -r "${MAIN_REPO}/${dir_name}"/* "$new_repo_path/" 2>/dev/null || true
        cp -r "${MAIN_REPO}/${dir_name}"/.[!.]* "$new_repo_path/" 2>/dev/null || true
        echo -e "${GREEN}✓ Files copied${NC}"
    else
        echo -e "${RED}Warning: ${MAIN_REPO}/${dir_name} does not exist${NC}"
        return
    fi
    
    # Initialize git repo if not already initialized
    cd "$new_repo_path"
    if [ ! -d ".git" ]; then
        git init
        echo -e "${GREEN}✓ Git repository initialized${NC}"
    fi
    
    # Add all files
    git add .
    
    # Check if there are changes to commit
    if git diff --staged --quiet && git diff --quiet; then
        echo -e "${YELLOW}No changes to commit${NC}"
    else
        git commit -m "Initial commit: Extract ${dir_name} from main repo" || \
        git commit -m "Update: Extract ${dir_name} from main repo"
        echo -e "${GREEN}✓ Changes committed${NC}"
    fi
    
    # Add remote if it doesn't exist
    if ! git remote get-url origin >/dev/null 2>&1; then
        git remote add origin "$github_url"
        echo -e "${GREEN}✓ Remote added: ${github_url}${NC}"
    else
        # Update remote URL if it's different
        current_url=$(git remote get-url origin)
        if [ "$current_url" != "$github_url" ]; then
            git remote set-url origin "$github_url"
            echo -e "${GREEN}✓ Remote URL updated: ${github_url}${NC}"
        else
            echo -e "${GREEN}✓ Remote already configured: ${github_url}${NC}"
        fi
    fi
    
    # Set main branch
    git branch -M main 2>/dev/null || true
    
    echo -e "${GREEN}✓ ${repo_name} ready${NC}"
    echo ""
}

# Extract each directory
extract_repo "docs" "fks_docs"
extract_repo "scripts" "fks_scripts"
extract_repo "nginx" "fks_nginx"
extract_repo "config" "fks_config"

echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Extraction complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Next steps to push to GitHub:${NC}"
echo ""
echo "For each repo, run:"
echo ""
for repo in fks_docs fks_scripts fks_nginx fks_config; do
    echo -e "${BLUE}cd ${BASE_DIR}/${repo}${NC}"
    echo -e "${BLUE}git push -u origin main${NC}"
    echo ""
done
echo -e "${YELLOW}Note:${NC} If the repos are empty on GitHub, you may need to use:"
echo -e "${BLUE}git push -u origin main --force${NC}"
echo ""
echo -e "${YELLOW}After pushing, you can:${NC}"
echo "1. Update main repo to reference these as submodules (optional)"
echo "2. Or keep them as separate repos and update documentation"

