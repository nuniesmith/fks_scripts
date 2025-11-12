#!/usr/bin/env python3
"""
Load testing script for CCXT execution service with security middleware.

Tests:
1. Normal webhook traffic (1000 requests)
2. Rate limiting (150 req/s to exceed 100 req/60s limit)
3. Circuit breaker (trigger with signature failures)
4. Low confidence filtering
5. Performance metrics (P95 latency, throughput)

Usage:
    python3 scripts/test_ccxt_load.py --endpoint http://localhost:8000
    python3 scripts/test_ccxt_load.py --load-test --duration 60
    python3 scripts/test_ccxt_load.py --circuit-breaker-test
"""

import argparse
import asyncio
import json
import hmac
import hashlib
import random
import time
import statistics
from datetime import datetime
from typing import List, Dict, Any
from dataclasses import dataclass, field
import sys

try:
    import aiohttp
except ImportError:
    print("Error: aiohttp not installed. Run: pip install aiohttp")
    sys.exit(1)


@dataclass
class LoadTestStats:
    """Statistics for load test results."""
    total_sent: int = 0
    successful: int = 0
    failed: int = 0
    dry_run: int = 0
    ignored: int = 0
    invalid_signature: int = 0
    rate_limited: int = 0
    circuit_open: int = 0
    latencies: List[float] = field(default_factory=list)
    start_time: float = 0
    end_time: float = 0
    
    def add_result(self, success: bool, status: int, latency: float, response_data: Dict = None):
        """Add a test result."""
        self.total_sent += 1
        self.latencies.append(latency)
        
        if success:
            self.successful += 1
            if response_data:
                if response_data.get('status') == 'dry_run':
                    self.dry_run += 1
                elif response_data.get('status') == 'ignored':
                    self.ignored += 1
        else:
            self.failed += 1
            if status == 401:
                self.invalid_signature += 1
            elif status == 429:
                self.rate_limited += 1
            elif status == 503:
                self.circuit_open += 1
    
    def print_summary(self):
        """Print test summary."""
        duration = self.end_time - self.start_time
        throughput = self.total_sent / duration if duration > 0 else 0
        
        print("\n" + "="*80)
        print("LOAD TEST RESULTS")
        print("="*80)
        print(f"\nRequests:")
        print(f"  Total:              {self.total_sent}")
        print(f"  Successful (2xx):   {self.successful} ({self.successful/self.total_sent*100:.1f}%)")
        print(f"  Failed:             {self.failed} ({self.failed/self.total_sent*100:.1f}%)")
        print(f"    - Dry Run:        {self.dry_run}")
        print(f"    - Ignored:        {self.ignored}")
        print(f"    - Invalid Sig:    {self.invalid_signature}")
        print(f"    - Rate Limited:   {self.rate_limited}")
        print(f"    - Circuit Open:   {self.circuit_open}")
        
        print(f"\nPerformance:")
        print(f"  Duration:           {duration:.2f}s")
        print(f"  Throughput:         {throughput:.2f} req/s")
        
        if self.latencies:
            p50 = statistics.median(self.latencies) * 1000
            p95 = statistics.quantiles(self.latencies, n=20)[18] * 1000 if len(self.latencies) > 20 else p50
            p99 = statistics.quantiles(self.latencies, n=100)[98] * 1000 if len(self.latencies) > 100 else p95
            min_lat = min(self.latencies) * 1000
            max_lat = max(self.latencies) * 1000
            avg_lat = statistics.mean(self.latencies) * 1000
            
            print(f"\nLatency (ms):")
            print(f"  Min:                {min_lat:.2f}ms")
            print(f"  Avg:                {avg_lat:.2f}ms")
            print(f"  P50:                {p50:.2f}ms")
            print(f"  P95:                {p95:.2f}ms {'✅' if p95 < 50 else '❌ (target <50ms)'}")
            print(f"  P99:                {p99:.2f}ms")
            print(f"  Max:                {max_lat:.2f}ms")
        
        print(f"\nTargets:")
        print(f"  P95 Latency:        {'✅ PASS' if self.latencies and p95 < 50 else '❌ FAIL'} (target <50ms)")
        print(f"  Throughput:         {'✅ PASS' if throughput > 80 else '❌ FAIL'} (target >80 req/s)")
        print("="*80 + "\n")


