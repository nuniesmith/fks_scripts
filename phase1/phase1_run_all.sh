#!/bin/bash
# Phase 1: Run All Assessment Scripts
# Executes all Phase 1 assessment tasks and generates comprehensive report

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/docs/phase1_assessment"

echo "🚀 Starting Phase 1: Complete Assessment"
echo "=========================================="
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Change to project root
cd "$PROJECT_ROOT"

# Step 1: Run Repo Audit
echo "📊 Step 1: Running Repository Audit..."
echo "--------------------------------------"
python3 scripts/phase1/phase1_repo_audit.py
mv phase1_audit_report.* "$OUTPUT_DIR/" 2>/dev/null || true
echo "✅ Repository audit complete"
echo ""

# Step 2: Run Health Check Assessment
echo "🏥 Step 2: Running Health Check Assessment..."
echo "--------------------------------------------"
python3 scripts/phase1/phase1_health_check.py
mv phase1_health_report.* "$OUTPUT_DIR/" 2>/dev/null || true
echo "✅ Health check assessment complete"
echo ""

# Step 3: Generate Summary
echo "📋 Step 3: Generating Summary Report..."
echo "--------------------------------------"
cat > "$OUTPUT_DIR/PHASE1_SUMMARY.md" << 'EOF'
# Phase 1: Assessment Summary

**Generated**: $(date)

## Overview

This directory contains the complete Phase 1 assessment results.

## Reports

1. **Repository Audit**: `phase1_audit_report.md`
   - Comprehensive audit of all FKS repositories
   - Identifies gaps in testing, Docker, documentation
   - Prioritizes issues by severity

2. **Health Check Assessment**: `phase1_health_report.md`
   - Tests existing health endpoints
   - Identifies services missing health probes
   - Maps potential failure points

## Next Steps

1. Review both reports
2. Prioritize issues in GitHub Issues
3. Plan Phase 2: Immediate Fixes
4. Set baseline metrics for tracking

## Files

- `phase1_audit_report.json` - Machine-readable audit results
- `phase1_audit_report.md` - Human-readable audit report
- `phase1_health_report.json` - Machine-readable health check results
- `phase1_health_report.md` - Human-readable health check report
- `PHASE1_SUMMARY.md` - This file

EOF

# Replace date placeholder
sed -i "s/\$(date)/$(date -Iseconds)/" "$OUTPUT_DIR/PHASE1_SUMMARY.md"

echo "✅ Summary report generated"
echo ""

# Final summary
echo "=========================================="
echo "✅ Phase 1 Assessment Complete!"
echo "=========================================="
echo ""
echo "📁 Reports saved to: $OUTPUT_DIR"
echo ""
echo "📄 Files generated:"
echo "  - phase1_audit_report.json"
echo "  - phase1_audit_report.md"
echo "  - phase1_health_report.json"
echo "  - phase1_health_report.md"
echo "  - PHASE1_SUMMARY.md"
echo ""
echo "🎯 Next Steps:"
echo "  1. Review the reports in $OUTPUT_DIR"
echo "  2. Create GitHub Issues for high-priority findings"
echo "  3. Update todo/tasks/P0-critical/phase1-assessment.md"
echo "  4. Plan Phase 2 based on findings"
echo ""

