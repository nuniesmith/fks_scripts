#!/bin/bash
# Grafana Dashboard Setup for FKS Execution Pipeline

set -e

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║              🎨 GRAFANA DASHBOARD SETUP - PATH A                        ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Configuration
GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="fks-grafana-admin-2025"
DASHBOARD_FILE="/home/jordan/fks/monitoring/grafana/dashboards/execution_pipeline.json"

echo "Step 1: Checking Grafana connectivity..."
if ! curl -s "${GRAFANA_URL}/api/health" | grep -q "ok"; then
    echo "❌ Grafana not accessible. Starting port-forward..."
    pkill -f "port-forward.*grafana" 2>/dev/null || true
    kubectl port-forward -n fks-trading svc/grafana 3000:3000 > /tmp/grafana-pf.log 2>&1 &
    sleep 8
    
    if ! curl -s "${GRAFANA_URL}/api/health" | grep -q "ok"; then
        echo "❌ Failed to connect to Grafana"
        echo "   Manual setup required:"
        echo "   kubectl port-forward -n fks-trading svc/grafana 3000:3000"
        exit 1
    fi
fi
echo "✅ Grafana is accessible"
echo ""

echo "Step 2: Configuring Prometheus datasource..."
# Check if datasource already exists
EXISTING_DS=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
    "${GRAFANA_URL}/api/datasources" | grep -c '"name":"Prometheus"' || echo "0")

if [ "$EXISTING_DS" -gt "0" ]; then
    echo "ℹ️  Prometheus datasource already exists"
else
    # Create Prometheus datasource
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
fi
echo ""

echo "Step 3: Importing Execution Pipeline dashboard..."
if [ ! -f "$DASHBOARD_FILE" ]; then
    echo "❌ Dashboard file not found: $DASHBOARD_FILE"
    exit 1
fi

# Import dashboard
IMPORT_RESPONSE=$(curl -s -X POST \
    -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
    -H "Content-Type: application/json" \
    "${GRAFANA_URL}/api/dashboards/db" \
    -d "{
      \"dashboard\": $(cat $DASHBOARD_FILE),
      \"overwrite\": true,
      \"message\": \"Imported via setup script\"
    }")

DASHBOARD_URL=$(echo "$IMPORT_RESPONSE" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)

if [ -n "$DASHBOARD_URL" ]; then
    echo "✅ Dashboard imported successfully"
    echo "   URL: ${GRAFANA_URL}${DASHBOARD_URL}"
else
    echo "⚠️  Dashboard import response: $IMPORT_RESPONSE"
fi
echo ""

echo "Step 4: Verifying setup..."
# List datasources
DS_COUNT=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
    "${GRAFANA_URL}/api/datasources" | grep -c '"type":"prometheus"' || echo "0")
echo "   Prometheus datasources: $DS_COUNT"

# List dashboards
DB_COUNT=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
    "${GRAFANA_URL}/api/search?type=dash-db" | grep -c '"title"' || echo "0")
echo "   Dashboards: $DB_COUNT"
echo ""

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║                        ✅ SETUP COMPLETE!                               ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "🌐 Access Grafana:"
echo "   URL: ${GRAFANA_URL}"
echo "   Username: ${GRAFANA_USER}"
echo "   Password: ${GRAFANA_PASS}"
echo ""
echo "📊 View Dashboard:"
if [ -n "$DASHBOARD_URL" ]; then
    echo "   ${GRAFANA_URL}${DASHBOARD_URL}"
else
    echo "   Go to Dashboards → Browse → Select 'Execution Pipeline'"
fi
echo ""
echo "🎯 Next Steps:"
echo "   1. Open Grafana in your browser"
echo "   2. Navigate to the Execution Pipeline dashboard"
echo "   3. Send test webhooks to see metrics:"
echo "      curl -X POST http://localhost:8000/webhook/tradingview \\"
echo "        -H 'Content-Type: application/json' \\"
echo "        -d '{\"symbol\":\"BTCUSDT\",\"side\":\"buy\",\"confidence\":0.85}'"
echo ""