class CCXTLoadTester:
    """Load tester for CCXT execution service."""
    
    SYMBOLS = ['BTC/USDT', 'ETH/USDT', 'SOL/USDT', 'ADA/USDT', 'XRP/USDT']
    
    def __init__(self, endpoint: str, secret: str):
        self.endpoint = endpoint
        self.secret = secret
        self.session: aiohttp.ClientSession | None = None
        self.stats = LoadTestStats()
    
    async def __aenter__(self):
        """Enter async context."""
        self.session = aiohttp.ClientSession()
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Exit async context."""
        if self.session:
            await self.session.close()
    
    def generate_payload(self, confidence: float = None, price: float = None) -> Dict[str, Any]:
        """Generate webhook payload matching TradingViewWebhook schema."""
        symbol = random.choice(self.SYMBOLS)
        action = random.choice(['buy', 'sell'])
        base_price = price or random.uniform(1000, 70000)
        
        payload = {
            'symbol': symbol,
            'action': action,
            'confidence': confidence if confidence is not None else round(random.uniform(0.6, 1.0), 2),
            'price': round(base_price, 2),
            'timestamp': int(time.time())
        }
        
        # Add TP/SL 70% of the time
        if random.random() > 0.3:
            if action == 'buy':
                payload['stop_loss'] = round(base_price * random.uniform(0.92, 0.97), 2)
                payload['take_profit'] = round(base_price * random.uniform(1.03, 1.10), 2)
            else:
                payload['stop_loss'] = round(base_price * random.uniform(1.03, 1.08), 2)
                payload['take_profit'] = round(base_price * random.uniform(0.90, 0.97), 2)
        
        return payload
    
    def sign_payload(self, payload: Dict[str, Any]) -> str:
        """Generate HMAC-SHA256 signature."""
        payload_json = json.dumps(payload)
        return hmac.new(
            self.secret.encode(),
            payload_json.encode(),
            hashlib.sha256
        ).hexdigest()
    
    async def send_webhook(
        self,
        payload: Dict[str, Any],
        invalid_signature: bool = False
    ) -> tuple[bool, int, float, Dict]:
        """Send webhook and return (success, status_code, latency, response)."""
        payload_json = json.dumps(payload)
        signature = self.sign_payload(payload)
        
        if invalid_signature:
            signature = "invalid_" + signature
        
        headers = {
            'Content-Type': 'application/json',
            'X-Webhook-Signature': signature
        }
        
        start = time.time()
        try:
            async with self.session.post(
                f"{self.endpoint}/webhook/tradingview",
                data=payload_json,
                headers=headers,
                timeout=aiohttp.ClientTimeout(total=10)
            ) as resp:
                latency = time.time() - start
                try:
                    data = await resp.json()
                except:
                    data = {}
                return (resp.status == 200, resp.status, latency, data)
        except Exception as e:
            latency = time.time() - start
            return (False, 0, latency, {'error': str(e)})
    
    async def test_normal_load(self, total: int = 1000, concurrent: int = 20):
        """Test normal webhook load."""
        print(f"\n{'='*80}")
        print(f"TEST 1: Normal Load - {total} requests, {concurrent} concurrent")
        print(f"{'='*80}\n")
        
        self.stats = LoadTestStats()
        self.stats.start_time = time.time()
        
        semaphore = asyncio.Semaphore(concurrent)
        
        async def send_one(i: int):
            async with semaphore:
                payload = self.generate_payload()
                success, status, latency, data = await self.send_webhook(payload)
                self.stats.add_result(success, status, latency, data)
                
                if (i + 1) % 100 == 0:
                    print(f"  Progress: {i + 1}/{total} requests sent")
        
        tasks = [send_one(i) for i in range(total)]
        await asyncio.gather(*tasks)
        
        self.stats.end_time = time.time()
        self.stats.print_summary()
    
    async def test_rate_limiting(self, rate: int = 150, duration: int = 5):
        """Test rate limiter by exceeding limit."""
        print(f"\n{'='*80}")
        print(f"TEST 2: Rate Limiting - {rate} req/s for {duration}s")
        print(f"{'='*80}\n")
        print(f"Expected: {rate} req/s should trigger rate limiting (limit is 100 req/60s)\n")
        
        self.stats = LoadTestStats()
        self.stats.start_time = time.time()
        
        total = rate * duration
        delay = 1.0 / rate
        
        for i in range(total):
            payload = self.generate_payload()
            success, status, latency, data = await self.send_webhook(payload)
            self.stats.add_result(success, status, latency, data)
            
            if (i + 1) % rate == 0:
                print(f"  Second {(i + 1) // rate}: {self.stats.rate_limited} rate limited so far")
            
            await asyncio.sleep(delay)
        
        self.stats.end_time = time.time()
        self.stats.print_summary()
    
    async def test_circuit_breaker(self, failures: int = 10):
        """Test circuit breaker by triggering failures."""
        print(f"\n{'='*80}")
        print(f"TEST 3: Circuit Breaker - {failures} signature failures")
        print(f"{'='*80}\n")
        print(f"Expected: Circuit breaker should open after 5 failures\n")
        
        self.stats = LoadTestStats()
        self.stats.start_time = time.time()
        
        for i in range(failures):
            payload = self.generate_payload()
            success, status, latency, data = await self.send_webhook(payload, invalid_signature=True)
            self.stats.add_result(success, status, latency, data)
            
            print(f"  Attempt {i + 1}: Status {status} - {'Invalid Signature' if status == 401 else 'Circuit Open' if status == 503 else 'Other'}")
            
            await asyncio.sleep(0.5)
        
        self.stats.end_time = time.time()
        self.stats.print_summary()
        
        # Test recovery
        print("\nWaiting 60s for circuit breaker timeout...")
        await asyncio.sleep(60)
        
        print("\nTesting circuit breaker recovery:")
        payload = self.generate_payload()
        success, status, latency, data = await self.send_webhook(payload)
        print(f"  Recovery test: Status {status} - {'✅ Recovered' if status == 200 else '❌ Still broken'}")
    
    async def test_low_confidence(self, count: int = 50):
        """Test low confidence filtering."""
        print(f"\n{'='*80}")
        print(f"TEST 4: Low Confidence Filtering - {count} requests")
        print(f"{'='*80}\n")
        print(f"Expected: Requests with confidence <0.6 should be ignored\n")
        
        self.stats = LoadTestStats()
        self.stats.start_time = time.time()
        
        for i in range(count):
            # Generate with confidence 0.3-0.5 (below threshold)
            payload = self.generate_payload(confidence=round(random.uniform(0.3, 0.5), 2))
            success, status, latency, data = await self.send_webhook(payload)
            self.stats.add_result(success, status, latency, data)
            
            if (i + 1) % 10 == 0:
                print(f"  Progress: {i + 1}/{count} - {self.stats.ignored} ignored")
        
        self.stats.end_time = time.time()
        self.stats.print_summary()
    
    async def run_all_tests(self):
        """Run complete test suite."""
        print("\n" + "="*80)
        print("CCXT EXECUTION SERVICE - COMPREHENSIVE LOAD TEST")
        print("="*80)
        
        await self.test_normal_load(total=1000, concurrent=20)
        await asyncio.sleep(2)
        
        await self.test_low_confidence(count=50)
        await asyncio.sleep(2)
        
        await self.test_rate_limiting(rate=150, duration=3)
        await asyncio.sleep(5)
        
        await self.test_circuit_breaker(failures=10)


async def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description='Load test CCXT execution service')
    parser.add_argument('--endpoint', default='http://localhost:8000', help='API endpoint')
    parser.add_argument('--secret', default='fks-tradingview-webhook-secret-dev-2025', help='Webhook secret')
    parser.add_argument('--all', action='store_true', help='Run all tests')
    parser.add_argument('--normal-load', action='store_true', help='Run normal load test')
    parser.add_argument('--rate-limit', action='store_true', help='Run rate limiting test')
    parser.add_argument('--circuit-breaker', action='store_true', help='Run circuit breaker test')
    parser.add_argument('--low-confidence', action='store_true', help='Run low confidence test')
    parser.add_argument('--requests', type=int, default=1000, help='Total requests for normal load')
    parser.add_argument('--concurrent', type=int, default=20, help='Concurrent requests')
    
    args = parser.parse_args()
    
    async with CCXTLoadTester(args.endpoint, args.secret) as tester:
        if args.all or not any([args.normal_load, args.rate_limit, args.circuit_breaker, args.low_confidence]):
            await tester.run_all_tests()
        else:
            if args.normal_load:
                await tester.test_normal_load(total=args.requests, concurrent=args.concurrent)
            if args.low_confidence:
                await tester.test_low_confidence()
            if args.rate_limit:
                await tester.test_rate_limiting()
            if args.circuit_breaker:
                await tester.test_circuit_breaker()


if __name__ == '__main__':
    asyncio.run(main())
