#!/bin/bash
# Generate Day 4 Stability Test Report
# Creates comprehensive Day 4 review report focusing on AI service, dashboard, and error recovery
# Usage: ./generate_day4_report.sh [--date YYYY-MM-DD]

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
    TEST_DATE=$(date -d "3 days ago" +%Y-%m-%d 2>/dev/null || date -v-3d +%Y-%m-%d 2>/dev/null || echo "")
fi

if [ -z "$TEST_DATE" ]; then
    echo -e "${RED}Error: Could not determine test date${NC}"
    exit 1
fi

REPORT_FILE="${REPORT_DIR}/day4_report_${TEST_DATE}.md"
ANALYSIS_FILE="${REPORT_DIR}/day4_analysis_${TEST_DATE}.md"

echo -e "${BLUE}=== Generating Day 4 Report ===${NC}\n"

# Create report
cat > "$REPORT_FILE" <<EOF
# Day 4 Stability Test Report

**Date**: $TEST_DATE  
**Test Day**: 4 of 7  
**Report Generated**: $(date +%Y-%m-%d\ %H:%M:%S)

---

## Overview

This report summarizes the findings from Day 4 of the 7-day stability test, focusing on:
- AI service (fks_ai) issues
- Dashboard (fks_web) issues
- Error recovery mechanisms
- Crypto service and dashboard issues

---

## Service Health Summary

EOF

# Check if analysis file exists and include it
if [ -f "$ANALYSIS_FILE" ]; then
    echo -e "${GREEN}Including analysis from: $ANALYSIS_FILE${NC}"
    cat "$ANALYSIS_FILE" >> "$REPORT_FILE"
else
    echo -e "${YELLOW}⚠ Analysis file not found. Run analyze_day4_logs.sh first.${NC}"
    echo "" >> "$REPORT_FILE"
    echo "**Note**: Run \`analyze_day4_logs.sh\` to generate detailed analysis." >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
fi

cat >> "$REPORT_FILE" <<EOF

---

## Issues Identified

### AI Service Issues
_(To be filled during review)_

**fks_ai Service Issues**:
- Model loading failures
- GPU/Ollama connection issues
- Timeout errors
- Memory issues
- Enhancement request failures

### Dashboard Issues
_(To be filled during review)_

**fks_web Service Issues**:
- Database connection problems
- Template rendering errors
- API endpoint failures
- Static file serving issues
- Session management problems

### Error Recovery Issues
_(To be filled during review)_

### Crypto Service Issues
_(To be filled during review)_

**fks_crypto Service Issues**:
- Crypto signal API failures
- Crypto data dependency issues
- Crypto authentication problems
- Crypto dashboard issues

---

## Fixes Applied

### AI Service Fixes
_(To be filled during review)_

### Dashboard Fixes
_(To be filled during review)_

### Error Recovery Improvements
_(To be filled during review)_

**Improvements Made**:
- Automatic retry mechanisms
- Circuit breakers for failing services
- Improved error handling and logging
- Health check recovery logic
- Exponential backoff for retries

### Crypto Service Fixes
_(To be filled during review)_

---

## Error Recovery Improvements

### Improvements Made
_(To be filled during review)_

### Areas Improved
1. Automatic retry mechanisms
2. Circuit breaker implementation
3. Error handling and logging
4. Health check recovery
5. Exponential backoff strategies

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
- Error recovery tracking enabled

### Alert Status
- Critical alerts: _(To be filled)_
- Warning alerts: _(To be filled)_
- Error recovery alerts: _(To be filled)_

---

## Next Steps

1. Continue monitoring all services
2. Verify fixes are working
3. Document all changes
4. Prepare stability report
5. Prepare for Day 5 review

---

## Metrics

### Overall Metrics (Day 4)
- **Total Health Checks**: _(To be calculated)_
- **Successful Checks**: _(To be calculated)_
- **Failed Checks**: _(To be calculated)_
- **Overall Uptime**: _(To be calculated)_
- **Error Recovery Rate**: _(To be calculated)_

### Service-Specific Metrics
_(To be filled from analysis)_

### Error Recovery Metrics
- **Services with Recovery Issues**: _(To be identified)_
- **Average Recovery Time**: _(To be calculated)_
- **Consecutive Error Counts**: _(To be analyzed)_

---

**Report Status**: Draft  
**Next Review**: Day 5 (if applicable) or Week 8 Review

EOF

echo -e "${GREEN}✓ Day 4 report generated: ${CYAN}$REPORT_FILE${NC}"
