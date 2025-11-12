#!/usr/bin/env python3
"""
Phase 2 Integration Testing Script
Tests the complete signal flow: data → signal → dashboard → execution
"""

import json
import urllib.request
import urllib.error
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from datetime import datetime
import time

class Phase2Tester:
    def __init__(self):
        self.services = {
            "fks_data": "http://localhost:8003",
            "fks_app": "http://localhost:8002",
            "fks_ai": "http://localhost:8007",
            "fks_execution": "http://localhost:8004",
            "fks_web": "http://localhost:8000"
        }
        self.results = {
            "passed": [],
            "failed": [],
            "warnings": [],
            "summary": {}
        }
    
    def test_service_health(self, service_name: str, base_url: str) -> Tuple[bool, str]:
        """Test service health endpoint"""
        try:
            url = f"{base_url}/health"
            req = urllib.request.Request(url)
            req.add_header('User-Agent', 'FKS-Phase2-Tester/1.0')
            with urllib.request.urlopen(req, timeout=5) as response:
                if response.getcode() == 200:
                    return True, "OK"
                else:
                    return False, f"Status {response.getcode()}"
        except urllib.error.URLError as e:
            return False, f"Connection error: {str(e)}"
        except Exception as e:
            return False, f"Error: {str(e)}"
    
    def test_data_price(self, symbol: str = "BTCUSDT") -> Tuple[bool, Optional[Dict]]:
        """Test data price endpoint"""
        try:
            url = f"{self.services['fks_data']}/api/v1/data/price?symbol={symbol}"
            req = urllib.request.Request(url)
            with urllib.request.urlopen(req, timeout=10) as response:
                if response.getcode() == 200:
                    data = json.loads(response.read().decode())
                    return True, data
                else:
                    return False, None
        except Exception as e:
            return False, None
    
    def test_data_ohlcv(self, symbol: str = "BTCUSDT") -> Tuple[bool, Optional[Dict]]:
        """Test data OHLCV endpoint"""
        try:
            url = f"{self.services['fks_data']}/api/v1/data/ohlcv?symbol={symbol}&interval=1h"
            req = urllib.request.Request(url)
            with urllib.request.urlopen(req, timeout=10) as response:
                if response.getcode() == 200:
                    data = json.loads(response.read().decode())
                    return True, data
                else:
                    return False, None
        except Exception as e:
            return False, None
    
    def test_signal_generation(self, symbol: str = "BTCUSDT", category: str = "swing") -> Tuple[bool, Optional[Dict]]:
        """Test signal generation"""
        try:
            url = f"{self.services['fks_app']}/api/v1/signals/latest/{symbol}?category={category}&use_ai=true"
            req = urllib.request.Request(url)
            with urllib.request.urlopen(req, timeout=30) as response:
                if response.getcode() == 200:
                    data = json.loads(response.read().decode())
                    return True, data
                else:
                    return False, None
        except Exception as e:
            return False, None
    
    def test_execution_health(self) -> Tuple[bool, str]:
        """Test execution service health"""
        return self.test_service_health("fks_execution", self.services["fks_execution"])
    
    def run_all_tests(self):
        """Run all Phase 2 integration tests"""
        print("=" * 70)
        print("PHASE 2 INTEGRATION TESTING")
        print("=" * 70)
        print()
        
        # Test 1: Service Health Checks
        print("1. Testing Service Health...")
        for service_name, base_url in self.services.items():
            success, message = self.test_service_health(service_name, base_url)
            if success:
                self.results["passed"].append(f"{service_name} health check")
                print(f"   [PASS] {service_name}: {message}")
            else:
                self.results["failed"].append(f"{service_name} health check: {message}")
                print(f"   [FAIL] {service_name}: {message}")
        print()
        
        # Test 2: Data Flow
        print("2. Testing Data Flow...")
        price_success, price_data = self.test_data_price()
        if price_success and price_data:
            self.results["passed"].append("Data price endpoint")
            print(f"   [PASS] Price data: ${price_data.get('price', 0):,.2f} for {price_data.get('symbol', 'N/A')}")
            if price_data.get('cached'):
                print(f"   [INFO] Data was cached (good for performance)")
        else:
            self.results["failed"].append("Data price endpoint")
            print(f"   [FAIL] Could not fetch price data")
        
        ohlcv_success, ohlcv_data = self.test_data_ohlcv()
        if ohlcv_success and ohlcv_data:
            self.results["passed"].append("Data OHLCV endpoint")
            data_points = len(ohlcv_data.get('data', []))
            print(f"   [PASS] OHLCV data: {data_points} data points")
        else:
            self.results["failed"].append("Data OHLCV endpoint")
            print(f"   [FAIL] Could not fetch OHLCV data")
        print()
        
        # Test 3: Signal Generation
        print("3. Testing Signal Generation...")
        signal_success, signal_data = self.test_signal_generation()
        if signal_success and signal_data:
            self.results["passed"].append("Signal generation")
            signal_type = signal_data.get('signal_type', 'N/A')
            confidence = signal_data.get('confidence', 0) * 100
            category = signal_data.get('category', 'N/A')
            print(f"   [PASS] Signal generated: {signal_type} ({category})")
            print(f"          Confidence: {confidence:.1f}%")
            print(f"          Entry: ${signal_data.get('entry_price', 0):,.2f}")
            print(f"          TP: ${signal_data.get('take_profit', 0):,.2f}")
            print(f"          SL: ${signal_data.get('stop_loss', 0):,.2f}")
            if signal_data.get('ai_enhanced'):
                print(f"          AI Enhanced: Yes")
        else:
            self.results["failed"].append("Signal generation")
            print(f"   [FAIL] Could not generate signal")
        print()
        
        # Test 4: Execution Service
        print("4. Testing Execution Service...")
        exec_success, exec_message = self.test_execution_health()
        if exec_success:
            self.results["passed"].append("Execution service health")
            print(f"   [PASS] Execution service: {exec_message}")
        else:
            self.results["warnings"].append(f"Execution service: {exec_message}")
            print(f"   [WARN] Execution service: {exec_message} (may not be running)")
        print()
        
        # Generate summary
        total = len(self.results["passed"]) + len(self.results["failed"])
        passed = len(self.results["passed"])
        failed = len(self.results["failed"])
        warnings = len(self.results["warnings"])
        
        self.results["summary"] = {
            "total_tests": total,
            "passed": passed,
            "failed": failed,
            "warnings": warnings,
            "success_rate": f"{(passed/total*100):.1f}%" if total > 0 else "0%",
            "timestamp": datetime.now().isoformat()
        }
        
        # Print summary
        print("=" * 70)
        print("TEST SUMMARY")
        print("=" * 70)
        print(f"Total Tests: {total}")
        print(f"Passed: {passed}")
        print(f"Failed: {failed}")
        print(f"Warnings: {warnings}")
        print(f"Success Rate: {self.results['summary']['success_rate']}")
        print("=" * 70)
        
        if failed == 0:
            print("\n✅ All critical tests passed!")
            if warnings > 0:
                print(f"⚠️  {warnings} warning(s) - check execution service")
        else:
            print(f"\n❌ {failed} test(s) failed - review errors above")
    
    def save_report(self, output_path: Path):
        """Save test report"""
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, 'w') as f:
            json.dump(self.results, f, indent=2)
        print(f"\nReport saved to {output_path}")


