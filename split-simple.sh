#!/bin/bash
set -e

###############################################################################
# FKS Monorepo Split Script (Simplified)
###############################################################################

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SOURCE_REPO="/home/jordan/Documents/code/fks"
TEMP_BASE="/tmp/fks_split"
GIT_FILTER_REPO="$SOURCE_REPO/git-filter-repo"
GITHUB_USER="nuniesmith"

mkdir -p "$TEMP_BASE"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}FKS Monorepo Split${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to split one repository
split_one() {
    local repo_name=$1
    shift
    local paths=("$@")
    
    echo ""
    echo -e "${BLUE}>>> Splitting: $repo_name${NC}"
    
    local temp_dir="$TEMP_BASE/${repo_name}_temp"
    rm -rf "$temp_dir"
    
    echo "Cloning source..."
    git clone --quiet "$SOURCE_REPO" "$temp_dir"
    cd "$temp_dir"
    
    echo "Filtering paths..."
    local filter_cmd="$GIT_FILTER_REPO --force"
    for path in "${paths[@]}"; do
        filter_cmd="$filter_cmd --path $path"
        echo "  - $path"
    done
    
    eval "$filter_cmd" 2>&1 | grep -v "^Parsed" | head -5
    
    echo "Copying shared code..."
    mkdir -p shared
    [ -d "$SOURCE_REPO/src/shared" ] && rsync -a "$SOURCE_REPO/src/shared/" shared/shared/ 2>/dev/null || true
    
    echo "Creating README..."
    cat > README.md << EOF
# $repo_name

Part of FKS Trading Platform

## Installation
\`\`\`bash
pip install -r requirements.txt
\`\`\`

## Documentation
See: https://github.com/$GITHUB_USER/fks_main
EOF
    
    cat > .gitignore << 'EOF'
__pycache__/
*.pyc
.venv/
*.log
EOF
    
    git add . 2>/dev/null
    git commit -m "Add shared code and config" 2>/dev/null || true
    
    local commits=$(git log --oneline | wc -l)
    local files=$(find . -type f | wc -l)
    
    git remote remove origin 2>/dev/null || true
    git remote add origin "https://github.com/$GITHUB_USER/$repo_name.git"
    
    echo -e "${GREEN}✓ Complete: $commits commits, $files files${NC}"
    echo "  Location: $temp_dir"
    echo "  Remote: https://github.com/$GITHUB_USER/$repo_name.git"
}

# Split each repository
split_one fks_ai repo/ai/ src/services/ai/ notebooks/transformer/ tests/unit/test_rag/ tests/unit/test_sentiment/
split_one fks_api repo/api/
split_one fks_app repo/app/ tests/unit/strategies/asmbtr/
split_one fks_data repo/data/ data/market_data/
split_one fks_execution tests/unit/test_execution/ tests/integration/test_execution_pipeline.py
split_one fks_ninja repo/ninja/
split_one fks_meta scripts/devtools/scripts-meta/
split_one fks_web repo/web/

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}ALL REPOS SPLIT!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Split repos are in: $TEMP_BASE"
echo ""
echo "To push to GitHub:"
echo "  cd $TEMP_BASE/fks_ai_temp && git push -u origin main --force"
echo "  cd $TEMP_BASE/fks_api_temp && git push -u origin main --force"
echo "  # ... etc"
echo ""
