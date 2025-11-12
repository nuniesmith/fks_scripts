#!/usr/bin/env python3
"""
Test Bitcoin Signal Generation
Quick test script to verify Bitcoin signal generation works
"""

import requests
import json
import sys
from typing import Optional, Dict, Any

# Service URLs
DATA_SERVICE = "http://localhost:8003"
APP_SERVICE = "http://localhost:8002"
WEB_SERVICE = "http://localhost:8000"

# Colors
GREEN = '\033[0;32m'
RED = '\033[0;31m'
YELLOW = '\033[1;33m'
NC = '\033[0m'  # No Color


def test_service(name: str, url: str) -> bool:
    """Test if service is responding"""
    try:
        response = requests.get(f"{url}/health", timeout=5)
        if response.status_code == 200:
            print(f"{GREEN}✓{NC} {name} is running")
            return True
        else:
            print(f"{RED}✗{NC} {name} returned status {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"{RED}✗{NC} {name} is not responding: {e}")
        return False


def test_bitcoin_price() -> bool:
    """Test Bitcoin price fetch"""
    try:
        response = requests.get(
            f"{DATA_SERVICE}/api/v1/data/price",
            params={"symbol": "BTCUSDT"},
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            price = data.get("price", 0)
            print(f"{GREEN}✓{NC} Bitcoin price: ${price:,.2f}")
            return True
        else:
            print(f"{RED}✗{NC} Failed to fetch price: {response.status_code}")
            print(f"  Response: {response.text}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"{RED}✗{NC} Error fetching price: {e}")
        return False


def test_bitcoin_ohlcv() -> bool:
    """Test Bitcoin OHLCV fetch"""
    try:
        response = requests.get(
            f"{DATA_SERVICE}/api/v1/data/ohlcv",
            params={"symbol": "BTCUSDT", "interval": "1h", "limit": 100},
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            ohlcv_data = data.get("data", [])
            if len(ohlcv_data) > 0:
                print(f"{GREEN}✓{NC} Bitcoin OHLCV: {len(ohlcv_data)} candles")
                return True
            else:
                print(f"{YELLOW}⚠{NC} No OHLCV data returned")
                return False
        else:
            print(f"{RED}✗{NC} Failed to fetch OHLCV: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"{RED}✗{NC} Error fetching OHLCV: {e}")
        return False


def test_bitcoin_signal(strategy: Optional[str] = None, use_ai: bool = False) -> bool:
    """Test Bitcoin signal generation"""
    try:
        params = {
            "category": "swing",
            "use_ai": str(use_ai).lower()
        }
        if strategy:
            params["strategy"] = strategy
        
        response = requests.get(
            f"{APP_SERVICE}/api/v1/signals/latest/BTCUSDT",
            params=params,
            timeout=30
        )
        
        if response.status_code == 200:
            signal = response.json()
            signal_type = signal.get("signal_type", "UNKNOWN")
            confidence = signal.get("confidence", 0)
            entry_price = signal.get("entry_price", 0)
            take_profit = signal.get("take_profit", 0)
            stop_loss = signal.get("stop_loss", 0)
            
            print(f"{GREEN}✓{NC} Bitcoin signal generated")
            print(f"  Signal: {signal_type}")
            print(f"  Confidence: {confidence:.2%}")
            print(f"  Entry: ${entry_price:,.2f}")
            print(f"  Take Profit: ${take_profit:,.2f}")
            print(f"  Stop Loss: ${stop_loss:,.2f}")
            
            if signal_type == "HOLD":
                print(f"  {YELLOW}Note: Signal is HOLD (no trading opportunity){NC}")
            
            return True
        else:
            print(f"{RED}✗{NC} Failed to generate signal: {response.status_code}")
            print(f"  Response: {response.text}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"{RED}✗{NC} Error generating signal: {e}")
        return False


def main():
    """Main test function"""
    print("=== Bitcoin Signal Generation Test ===\n")
    
    # Test services
    print("Step 1: Testing Services")
    print("-" * 40)
    services_ok = (
        test_service("fks_data", DATA_SERVICE) and
        test_service("fks_app", APP_SERVICE) and
        test_service("fks_web", WEB_SERVICE)
    )
    
    if not services_ok:
        print(f"\n{RED}Error: Services are not running. Please start them first.{NC}")
        print("Run: ./repo/main/scripts/start-bitcoin-demo.sh")
        sys.exit(1)
    
    print()
    
    # Test data fetch
    print("Step 2: Testing Data Fetch")
    print("-" * 40)
    data_ok = test_bitcoin_price() and test_bitcoin_ohlcv()
    
    if not data_ok:
        print(f"\n{RED}Error: Failed to fetch Bitcoin data.{NC}")
        sys.exit(1)
    
    print()
    
    # Test signal generation
    print("Step 3: Testing Signal Generation")
    print("-" * 40)
    
    # Test different strategies
    strategies = [None, "rsi", "macd", "ema_swing"]
    
    for strategy in strategies:
        strategy_name = strategy or "auto"
        print(f"\nTesting strategy: {strategy_name}")
        signal_ok = test_bitcoin_signal(strategy=strategy, use_ai=False)
        
        if not signal_ok:
            print(f"{YELLOW}Warning: Strategy {strategy_name} failed{NC}")
    
    print()
    print(f"{GREEN}=== Test Complete ==={NC}\n")
    print("Next steps:")
    print("1. Open dashboard: http://localhost:8000/portfolio/signals/?symbols=BTCUSDT&category=swing")
    print("2. Review Bitcoin signals")
    print("3. Test approval workflow")
    print()


if __name__ == "__main__":
    main()

