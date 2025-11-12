#!/bin/bash
# Complete Standardization and Verification Workflow
# Runs standardization, then verifies all services

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "🔧 FKS Repository Standardization and Verification"
echo "==================================================="
echo ""

cd "$PROJECT_ROOT"

# Step 1: Standardize all repos
echo "📋 Step 1: Standardizing All Repositories..."
echo "--------------------------------------------"
python3 scripts/standardization/standardize_all_repos.py
echo ""

# Step 2: Verify all services
echo "🔍 Step 2: Verifying All Services..."
echo "------------------------------------"
./scripts/verification/verify_all_services.sh
echo ""

echo "✅ Standardization and verification complete!"
echo ""
echo "📊 Next Steps:"
echo "  1. Review standardization_report.md"
echo "  2. Fix any remaining issues manually"
echo "  3. Test services individually:"
echo "     cd repo/tools/monitor && docker-compose up --build"
echo "  4. Run Phase 1 assessment again to verify improvements"

