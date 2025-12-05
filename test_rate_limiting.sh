#!/bin/bash
# Simple wrapper script for rate limiting tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="${SCRIPT_DIR}/test_rate_limiting.py"

# Check if Python script exists
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "ERROR: Test script not found: $PYTHON_SCRIPT"
    exit 1
fi

# Check if requests library is installed
if ! python3 -c "import requests" 2>/dev/null; then
    echo "ERROR: 'requests' library not found."
    echo "Install it with: pip install requests"
    exit 1
fi

# Run the Python script with all arguments
exec python3 "$PYTHON_SCRIPT" "$@"
