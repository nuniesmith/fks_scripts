#!/bin/bash
# Generate Day 1 Stability Test Report
# Creates comprehensive Day 1 review report
# Usage: ./generate_day1_report.sh [--date YYYY-MM-DD]

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
STABILITY_TEST_DIR="${STABILITY_TEST_DIR:-/home/jordan/Nextcloud/code/repos/fks/infrastructure/docs/06-PLANNING/stability-test}"
REPORT_DIR="${STABILITY_TEST_DIR}/reports"

# Parse date argument
TEST_DATE=""
if [ "$1" == "--date" ] && [ -n "$2" ]; then
    TEST_DATE="$2"
else
    TEST_DATE=$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d 2>/dev/null || echo "")
fi

if [ -z "$TEST_DATE" ]; then
    echo -e "${RED}Error: Could not determine test date${NC}"
    exit 1
fi

REPORT_FILE="${REPORT_DIR}/day1_report_${TEST_DATE}.md"
ANALYSIS_FILE="${REPORT_DIR}/day1_analysis_${TEST_DATE}.md"

echo -e "${BLUE}=== Generating Day 1 Report ===${NC}\n"

# Create report
cat > "$REPORT_FILE" <<EOF
# Day 1 Stability Test Report

**Date**: $TEST_DATE  
**Test Day**: 1 of 7  
**Report Generated**: $(date +%Y-%m-%d\ %H:%M:%S)

---

## Overview

This report summarizes the findings from Day 1 of the 7-day stability test. The test monitors all 15 FKS services continuously, checking health endpoints every 5 minutes.

---

## Service Health Summary

EOF

# Check if analysis file exists and include it
if [ -f "$ANALYSIS_FILE" ]; then
    echo -e "${GREEN}Including analysis from: $ANALYSIS_FILE${NC}"
    cat "$ANALYSIS_FILE" >> "$REPORT_FILE"
else
    echo -e "${YELLOW}⚠ Analysis file not found. Run analyze_day1_logs.sh first.${NC}"
    echo "" >> "$REPORT_FILE"
    echo "**Note**: Run \`analyze_day1_logs.sh\` to generate detailed analysis." >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
fi

cat >> "$REPORT_FILE" <<EOF

---

## Issues Identified

### Critical Issues
_(To be filled during review)_

### High Priority Issues
_(To be filled during review)_

### Medium Priority Issues
_(To be filled during review)_

### Low Priority Issues
_(To be filled during review)_

---

## Fixes Applied

### Critical Fixes
_(To be filled during review)_

### High Priority Fixes
_(To be filled during review)_

### Error Handling Improvements
_(To be filled during review)_

---

## Crypto Service Review

### fks_crypto Status
_(To be filled during review)_

### Crypto Dependencies
- **fks_data**: _(Status to be filled)_
- **fks_auth**: _(Status to be filled)_

### Crypto-Specific Issues
_(To be filled during review)_

### Crypto Fixes Applied
_(To be filled during review)_

---

## Error Handling Improvements

### Improvements Made
_(To be filled during review)_

### Recommendations
_(To be filled during review)_

---

## Monitoring Status

### Services Monitored
- All 15 services including fks_crypto
- Health checks every 5 minutes
- Comprehensive logging enabled

### Alert Status
- Critical alerts: _(To be filled)_
- Warning alerts: _(To be filled)_
- Info alerts: _(To be filled)_

---

## Next Steps

1. Continue monitoring all services
2. Fix non-critical issues
3. Document all fixes
4. Update stability report
5. Prepare for Day 2-3 review

---

## Metrics

### Overall Metrics
- **Total Health Checks**: _(To be calculated)_
- **Successful Checks**: _(To be calculated)_
- **Failed Checks**: _(To be calculated)_
- **Overall Uptime**: _(To be calculated)_
- **Average Response Time**: _(To be calculated)_

### Service-Specific Metrics
_(To be filled from analysis)_

---

**Report Status**: Draft  
**Next Review**: Day 2-3 (Day 38)

EOF

echo -e "${GREEN}✓ Day 1 report generated: ${CYAN}$REPORT_FILE${NC}"