def main():
    script_dir = Path(__file__).parent
    main_dir = script_dir.parent
    
    tester = Phase2Tester()
    tester.run_all_tests()
    
    # Save report
    report_path = main_dir / "docs" / "todo" / "PHASE-2-TEST-REPORT.json"
    tester.save_report(report_path)
    
    # Save markdown summary
    summary_path = main_dir / "docs" / "todo" / "PHASE-2-TEST-SUMMARY.md"
    with open(summary_path, 'w') as f:
        f.write("# Phase 2 Integration Test Summary\n\n")
        f.write(f"**Date**: {tester.results['summary']['timestamp']}\n\n")
        f.write("## Summary\n\n")
        f.write(f"- **Total Tests**: {tester.results['summary']['total_tests']}\n")
        f.write(f"- **Passed**: {tester.results['summary']['passed']}\n")
        f.write(f"- **Failed**: {tester.results['summary']['failed']}\n")
        f.write(f"- **Warnings**: {tester.results['summary']['warnings']}\n")
        f.write(f"- **Success Rate**: {tester.results['summary']['success_rate']}\n\n")
        
        if tester.results['passed']:
            f.write("## Passed Tests\n\n")
            for test in tester.results['passed']:
                f.write(f"- ✅ {test}\n")
            f.write("\n")
        
        if tester.results['failed']:
            f.write("## Failed Tests\n\n")
            for test in tester.results['failed']:
                f.write(f"- ❌ {test}\n")
            f.write("\n")
        
        if tester.results['warnings']:
            f.write("## Warnings\n\n")
            for warning in tester.results['warnings']:
                f.write(f"- ⚠️  {warning}\n")
            f.write("\n")
    
    print(f"Summary saved to {summary_path}")
    
    # Exit code
    exit(0 if tester.results['summary']['failed'] == 0 else 1)


if __name__ == "__main__":
    main()

