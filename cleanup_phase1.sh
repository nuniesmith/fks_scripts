#!/bin/bash
# Quick Start Script for Monorepo Refactoring
# Phase 1: Clean up duplicates and fix nested core/core issue

set -e  # Exit on error

REPO_ROOT="/home/jordan/Documents/code/fks"
BACKUP_DIR="$HOME/fks-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================================================"
echo "FKS Monorepo Cleanup - Phase 1"
echo "======================================================================"
echo ""

# Check if we're in the right directory
if [ ! -f "$REPO_ROOT/manage.py" ]; then
    echo -e "${RED}Error: Not in FKS repo root. Please run from $REPO_ROOT${NC}"
    exit 1
fi

cd "$REPO_ROOT"

# Step 1: Create backup
echo -e "${YELLOW}Step 1: Creating backup...${NC}"
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/fks-src-backup-$TIMESTAMP.tar.gz"

if tar -czf "$BACKUP_FILE" src/ 2>/dev/null; then
    echo -e "${GREEN}✓ Backup created: $BACKUP_FILE${NC}"
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "  Size: $BACKUP_SIZE"
else
    echo -e "${RED}✗ Backup failed. Exiting for safety.${NC}"
    exit 1
fi
echo ""

# Step 2: Analyze current state
echo -e "${YELLOW}Step 2: Analyzing current state...${NC}"
python3 scripts/analyze_duplication.py > "$BACKUP_DIR/duplication-analysis-$TIMESTAMP.txt"
echo -e "${GREEN}✓ Analysis saved to $BACKUP_DIR/duplication-analysis-$TIMESTAMP.txt${NC}"
echo ""

# Step 3: Interactive decision
echo -e "${YELLOW}Step 3: Choose cleanup strategy${NC}"
echo ""
echo "Current situation:"
echo "  - src/core, src/framework, src/monitor (root level)"
echo "  - src/shared/core, src/shared/framework, src/shared/monitor (shared level)"
echo "  - src/shared/core/core (NESTED - needs fix)"
echo ""
echo "Options:"
echo "  A) Keep src/shared/ and remove root duplicates (RECOMMENDED for future)"
echo "  B) Keep root level and remove src/shared/ (simpler short-term)"
echo "  C) Cancel and review manually"
echo ""
read -p "Choose option (A/B/C): " choice

case $choice in
    [Aa]*)
        echo ""
        echo -e "${GREEN}Option A selected: Keep src/shared/, remove root duplicates${NC}"
        
        # Fix nested core/core first
        echo -e "${YELLOW}Fixing nested core/core issue...${NC}"
        if [ -d "src/shared/core/core" ]; then
            rm -rf src/shared/core/core/
            echo -e "${GREEN}✓ Removed src/shared/core/core/${NC}"
        fi
        
        # Remove root duplicates
        echo -e "${YELLOW}Removing root level duplicates...${NC}"
        rm -rf src/core/
        rm -rf src/framework/
        rm -rf src/monitor/
        echo -e "${GREEN}✓ Removed src/core, src/framework, src/monitor${NC}"
        
        echo ""
        echo -e "${YELLOW}Updating imports...${NC}"
        # Update imports in remaining src files (excluding shared/)
        find src/ -name "*.py" -type f ! -path "*/shared/*" -exec sed -i 's/^from core\./from src.shared.core./g' {} \;
        find src/ -name "*.py" -type f ! -path "*/shared/*" -exec sed -i 's/^from framework\./from src.shared.framework./g' {} \;
        find src/ -name "*.py" -type f ! -path "*/shared/*" -exec sed -i 's/^from monitor\./from src.shared.monitor./g' {} \;
        find src/ -name "*.py" -type f ! -path "*/shared/*" -exec sed -i 's/^import core$/import src.shared.core/g' {} \;
        find src/ -name "*.py" -type f ! -path "*/shared/*" -exec sed -i 's/^import framework$/import src.shared.framework/g' {} \;
        echo -e "${GREEN}✓ Import statements updated${NC}"
        
        CLEANUP_MODE="keep_shared"
        ;;
    [Bb]*)
        echo ""
        echo -e "${GREEN}Option B selected: Keep root level, remove src/shared/${NC}"
        
        echo -e "${YELLOW}Removing src/shared/ directory...${NC}"
        rm -rf src/shared/
        echo -e "${GREEN}✓ Removed src/shared/${NC}"
        
        CLEANUP_MODE="keep_root"
        ;;
    [Cc]*)
        echo ""
        echo -e "${YELLOW}Cleanup cancelled. Backup saved at: $BACKUP_FILE${NC}"
        echo "Review the analysis at: $BACKUP_DIR/duplication-analysis-$TIMESTAMP.txt"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option. Exiting.${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${YELLOW}Step 4: Verification${NC}"

# Check what's left
echo "Remaining directories:"
ls -la src/ | grep "^d" | awk '{print "  - " $9}' | grep -v "^\.$\|^\.\.$"

echo ""
echo -e "${YELLOW}Step 5: Running tests...${NC}"
if command -v make &> /dev/null && [ -f "Makefile" ]; then
    echo "Running make test..."
    if make test 2>&1 | tee "$BACKUP_DIR/test-results-$TIMESTAMP.txt"; then
        echo -e "${GREEN}✓ Tests passed!${NC}"
    else
        echo -e "${RED}✗ Tests failed. Check $BACKUP_DIR/test-results-$TIMESTAMP.txt${NC}"
        echo "You can restore from backup: tar -xzf $BACKUP_FILE"
    fi
else
    echo -e "${YELLOW}Makefile not found, skipping automated tests${NC}"
fi

echo ""
echo "======================================================================"
echo -e "${GREEN}Phase 1 Cleanup Complete!${NC}"
echo "======================================================================"
echo ""
echo "Summary:"
echo "  - Backup: $BACKUP_FILE"
echo "  - Analysis: $BACKUP_DIR/duplication-analysis-$TIMESTAMP.txt"
echo "  - Mode: $CLEANUP_MODE"
echo ""
echo "Next steps:"
echo "  1. Review the changes with: git status"
echo "  2. Run manual tests"
echo "  3. Commit changes: git add . && git commit -m 'refactor: Phase 1 - Remove duplicate directories'"
echo "  4. Proceed to Phase 2: Read docs/MONOREPO_REFACTOR_PLAN.md"
echo ""
echo "To restore if needed:"
echo "  cd $REPO_ROOT && tar -xzf $BACKUP_FILE"
echo ""
