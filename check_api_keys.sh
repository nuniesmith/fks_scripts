#!/bin/bash
# Check API keys for fks_data service adapters
# TASK-024: API Key Status Report

echo "============================================================"
echo "FKS Data Service - API Key Status Report"
echo "Date: $(date)"
echo "============================================================"
echo ""

# Define adapters and their environment variable names
declare -A ADAPTERS
ADAPTERS[binance]="BINANCE_API_KEY"
ADAPTERS[polygon]="POLYGON_API_KEY FKS_POLYGON_API_KEY"
ADAPTERS[alphavantage]="ALPHA_API_KEY ALPHAVANTAGE_API_KEY FKS_ALPHA_VANTAGE_API_KEY"
ADAPTERS[coingecko]="COINGECKO_API_KEY"
ADAPTERS[coinmarketcap]="CMC_API_KEY COINMARKETCAP_API_KEY FKS_CMC_API_KEY"
ADAPTERS[eodhd]="EODHD_API_KEY"

# Required vs Optional
declare -A REQUIRED
REQUIRED[binance]="NO"
REQUIRED[polygon]="YES"
REQUIRED[alphavantage]="YES"
REQUIRED[coingecko]="NO"
REQUIRED[coinmarketcap]="YES"
REQUIRED[eodhd]="YES"

echo "Adapter Name | Status        | Variable(s) Checked | Required"
echo "------------|---------------|---------------------|----------"

for adapter in "${!ADAPTERS[@]}"; do
    vars="${ADAPTERS[$adapter]}"
    required="${REQUIRED[$adapter]}"
    
    found=false
    found_var=""
    
    for var in $vars; do
        value=$(eval "echo \${$var:-}")
        if [ -n "$value" ]; then
            found=true
            found_var="$var"
            length=${#value}
            # Mask the key value (show only first 4 and last 4 chars)
            if [ $length -gt 8 ]; then
                masked="${value:0:4}...${value: -4}"
            else
                masked="[CONFIGURED]"
            fi
            printf "%-12s | %-13s | %-19s | %s\n" "$adapter" "[CONFIGURED]" "$found_var" "$required"
            found=true
            break
        fi
    done
    
    if [ "$found" = false ]; then
        if [ "$required" = "YES" ]; then
            status="[MISSING ❌]"
        else
            status="[NOT SET]"
        fi
        printf "%-12s | %-13s | %-19s | %s\n" "$adapter" "$status" "${vars%% *}" "$required"
        # Show all alternative variable names
        for var in $vars; do
            if [ "$var" != "${vars%% *}" ]; then
                printf "%-12s | %-13s | %-19s | %s\n" "" "" "  or: $var" ""
            fi
        done
    fi
done

echo ""
echo "============================================================"
echo "Summary:"
echo "============================================================"

configured=0
missing=0

for adapter in "${!ADAPTERS[@]}"; do
    vars="${ADAPTERS[$adapter]}"
    required="${REQUIRED[$adapter]}"
    
    found=false
    for var in $vars; do
        value=$(eval "echo \${$var:-}")
        if [ -n "$value" ]; then
            found=true
            break
        fi
    done
    
    if [ "$found" = true ]; then
        configured=$((configured + 1))
    else
        if [ "$required" = "YES" ]; then
            missing=$((missing + 1))
        fi
    fi
done

echo "Configured: $configured / ${#ADAPTERS[@]} adapters"
echo "Missing (required): $missing"

echo ""
echo "Note: API keys should be set in your environment or .env file"
echo "      and passed to Docker containers via docker-compose.yml"
