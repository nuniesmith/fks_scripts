#!/bin/bash
# Import FKS Platform Overview Dashboard to Grafana
# Uses direct JSON file import

set -e

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║        📊 FKS PLATFORM OVERVIEW DASHBOARD IMPORT                        ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Configuration
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-fks-grafana-admin-2025}"
DASHBOARD_FILE="${DASHBOARD_FILE:-infrastructure/main/monitoring/grafana/dashboards/fks_platform_overview.json}"

# Get absolute path to dashboard file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FULL_DASHBOARD_PATH="$REPO_ROOT/$DASHBOARD_FILE"

echo "Step 1: Checking Grafana connectivity..."
if ! curl -s "${GRAFANA_URL}/api/health" | grep -q "ok"; then
    echo "❌ Grafana not accessible at ${GRAFANA_URL}"
    echo "   Please ensure Grafana is running and accessible"
    exit 1
fi
echo "✅ Grafana is accessible"
echo ""

echo "Step 2: Checking dashboard file..."
if [ ! -f "$FULL_DASHBOARD_PATH" ]; then
    echo "❌ Dashboard file not found: $FULL_DASHBOARD_PATH"
    exit 1
fi
echo "✅ Dashboard file found: $FULL_DASHBOARD_PATH"
echo ""

echo "Step 3: Reading dashboard JSON..."
DASHBOARD_JSON=$(cat "$FULL_DASHBOARD_PATH")
if [ -z "$DASHBOARD_JSON" ]; then
    echo "❌ Failed to read dashboard JSON"
    exit 1
fi
echo "✅ Dashboard JSON loaded"
echo ""

echo "Step 4: Importing dashboard to Grafana..."
# Wrap dashboard JSON in the import format
IMPORT_PAYLOAD=$(jq -n \
  --argjson dashboard "$DASHBOARD_JSON" \
  '{
    dashboard: $dashboard,
    overwrite: true,
    inputs: []
  }')

IMPORT_RESPONSE=$(curl -s -X POST \
    -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
    -H "Content-Type: application/json" \
    "${GRAFANA_URL}/api/dashboards/db" \
    -d "$IMPORT_PAYLOAD")

# Check response
if echo "$IMPORT_RESPONSE" | grep -q '"url"'; then
    DASHBOARD_URL=$(echo "$IMPORT_RESPONSE" | jq -r '.url // empty')
    if [ -n "$DASHBOARD_URL" ]; then
        echo "✅ Dashboard imported successfully!"
        echo "   URL: ${GRAFANA_URL}${DASHBOARD_URL}"
    else
        echo "⚠️  Dashboard imported but could not extract URL"
        echo "   Response: $IMPORT_RESPONSE"
    fi
elif echo "$IMPORT_RESPONSE" | grep -q "Invalid username or password"; then
    echo "❌ Authentication failed"
    echo "   Please check GRAFANA_USER and GRAFANA_PASS environment variables"
    echo "   Current user: $GRAFANA_USER"
    echo ""
    echo "   You can manually import the dashboard:"
    echo "   1. Go to: ${GRAFANA_URL}/dashboard/import"
    echo "   2. Click 'Upload JSON file'"
    echo "   3. Select: $FULL_DASHBOARD_PATH"
    echo "   4. Click 'Import'"
    exit 1
elif echo "$IMPORT_RESPONSE" | grep -q "already exists"; then
    echo "ℹ️  Dashboard already exists (overwritten)"
    DASHBOARD_URL=$(echo "$IMPORT_RESPONSE" | jq -r '.url // empty')
    if [ -n "$DASHBOARD_URL" ]; then
        echo "   URL: ${GRAFANA_URL}${DASHBOARD_URL}"
    fi
else
    echo "⚠️  Unexpected response:"
    echo "$IMPORT_RESPONSE" | jq '.' 2>/dev/null || echo "$IMPORT_RESPONSE"
    echo ""
    echo "   You can manually import the dashboard:"
    echo "   1. Go to: ${GRAFANA_URL}/dashboard/import"
    echo "   2. Click 'Upload JSON file'"
    echo "   3. Select: $FULL_DASHBOARD_PATH"
    echo "   4. Click 'Import'"
fi
echo ""

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║                    ✅ IMPORT COMPLETE!                                  ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "🌐 Access Grafana:"
echo "   URL: ${GRAFANA_URL}"
echo ""
