#!/usr/bin/env python3
"""
Test traffic generator for execution pipeline metrics.

Generates webhook requests to simulate real trading activity for testing
Prometheus metrics collection and Grafana dashboard visualization.

Usage:
    python3 scripts/generate_test_traffic.py --webhooks 100 --concurrent 10
    python3 scripts/generate_test_traffic.py --load-test --duration 60
"""

import argparse
import asyncio
import json
import hmac
import hashlib
import random
import time
from datetime import datetime
from typing import List, Dict, Any
import aiohttp
from dataclasses import dataclass


@dataclass
class TrafficConfig:
    """Configuration for traffic generation."""
    webhook_url: str = "http://localhost:8000/webhook/tradingview"
    webhook_secret: str = "test_secret"
    total_webhooks: int = 100
    concurrent_requests: int = 10
    duration_seconds: int = 0  # 0 = run total_webhooks, >0 = run for duration
    rate_limit_test: bool = False
    circuit_breaker_test: bool = False


class TestTrafficGenerator:
    """Generate test traffic for execution pipeline."""

    SYMBOLS = [
        'BTC/USDT', 'ETH/USDT', 'BNB/USDT', 'SOL/USDT', 'ADA/USDT',
        'XRP/USDT', 'DOT/USDT', 'DOGE/USDT', 'AVAX/USDT', 'MATIC/USDT'
    ]

    SOURCES = ['tradingview', 'custom_bot', 'ml_model', 'backtester']

    ORDER_TYPES = ['market', 'limit']

    SIDES = ['buy', 'sell']

    def __init__(self, config: TrafficConfig):
        self.config = config
        self.session: aiohttp.ClientSession | None = None
        self.stats = {
            'total_sent': 0,
            'successful': 0,
            'failed': 0,
            'signature_failures': 0,
            'validation_failures': 0,
            'rate_limited': 0,
            'start_time': None,
            'end_time': None
        }

    async def __aenter__(self):
        """Enter async context."""
        self.session = aiohttp.ClientSession()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Exit async context."""
        if self.session:
            await self.session.close()

    def _generate_webhook_payload(
        self,
        source: str | None = None,
        symbol: str | None = None,
        confidence: float | None = None,
        invalid: bool = False
    ) -> Dict[str, Any]:
        """Generate a random webhook payload."""
        if invalid:
            # Generate intentionally invalid payload
            return {
                'invalid_field': 'test',
                'missing_required': True
            }

        payload = {
            'symbol': symbol or random.choice(self.SYMBOLS),
            'side': random.choice(self.SIDES),
            'order_type': random.choice(self.ORDER_TYPES),
            'quantity': round(random.uniform(0.001, 1.0), 6),
            'confidence': confidence if confidence is not None else round(random.uniform(0.5, 1.0), 2),
            'timestamp': int(time.time() * 1000),
            'source': source or random.choice(self.SOURCES)
        }

        # Add price for limit orders
        if payload['order_type'] == 'limit':
            base_price = random.uniform(100, 70000)
            payload['price'] = round(base_price, 2)

        # Sometimes add TP/SL
        if random.random() > 0.7:
            payload['take_profit'] = round(payload.get('price', 100) * random.uniform(1.05, 1.15), 2)
        
        if random.random() > 0.8:
            payload['stop_loss'] = round(payload.get('price', 100) * random.uniform(0.85, 0.95), 2)

        return payload

    def _sign_payload(self, payload: Dict[str, Any]) -> str:
        """Generate HMAC signature for payload."""
        payload_json = json.dumps(payload, sort_keys=True)
        signature = hmac.new(
            self.config.webhook_secret.encode('utf-8'),
            payload_json.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()
        return signature

    async def send_webhook(
        self,
        payload: Dict[str, Any],
        signature: str | None = None,
        invalid_signature: bool = False
    ) -> Dict[str, Any]:
        """Send a single webhook request."""
        if not self.session:
            raise RuntimeError("Session not initialized. Use 'async with' context manager.")

        payload_json = json.dumps(payload, sort_keys=True)
        
        # Generate or use provided signature
        if signature is None:
            signature = self._sign_payload(payload)
        
        if invalid_signature:
            signature = "invalid_" + signature

        headers = {
            'Content-Type': 'application/json',
            'X-Signature': signature
        }

        try:
            async with self.session.post(
                self.config.webhook_url,
                data=payload_json,
                headers=headers,
                timeout=aiohttp.ClientTimeout(total=10)
            ) as response:
                result = {
                    'status': response.status,
                    'success': response.status == 200,
                    'response': await response.json() if response.status == 200 else await response.text()
                }
                return result
        except Exception as e:
            return {
                'status': 0,
                'success': False,
                'error': str(e)
            }

    async def generate_normal_traffic(self) -> None:
        """Generate normal trading traffic."""
        print(f"\n🚀 Generating {self.config.total_webhooks} webhooks with {self.config.concurrent_requests} concurrent requests...")
        
        self.stats['start_time'] = time.time()
        
        semaphore = asyncio.Semaphore(self.config.concurrent_requests)
        
        async def send_one(index: int):
            async with semaphore:
                payload = self._generate_webhook_payload()
                result = await self.send_webhook(payload)
                
                self.stats['total_sent'] += 1
                if result['success']:
                    self.stats['successful'] += 1
                else:
                    self.stats['failed'] += 1
                
                if index % 10 == 0:
                    print(f"  Progress: {index}/{self.config.total_webhooks}")
                
                return result
        
        tasks = [send_one(i) for i in range(self.config.total_webhooks)]
        await asyncio.gather(*tasks)
        
        self.stats['end_time'] = time.time()

    async def test_validation_failures(self, count: int = 20) -> None:
        """Generate traffic to test validation failure metrics."""
        print(f"\n❌ Testing validation failures ({count} requests)...")
        
        for i in range(count):
            # Invalid JSON payload
            payload = self._generate_webhook_payload(invalid=True)
            result = await self.send_webhook(payload)
            
            if not result['success']:
                self.stats['validation_failures'] += 1
            
            if i % 5 == 0:
                print(f"  Progress: {i}/{count}")

    async def test_signature_failures(self, count: int = 20) -> None:
        """Generate traffic to test signature failure metrics."""
        print(f"\n🔐 Testing signature failures ({count} requests)...")
        
        for i in range(count):
            payload = self._generate_webhook_payload()
            result = await self.send_webhook(payload, invalid_signature=True)
            
            if not result['success']:
                self.stats['signature_failures'] += 1
            
            if i % 5 == 0:
                print(f"  Progress: {i}/{count}")

    async def test_low_confidence_filtering(self, count: int = 20) -> None:
        """Generate traffic to test confidence filtering."""
        print(f"\n📊 Testing low confidence filtering ({count} requests)...")
        
        for i in range(count):
            # Generate with low confidence (<0.6)
            payload = self._generate_webhook_payload(confidence=round(random.uniform(0.1, 0.5), 2))
            result = await self.send_webhook(payload)
            
            if i % 5 == 0:
                print(f"  Progress: {i}/{count}")

    async def test_rate_limiting(self, requests_per_second: int = 150) -> None:
        """Generate traffic to test rate limiting."""
        print(f"\n⚡ Testing rate limiting ({requests_per_second} req/s for 5 seconds)...")
        
        duration = 5
        total = requests_per_second * duration
        delay = 1.0 / requests_per_second
        
        for i in range(total):
            payload = self._generate_webhook_payload()
            result = await self.send_webhook(payload)
            
            if not result['success'] and result.get('status') == 429:
                self.stats['rate_limited'] += 1
            
            await asyncio.sleep(delay)
            
            if i % 50 == 0:
                print(f"  Progress: {i}/{total}")

    async def load_test(self, duration_seconds: int = 60) -> None:
        """Run load test for specified duration."""
        print(f"\n🔥 Running load test for {duration_seconds} seconds...")
        
        self.stats['start_time'] = time.time()
        end_time = self.stats['start_time'] + duration_seconds
        
        semaphore = asyncio.Semaphore(self.config.concurrent_requests)
        
        async def continuous_sender():
            while time.time() < end_time:
                async with semaphore:
                    payload = self._generate_webhook_payload()
                    result = await self.send_webhook(payload)
                    
                    self.stats['total_sent'] += 1
                    if result['success']:
                        self.stats['successful'] += 1
                    else:
                        self.stats['failed'] += 1
                
                await asyncio.sleep(0.01)  # Small delay to prevent overwhelming
        
        # Start multiple senders
        tasks = [continuous_sender() for _ in range(10)]
        await asyncio.gather(*tasks)
        
        self.stats['end_time'] = time.time()

    def print_stats(self) -> None:
        """Print traffic generation statistics."""
        print("\n" + "="*60)
        print("📊 Traffic Generation Statistics")
        print("="*60)
        
        if self.stats['start_time'] and self.stats['end_time']:
            duration = self.stats['end_time'] - self.stats['start_time']
            rps = self.stats['total_sent'] / duration if duration > 0 else 0
            
            print(f"Duration: {duration:.2f} seconds")
            print(f"Throughput: {rps:.2f} requests/second")
        
        print(f"\nTotal Sent: {self.stats['total_sent']}")
        print(f"✅ Successful: {self.stats['successful']}")
        print(f"❌ Failed: {self.stats['failed']}")
        
        if self.stats['signature_failures']:
            print(f"🔐 Signature Failures: {self.stats['signature_failures']}")
        
        if self.stats['validation_failures']:
            print(f"❌ Validation Failures: {self.stats['validation_failures']}")
        
        if self.stats['rate_limited']:
            print(f"⚡ Rate Limited: {self.stats['rate_limited']}")
        
        success_rate = (self.stats['successful'] / self.stats['total_sent'] * 100) if self.stats['total_sent'] > 0 else 0
        print(f"\nSuccess Rate: {success_rate:.2f}%")
        print("="*60)


async def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description='Generate test traffic for execution pipeline')
    
    parser.add_argument(
        '--webhooks',
        type=int,
        default=100,
        help='Total number of webhooks to send (default: 100)'
    )
    
    parser.add_argument(
        '--concurrent',
        type=int,
        default=10,
        help='Number of concurrent requests (default: 10)'
    )
    
    parser.add_argument(
        '--url',
        type=str,
        default='http://localhost:8000/webhook/tradingview',
        help='Webhook URL (default: http://localhost:8000/webhook/tradingview)'
    )
    
    parser.add_argument(
        '--secret',
        type=str,
        default='test_secret',
        help='Webhook secret for signatures (default: test_secret)'
    )
    
    parser.add_argument(
        '--load-test',
        action='store_true',
        help='Run continuous load test'
    )
    
    parser.add_argument(
        '--duration',
        type=int,
        default=60,
        help='Load test duration in seconds (default: 60)'
    )
    
    parser.add_argument(
        '--test-failures',
        action='store_true',
        help='Include validation and signature failure tests'
    )
    
    parser.add_argument(
        '--test-rate-limit',
        action='store_true',
        help='Include rate limiting test'
    )
    
    args = parser.parse_args()
    
    config = TrafficConfig(
        webhook_url=args.url,
        webhook_secret=args.secret,
        total_webhooks=args.webhooks,
        concurrent_requests=args.concurrent,
        duration_seconds=args.duration,
        rate_limit_test=args.test_rate_limit
    )
    
    async with TestTrafficGenerator(config) as generator:
        if args.load_test:
            await generator.load_test(args.duration)
        else:
            await generator.generate_normal_traffic()
        
        if args.test_failures:
            await generator.test_validation_failures(20)
            await generator.test_signature_failures(20)
            await generator.test_low_confidence_filtering(20)
        
        if args.test_rate_limit:
            await generator.test_rate_limiting(150)
        
        generator.print_stats()
    
    print("\n✅ Traffic generation complete!")
    print("📊 Check Prometheus: http://localhost:9090")
    print("📈 Check Grafana: http://localhost:3000/d/execution-pipeline")


if __name__ == '__main__':
    asyncio.run(main())
