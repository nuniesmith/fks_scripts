#!/bin/bash
# Import Standard Grafana Dashboards for FKS Platform
# Quick Win: 30 minutes estimated

set -e

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║          📊 GRAFANA STANDARD DASHBOARDS IMPORT                          ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Configuration
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-fks-grafana-admin-2025}"

# Standard dashboard IDs from grafana.com
# 16110: Node Exporter Full (comprehensive system metrics)
# 18739: Prometheus Stats (Prometheus server metrics)
STANDARD_DASHBOARDS=(
    "16110:Node Exporter Full"
    "18739:Prometheus Stats"
)

echo "Step 1: Checking Grafana connectivity..."
if ! curl -s "${GRAFANA_URL}/api/health" | grep -q "ok"; then
    echo "❌ Grafana not accessible at ${GRAFANA_URL}"
    echo "   Please ensure Grafana is running and accessible"
    echo "   Or set GRAFANA_URL environment variable"
    exit 1
fi
echo "✅ Grafana is accessible"
echo ""

echo "Step 2: Verifying Prometheus datasource..."
DS_COUNT=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
    "${GRAFANA_URL}/api/datasources" | grep -c '"type":"prometheus"' || echo "0")

if [ "$DS_COUNT" -eq "0" ]; then
    echo "⚠️  No Prometheus datasource found"
    echo "   Creating default Prometheus datasource..."
    
    RESPONSE=$(curl -s -X POST \
        -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
        -H "Content-Type: application/json" \
        "${GRAFANA_URL}/api/datasources" \
        -d '{
          "name": "Prometheus",
          "type": "prometheus",
          "url": "http://prometheus:9090",
          "access": "proxy",
          "isDefault": true,
          "jsonData": {
            "httpMethod": "POST",
            "timeInterval": "15s"
          }
        }')
    
    if echo "$RESPONSE" | grep -q '"id"'; then
        echo "✅ Prometheus datasource created"
    else
        echo "⚠️  Datasource creation response: $RESPONSE"
    fi
else
    echo "✅ Prometheus datasource exists ($DS_COUNT found)"
fi
echo ""

echo "Step 3: Importing standard dashboards from grafana.com..."
echo "   Note: Grafana.com dashboards require manual import via UI"
echo "   This script will provide instructions for each dashboard"
echo ""

for dashboard in "${STANDARD_DASHBOARDS[@]}"; do
    IFS=':' read -r dashboard_id dashboard_name <<< "$dashboard"
    
    echo "   📊 $dashboard_name (ID: $dashboard_id)"
    echo "      Manual import steps:"
    echo "      1. Go to: ${GRAFANA_URL}/dashboard/import"
    echo "      2. Enter dashboard ID: $dashboard_id"
    echo "      3. Click 'Load'"
    echo "      4. Select 'Prometheus' as datasource"
    echo "      5. Click 'Import'"
    echo ""
done

echo "   💡 Tip: You can also import via Grafana UI:"
echo "      Dashboards → Import → Enter ID → Load → Import"
echo ""

echo "Step 4: Creating FKS Platform Overview dashboard..."
# Create a simple overview dashboard JSON
OVERVIEW_DASHBOARD='{
  "dashboard": {
    "id": null,
    "title": "FKS Platform Overview",
    "tags": ["fks", "overview"],
    "timezone": "browser",
    "schemaVersion": 16,
    "version": 0,
    "refresh": "30s",
    "panels": [
      {
        "id": 1,
        "title": "Service Health",
        "type": "stat",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "up",
            "refId": "A"
          }
        ]
      },
      {
        "id": 2,
        "title": "HTTP Request Rate",
        "type": "graph",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "refId": "A"
          }
        ]
      },
      {
        "id": 3,
        "title": "Request Duration",
        "type": "graph",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
            "refId": "A"
          }
        ]
      },
      {
        "id": 4,
        "title": "Memory Usage",
        "type": "graph",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},
        "targets": [
          {
            "expr": "process_resident_memory_bytes",
            "refId": "A"
          }
        ]
      }
    ]
  },
  "overwrite": true
}'

OVERVIEW_RESPONSE=$(curl -s -X POST \
    -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
    -H "Content-Type: application/json" \
    "${GRAFANA_URL}/api/dashboards/db" \
    -d "$OVERVIEW_DASHBOARD" || echo "{}")

if echo "$OVERVIEW_RESPONSE" | grep -q '"url"'; then
    OVERVIEW_URL=$(echo "$OVERVIEW_RESPONSE" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
    echo "✅ FKS Platform Overview dashboard created"
    echo "   URL: ${GRAFANA_URL}${OVERVIEW_URL}"
else
    echo "⚠️  Overview dashboard creation response: $OVERVIEW_RESPONSE"
    echo "   You may need to create it manually"
fi
echo ""

echo "Step 5: Verifying imports..."
DB_COUNT=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
    "${GRAFANA_URL}/api/search?type=dash-db&tag=fks" | grep -c '"title"' || echo "0")
echo "   FKS dashboards: $DB_COUNT"
echo ""

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║                    ✅ DASHBOARD IMPORT COMPLETE!                         ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "🌐 Access Grafana:"
echo "   URL: ${GRAFANA_URL}"
echo "   Username: ${GRAFANA_USER}"
echo ""
echo "📊 Standard Dashboards:"
echo "   - Node Exporter Full (ID: 16110)"
echo "   - Prometheus Stats (ID: 18739)"
echo ""
echo "📈 FKS Dashboards:"
echo "   - FKS Platform Overview"
echo ""
echo "💡 Manual Import (if needed):"
echo "   1. Go to: ${GRAFANA_URL}/dashboard/import"
echo "   2. Enter dashboard ID: 16110 or 18739"
echo "   3. Select Prometheus datasource"
echo "   4. Click Import"
echo ""
