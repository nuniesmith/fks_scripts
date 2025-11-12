#!/usr/bin/env python3
"""
FKS Platform - Load Testing Script

Usage:
    python load_test.py --service ai --endpoint /ai/bots/consensus --concurrent 10 --requests 100
    python load_test.py --service analyze --endpoint /api/v1/rag/query --concurrent 5 --requests 50
"""
import argparse
import asyncio
import time
import statistics
from typing import List, Dict, Any
import httpx
from loguru import logger


class LoadTester:
    """Load testing utility for FKS Platform"""
    
    def __init__(self, base_url: str = "http://localhost:8001"):
        """
        Initialize load tester.
        
        Args:
            base_url: Base URL for the service
        """
        self.base_url = base_url.rstrip('/')
        self.results: List[Dict[str, Any]] = []
    
    async def make_request(
        self,
        endpoint: str,
        method: str = "GET",
        data: Dict = None,
        client: httpx.AsyncClient = None
    ) -> Dict[str, Any]:
        """
        Make a single HTTP request.
        
        Args:
            endpoint: API endpoint
            method: HTTP method
            data: Request data
            client: HTTP client
        
        Returns:
            Request result with timing and status
        """
        url = f"{self.base_url}{endpoint}"
        start_time = time.time()
        
        try:
            if method == "GET":
                response = await client.get(url, timeout=30.0)
            elif method == "POST":
                response = await client.post(url, json=data, timeout=30.0)
            else:
                raise ValueError(f"Unsupported method: {method}")
            
            elapsed = time.time() - start_time
            
            result = {
                "status_code": response.status_code,
                "elapsed_time": elapsed,
                "success": 200 <= response.status_code < 300,
                "error": None
            }
            
            return result
            
        except Exception as e:
            elapsed = time.time() - start_time
            return {
                "status_code": 0,
                "elapsed_time": elapsed,
                "success": False,
                "error": str(e)
            }
    
    async def run_load_test(
        self,
        endpoint: str,
        method: str = "GET",
        data: Dict = None,
        concurrent: int = 10,
        total_requests: int = 100
    ) -> Dict[str, Any]:
        """
        Run load test.
        
        Args:
            endpoint: API endpoint to test
            method: HTTP method
            data: Request data
            concurrent: Number of concurrent requests
            total_requests: Total number of requests
        
        Returns:
            Load test results
        """
        logger.info(f"Starting load test: {endpoint}")
        logger.info(f"Concurrent: {concurrent}, Total: {total_requests}")
        
        async with httpx.AsyncClient() as client:
            # Create semaphore for concurrency control
            semaphore = asyncio.Semaphore(concurrent)
            
            async def bounded_request():
                async with semaphore:
                    return await self.make_request(endpoint, method, data, client)
            
            # Run requests
            start_time = time.time()
            tasks = [bounded_request() for _ in range(total_requests)]
            results = await asyncio.gather(*tasks)
            total_time = time.time() - start_time
        
        # Calculate statistics
        elapsed_times = [r["elapsed_time"] for r in results]
        success_count = sum(1 for r in results if r["success"])
        error_count = total_requests - success_count
        
        stats = {
            "endpoint": endpoint,
            "method": method,
            "total_requests": total_requests,
            "concurrent": concurrent,
            "total_time": total_time,
            "requests_per_second": total_requests / total_time if total_time > 0 else 0,
            "success_count": success_count,
            "error_count": error_count,
            "success_rate": (success_count / total_requests * 100) if total_requests > 0 else 0,
            "min_time": min(elapsed_times) if elapsed_times else 0,
            "max_time": max(elapsed_times) if elapsed_times else 0,
            "mean_time": statistics.mean(elapsed_times) if elapsed_times else 0,
            "median_time": statistics.median(elapsed_times) if elapsed_times else 0,
            "p95_time": self._percentile(elapsed_times, 95) if elapsed_times else 0,
            "p99_time": self._percentile(elapsed_times, 99) if elapsed_times else 0,
            "errors": [r for r in results if not r["success"]]
        }
        
        return stats
    
    def _percentile(self, data: List[float], percentile: float) -> float:
        """Calculate percentile"""
        if not data:
            return 0.0
        sorted_data = sorted(data)
        index = int(len(sorted_data) * percentile / 100)
        return sorted_data[min(index, len(sorted_data) - 1)]
    
    def print_results(self, stats: Dict[str, Any]):
        """Print load test results"""
        print("\n" + "=" * 60)
        print("Load Test Results")
        print("=" * 60)
        print(f"Endpoint: {stats['endpoint']}")
        print(f"Method: {stats['method']}")
        print(f"Total Requests: {stats['total_requests']}")
        print(f"Concurrent: {stats['concurrent']}")
        print(f"Total Time: {stats['total_time']:.2f}s")
        print(f"Requests/Second: {stats['requests_per_second']:.2f}")
        print(f"Success Rate: {stats['success_rate']:.2f}%")
        print(f"Success: {stats['success_count']}, Errors: {stats['error_count']}")
        print("\nResponse Times:")
        print(f"  Min: {stats['min_time']*1000:.2f}ms")
        print(f"  Max: {stats['max_time']*1000:.2f}ms")
        print(f"  Mean: {stats['mean_time']*1000:.2f}ms")
        print(f"  Median: {stats['median_time']*1000:.2f}ms")
        print(f"  P95: {stats['p95_time']*1000:.2f}ms")
        print(f"  P99: {stats['p99_time']*1000:.2f}ms")
        
        if stats['errors']:
            print(f"\nErrors ({len(stats['errors'])}):")
            for error in stats['errors'][:5]:  # Show first 5 errors
                print(f"  - {error.get('error', 'Unknown error')}")
        
        print("=" * 60)


