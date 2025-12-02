#!/bin/bash
###############################################################################
# FKS Repository Split Verification Script
# 
# Purpose: Verify what files will be included in each split repository
# Usage: ./verify-split.sh
###############################################################################

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

SOURCE_REPO="/home/jordan/Documents/code/fks"

# Repository path mappings
declare -A REPO_PATHS=(
    ["fks_ai"]="repo/ai/,src/services/ai/,notebooks/transformer/,tests/unit/test_rag/,tests/unit/test_sentiment/"
    ["fks_api"]="repo/api/,tests/integration/test_api"
    ["fks_app"]="repo/app/,data/asmbtr_real_data_optimization.json,tests/unit/test_asmbtr,tests/unit/strategies/asmbtr/"
    ["fks_data"]="repo/data/,data/market_data/,tests/integration/test_data"
    ["fks_execution"]="src/services/execution/,tests/unit/test_execution/,tests/integration/test_execution_pipeline.py"
    ["fks_ninja"]="repo/ninja/"
    ["fks_meta"]="scripts/devtools/scripts-meta/"
    ["fks_web"]="repo/web/,tests/unit/test_web"
)

echo "=========================================================================="
echo "          FKS Repository Split Verification"
echo "=========================================================================="
echo ""

cd "$SOURCE_REPO"

total_files=0

# Check each repository
for repo_name in $(echo "${!REPO_PATHS[@]}" | tr ' ' '\n' | sort); do
    echo -e "${BLUE}[$repo_name]${NC}"
    
    paths="${REPO_PATHS[$repo_name]}"
    IFS=',' read -ra PATH_ARRAY <<< "$paths"
    
    repo_file_count=0
    
    for path in "${PATH_ARRAY[@]}"; do
        path=$(echo "$path" | xargs)
        if [ -n "$path" ]; then
            if [ -e "$path" ]; then
                count=$(find "$path" -type f 2>/dev/null | wc -l)
                repo_file_count=$((repo_file_count + count))
                echo "  ✓ $path ($count files)"
            else
                echo -e "  ${YELLOW}⚠ $path (not found)${NC}"
            fi
        fi
    done
    
    total_files=$((total_files + repo_file_count))
    echo -e "${GREEN}  Total: $repo_file_count files${NC}"
    echo ""
done

echo "=========================================================================="
echo -e "${GREEN}Total files to be split: $total_files${NC}"
echo "=========================================================================="
echo ""

# Check for shared code
echo -e "${BLUE}[Shared Code]${NC}"
shared_count=0
if [ -d "src/shared" ]; then
    count=$(find src/shared -type f | wc -l)
    shared_count=$((shared_count + count))
    echo "  src/shared/ ($count files)"
fi
if [ -d "src/core" ]; then
    count=$(find src/core -type f | wc -l)
    shared_count=$((shared_count + count))
    echo "  src/core/ ($count files)"
fi
if [ -d "src/framework" ]; then
    count=$(find src/framework -type f | wc -l)
    shared_count=$((shared_count + count))
    echo "  src/framework/ ($count files)"
fi
echo -e "${GREEN}  Total shared: $shared_count files (will be duplicated to each repo)${NC}"
echo ""

echo "=========================================================================="
echo "Summary:"
echo "  Repositories: ${#REPO_PATHS[@]}"
echo "  Service files: $total_files"
echo "  Shared files: $shared_count (duplicated)"
echo "  Total after split: ~$((total_files + shared_count * ${#REPO_PATHS[@]})) files"
echo "=========================================================================="
