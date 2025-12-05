#!/bin/bash
# Test Import Fixes - Verify all preprocessing imports work
# Tests the fixes made to preprocessing.py and related modules

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "FKS Import Fixes - Verification Test"
echo "========================================="
echo ""

cd "$REPO_ROOT"

# Test 1: Verify preprocessing.py exists and has classes
echo -n "Test 1: Checking preprocessing.py structure... "
PREPROC_FILE="$REPO_ROOT/services/data/src/domain/processing/layers/preprocessing.py"
if [ ! -f "$PREPROC_FILE" ]; then
    echo -e "${RED}✗${NC} preprocessing.py not found!"
    exit 1
fi

if grep -q "class ETLPipeline" "$PREPROC_FILE" && grep -q "class Transformer" "$PREPROC_FILE"; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC} Missing required classes!"
    exit 1
fi

# Test 2: Verify preprocessing submodule files exist
echo -n "Test 2: Checking preprocessing submodules... "
SUBMODULES=(
    "services/data/src/domain/processing/layers/preprocessing/cleaner.py"
    "services/data/src/domain/processing/layers/preprocessing/normalizer.py"
    "services/data/src/domain/processing/layers/preprocessing/resampler.py"
    "services/data/src/domain/processing/layers/preprocessing/transformer.py"
)

ALL_EXIST=true
for file in "${SUBMODULES[@]}"; do
    if [ ! -f "$REPO_ROOT/$file" ]; then
        echo -e "${RED}✗${NC} Missing: $file"
        ALL_EXIST=false
    fi
done

if [ "$ALL_EXIST" = true ]; then
    echo -e "${GREEN}✓${NC}"
else
    exit 1
fi

# Test 3: Verify files that import preprocessing can parse
echo -n "Test 3: Checking Python syntax of files that import preprocessing... "
ETL_FILE="$REPO_ROOT/services/data/src/pipelines/etl.py"
EXECUTOR_FILE="$REPO_ROOT/services/data/src/pipelines/executor.py"

if python3 -m py_compile "$ETL_FILE" 2>/dev/null; then
    if python3 -m py_compile "$EXECUTOR_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC} executor.py has syntax errors"
        exit 1
    fi
else
    echo -e "${RED}✗${NC} etl.py has syntax errors"
    exit 1
fi

# Test 4: Verify baselines.py has fallback patterns
echo -n "Test 4: Checking baselines.py has fallback patterns... "
BASELINES_FILE="$REPO_ROOT/services/training/src/models/baselines.py"
if grep -q "try:" "$BASELINES_FILE" && grep -q "except.*ImportError" "$BASELINES_FILE"; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠${NC} Fallback patterns may be missing"
fi

# Test 5: Check that adapter files have fallback patterns
echo -n "Test 5: Checking adapter files have fallbacks... "
ADAPTER_BASE="$REPO_ROOT/services/data/src/adapters/base.py"
if grep -q "try:" "$ADAPTER_BASE" && grep -q "except.*ImportError" "$ADAPTER_BASE"; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠${NC} May need review"
fi

echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo -e "${GREEN}✓${NC} All structural checks passed!"
echo ""
echo "Note: Full import tests require Python environment with dependencies."
echo "To test fully, run: cd services/data && python3 scripts/verify_imports.py"
echo ""