def get_test_data(service: str, endpoint: str) -> Dict:
    """Get test data for endpoint"""
    if "bots" in endpoint:
        return {
            "symbol": "BTC-USD",
            "market_data": {
                "close": 50000.0,
                "open": 49000.0,
                "high": 51000.0,
                "low": 48000.0,
                "volume": 100000000,
                "data": [
                    {
                        "open": 49000.0,
                        "high": 51000.0,
                        "low": 48000.0,
                        "close": 50000.0,
                        "volume": 100000000
                    }
                ]
            }
        }
    elif "rag" in endpoint:
        return {
            "query": "What is the FKS platform?"
        }
    return {}


def main():
    parser = argparse.ArgumentParser(description="Load test FKS Platform")
    parser.add_argument("--service", type=str, required=True, 
                       choices=["ai", "analyze", "training"],
                       help="Service to test")
    parser.add_argument("--endpoint", type=str, required=True,
                       help="Endpoint to test")
    parser.add_argument("--base-url", type=str,
                       default="http://localhost:8001",
                       help="Base URL")
    parser.add_argument("--concurrent", type=int, default=10,
                       help="Number of concurrent requests")
    parser.add_argument("--requests", type=int, default=100,
                       help="Total number of requests")
    parser.add_argument("--method", type=str, default="POST",
                       choices=["GET", "POST"],
                       help="HTTP method")
    
    args = parser.parse_args()
    
    # Set base URL based on service
    if args.service == "ai":
        base_url = args.base_url or "http://localhost:8001"
    elif args.service == "analyze":
        base_url = args.base_url or "http://localhost:8004"
    elif args.service == "training":
        base_url = args.base_url or "http://localhost:8002"
    else:
        base_url = args.base_url
    
    # Get test data
    test_data = get_test_data(args.service, args.endpoint)
    
    # Run load test
    tester = LoadTester(base_url=base_url)
    stats = asyncio.run(tester.run_load_test(
        endpoint=args.endpoint,
        method=args.method,
        data=test_data if args.method == "POST" else None,
        concurrent=args.concurrent,
        total_requests=args.requests
    ))
    
    # Print results
    tester.print_results(stats)


if __name__ == "__main__":
    main()

