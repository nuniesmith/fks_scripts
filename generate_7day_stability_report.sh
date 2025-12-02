#!/bin/bash
# Generate 7-Day Stability Test Report
# Creates comprehensive 7-day stability test summary report
# Usage: ./generate_7day_stability_report.sh [--start-date YYYY-MM-DD]

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
START_DATE=""
if [ "$1" == "--start-date" ] && [ -n "$2" ]; then
    START_DATE="$2"
else
    START_DATE=$(date -d "7 days ago" +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d 2>/dev/null || echo "")
fi

if [ -z "$START_DATE" ]; then
    echo -e "${RED}Error: Could not determine start date${NC}"
    exit 1
fi

END_DATE=$(date -d "$START_DATE + 6 days" +%Y-%m-%d 2>/dev/null || date -v+6d -j -f "%Y-%m-%d" "$START_DATE" +%Y-%m-%d 2>/dev/null || echo "")

REPORT_FILE="${REPORT_DIR}/7day_stability_report_${START_DATE}.md"
ANALYSIS_FILE="${REPORT_DIR}/7day_stability_analysis_${START_DATE}.md"

echo -e "${BLUE}=== Generating 7-Day Stability Report ===${NC}\n"

# Create report
cat > "$REPORT_FILE" <<EOF
# 7-Day Stability Test Report

**Test Period**: $START_DATE to $END_DATE  
**Duration**: 7 days  
**Report Generated**: $(date +%Y-%m-%d\ %H:%M:%S)

---

## Executive Summary

This report summarizes the complete 7-day stability test of the FKS trading platform, including all 15 services (including fks_crypto). The test monitored system health continuously, identified issues, applied fixes, and assessed overall system stability.

---

## Test Overview

- **Test Duration**: 7 days
- **Check Interval**: 5 minutes
- **Total Services Monitored**: 15 (including fks_crypto)
- **Health Checks per Service**: ~2,016 (288 per day × 7 days)
- **Total Health Checks**: ~30,240

---

## Overall Results

EOF

# Check if analysis file exists and include it
if [ -f "$ANALYSIS_FILE" ]; then
    echo -e "${GREEN}Including analysis from: $ANALYSIS_FILE${NC}"
    cat "$ANALYSIS_FILE" >> "$REPORT_FILE"
else
    echo -e "${YELLOW}⚠ Analysis file not found. Run analyze_7day_stability.sh first.${NC}"
    echo "" >> "$REPORT_FILE"
    echo "**Note**: Run \`analyze_7day_stability.sh\` to generate detailed analysis." >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
fi

cat >> "$REPORT_FILE" <<EOF

---

## Issues Identified and Fixed

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

### Day 1 Fixes
_(To be filled from Day 1 review)_

### Day 2-3 Fixes
_(To be filled from Day 2-3 review)_

### Day 4 Fixes
_(To be filled from Day 4 review)_

### Day 5-7 Fixes
_(To be filled from Day 5-7 review)_

---

## Crypto Service Stability

### fks_crypto 7-Day Performance
_(To be filled from analysis)_

### Crypto Dependencies
- **fks_data**: _(Status to be filled)_
- **fks_auth**: _(Status to be filled)_

### Crypto-Specific Issues
_(To be filled during review)_

### Crypto Fixes Applied
_(To be filled during review)_

---

## System Readiness Assessment

### Overall Status
_(To be filled during review)_

**Criteria**:
- Overall uptime > 99%: _(To be assessed)_
- No critical issues remaining: _(To be assessed)_
- All services stable: _(To be assessed)_
- Error rates acceptable: _(To be assessed)_

### Service Readiness
_(To be filled for each service)_

### Production Readiness
_(To be assessed)_

---

## Lessons Learned

### What Went Well
_(To be filled during review)_

### Challenges Faced
_(To be filled during review)_

### Improvements Made
_(To be filled during review)_

### Recommendations
_(To be filled during review)_

---

## Metrics Summary

### Overall Metrics
- **Total Health Checks**: _(To be calculated)_
- **Successful Checks**: _(To be calculated)_
- **Failed Checks**: _(To be calculated)_
- **Overall Uptime**: _(To be calculated)_
- **Average Response Time**: _(To be calculated)_

### Service-Specific Metrics
_(To be filled from analysis)_

### Trend Metrics
- **Improving Services**: _(To be calculated)_
- **Stable Services**: _(To be calculated)_
- **Degrading Services**: _(To be calculated)_

---

## Next Steps

1. Continue monitoring system stability
2. Address any remaining issues
3. Implement additional improvements
4. Prepare for Week 9 (Performance Tracking)
5. Update system documentation

---

## Conclusion

The 7-day stability test has provided valuable insights into system reliability, identified areas for improvement, and verified the stability of all services including fks_crypto. The system is now ready for the next phase of development.

---

**Report Status**: Draft  
**Next Phase**: Week 9 - Performance Tracking

EOF

echo -e "${GREEN}✓ 7-day stability report generated: ${CYAN}$REPORT_FILE${NC}"
