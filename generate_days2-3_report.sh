#!/bin/bash
# Generate Day 2-3 Stability Test Report
# Creates comprehensive Day 2-3 review report focusing on patterns and improvements
# Usage: ./generate_days2-3_report.sh [--start-date YYYY-MM-DD]

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
    START_DATE=$(date -d "2 days ago" +%Y-%m-%d 2>/dev/null || date -v-2d +%Y-%m-%d 2>/dev/null || echo "")
fi

if [ -z "$START_DATE" ]; then
    echo -e "${RED}Error: Could not determine start date${NC}"
    exit 1
fi

DAY2_DATE=$START_DATE
DAY3_DATE=$(date -d "$START_DATE + 1 day" +%Y-%m-%d 2>/dev/null || date -v+1d -j -f "%Y-%m-%d" "$START_DATE" +%Y-%m-%d 2>/dev/null || echo "")

REPORT_FILE="${REPORT_DIR}/days2-3_report_${START_DATE}.md"
ANALYSIS_FILE="${REPORT_DIR}/days2-3_analysis_${START_DATE}.md"

echo -e "${BLUE}=== Generating Day 2-3 Report ===${NC}\n"

# Create report
cat > "$REPORT_FILE" <<EOF
# Day 2-3 Stability Test Report

**Day 2 Date**: $DAY2_DATE  
**Day 3 Date**: $DAY3_DATE  
**Test Days**: 2-3 of 7  
**Report Generated**: $(date +%Y-%m-%d\ %H:%M:%S)

---

## Overview

This report summarizes the findings from Days 2-3 of the 7-day stability test, focusing on pattern identification, data collection issues, signal generation problems, and reliability improvements.

---

## Pattern Analysis

EOF

# Check if analysis file exists and include it
if [ -f "$ANALYSIS_FILE" ]; then
    echo -e "${GREEN}Including analysis from: $ANALYSIS_FILE${NC}"
    cat "$ANALYSIS_FILE" >> "$REPORT_FILE"
else
    echo -e "${YELLOW}⚠ Analysis file not found. Run analyze_days2-3_logs.sh first.${NC}"
    echo "" >> "$REPORT_FILE"
    echo "**Note**: Run \`analyze_days2-3_logs.sh\` to generate detailed analysis." >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
fi

cat >> "$REPORT_FILE" <<EOF

---

## Issues Identified

### Data Collection Issues
_(To be filled during review)_

**fks_data Service Issues**:
- API rate limits
- Network connectivity
- Data provider issues
- Database connection problems

### Signal Generation Issues
_(To be filled during review)_

**fks_app (Traditional Signals) Issues**:
- Signal calculation errors
- Data dependency problems
- AI enhancement failures
- Schedule execution issues

**fks_crypto (Crypto Signals) Issues**:
- Crypto signal generation errors
- DCA bot issues
- Crypto data dependency problems
- Prop firm rules validation issues

### Reliability Issues
_(To be filled during review)_

---

## Fixes Applied

### Data Collection Fixes
_(To be filled during review)_

### Signal Generation Fixes
_(To be filled during review)_

**Traditional Signals (fks_app)**:
_(To be filled)_

**Crypto Signals (fks_crypto)**:
_(To be filled)_

### Reliability Improvements
_(To be filled during review)_

---

## Pattern Analysis

### Error Patterns
_(To be filled from analysis)_

### Time-Based Patterns
_(To be filled from analysis)_

### Service Dependencies
_(To be filled from analysis)_

---

## Crypto Service Review (Days 2-3)

### fks_crypto Status
_(To be filled during review)_

### Crypto Dependencies
- **fks_data**: _(Status to be filled)_
- **fks_auth**: _(Status to be filled)_

### Crypto Signal Generation Issues
_(To be filled during review)_

### Crypto Fixes Applied
_(To be filled during review)_

---

## Reliability Improvements

### Improvements Made
_(To be filled during review)_

### Areas Improved
1. Data collection reliability
2. Signal generation reliability
3. Error handling
4. Dependency management
5. Monitoring and alerting

### Recommendations
_(To be filled during review)_

---

## Testing Status

### Fixes Tested
_(To be filled during review)_

### Test Results
_(To be filled during review)_

### Verification
_(To be filled during review)_

---

## Monitoring Status

### Services Monitored
- All 15 services including fks_crypto
- Health checks every 5 minutes
- Pattern analysis enabled

### Alert Status
- Critical alerts: _(To be filled)_
- Warning alerts: _(To be filled)_
- Pattern-based alerts: _(To be filled)_

---

## Next Steps

1. Continue monitoring all services
2. Verify fixes are working
3. Document all improvements
4. Update stability report
5. Prepare for Day 4-5 review

---

## Metrics

### Overall Metrics (Days 2-3)
- **Total Health Checks**: _(To be calculated)_
- **Successful Checks**: _(To be calculated)_
- **Failed Checks**: _(To be calculated)_
- **Overall Uptime**: _(To be calculated)_
- **Trend**: _(Improving/Stable/Degrading)_

### Service-Specific Metrics
_(To be filled from analysis)_

### Pattern Metrics
- **Most Common Errors**: _(To be identified)_
- **Error Time Patterns**: _(To be identified)_
- **Service Dependencies**: _(To be analyzed)_

---

**Report Status**: Draft  
**Next Review**: Day 4-5 (Day 39)

EOF

echo -e "${GREEN}✓ Day 2-3 report generated: ${CYAN}$REPORT_FILE${NC}"
