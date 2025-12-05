#!/usr/bin/env python3
"""
Rate Limiting Test Script

Tests rate limiting implementation on trading endpoints.
Verifies:
- Rate limit enforcement (429 responses)
- User-based rate limiting (with auth token)
- IP-based rate limiting (without auth token)
- Rate limit headers in responses

Usage:
    python test_rate_limiting.py [--base-url BASE_URL] [--token TOKEN] [--endpoint ENDPOINT]
"""

import argparse
import json
import sys
import time
from typing import Dict, List, Optional, Tuple

try:
    import requests
except ImportError:
    print("ERROR: 'requests' library not found. Install it with: pip install requests")
    sys.exit(1)


class Colors:
    """ANSI color codes for terminal output."""
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    RESET = '\033[0m'
    BOLD = '\033[1m'


class RateLimitTester:
    """Test rate limiting on API endpoints."""
    
    def __init__(self, base_url: str = "http://localhost:8001", token: Optional[str] = None):
        """
        Initialize tester.
        
        Args:
            base_url: Base URL of the API (default: http://localhost:8001)
            token: Optional JWT token for authenticated requests
        """
        self.base_url = base_url.rstrip('/')
        self.token = token
        self.session = requests.Session()
        if token:
            self.session.headers.update({
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json"
            })
        else:
            self.session.headers.update({
                "Content-Type": "application/json"
            })
    
    def print_header(self, text: str):
        """Print a formatted header."""
        print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*60}{Colors.RESET}")
        print(f"{Colors.BOLD}{Colors.CYAN}{text}{Colors.RESET}")
        print(f"{Colors.BOLD}{Colors.CYAN}{'='*60}{Colors.RESET}\n")
    
    def print_success(self, text: str):
        """Print success message."""
        print(f"{Colors.GREEN}✅ {text}{Colors.RESET}")
    
    def print_error(self, text: str):
        """Print error message."""
        print(f"{Colors.RED}❌ {text}{Colors.RESET}")
    
    def print_warning(self, text: str):
        """Print warning message."""
        print(f"{Colors.YELLOW}⚠️  {text}{Colors.RESET}")
    
    def print_info(self, text: str):
        """Print info message."""
        print(f"{Colors.BLUE}ℹ️  {text}{Colors.RESET}")
    
    def check_api_health(self) -> bool:
        """Check if API is accessible."""
        try:
            response = self.session.get(f"{self.base_url}/", timeout=5)
            if response.status_code in [200, 404]:  # 404 is ok, means API is running
                return True
        except requests.exceptions.RequestException:
            pass
        return False
    
    def test_endpoint(
        self,
        method: str,
        endpoint: str,
        data: Optional[Dict] = None,
        expected_limit: int = 10,
        test_count: int = 15
    ) -> Tuple[bool, Dict]:
        """
        Test rate limiting on an endpoint.
        
        Args:
            method: HTTP method (GET, POST, PUT, DELETE)
            endpoint: Endpoint path (e.g., /api/v1/trading/orders)
            data: Optional request body data
            expected_limit: Expected rate limit (default: 10)
            test_count: Number of requests to make (default: 15)
        
        Returns:
            Tuple of (success: bool, results: dict)
        """
        full_url = f"{self.base_url}{endpoint}"
        results = {
            "endpoint": endpoint,
            "method": method,
            "total_requests": test_count,
            "successful": 0,
            "rate_limited": 0,
            "errors": 0,
            "responses": []
        }
        
        print(f"\n{Colors.BOLD}Testing: {method} {endpoint}{Colors.RESET}")
        print(f"Expected limit: {expected_limit} requests per minute")
        print(f"Making {test_count} requests...\n")
        
        for i in range(1, test_count + 1):
            try:
                if method.upper() == "GET":
                    response = self.session.get(full_url, timeout=10)
                elif method.upper() == "POST":
                    response = self.session.post(full_url, json=data, timeout=10)
                elif method.upper() == "PUT":
                    response = self.session.put(full_url, json=data, timeout=10)
                elif method.upper() == "DELETE":
                    response = self.session.delete(full_url, timeout=10)
                else:
                    self.print_error(f"Unsupported method: {method}")
                    return False, results
                
                status = response.status_code
                headers = dict(response.headers)
                
                result_entry = {
                    "request": i,
                    "status": status,
                    "headers": {
                        "x-ratelimit-limit": headers.get("X-RateLimit-Limit", "N/A"),
                        "x-ratelimit-window": headers.get("X-RateLimit-Window", "N/A"),
                        "retry-after": headers.get("Retry-After", "N/A")
                    }
                }
                
                if status == 429:
                    results["rate_limited"] += 1
                    result_entry["result"] = "RATE_LIMITED"
                    print(f"  Request {i:2d}: {Colors.RED}429 Rate Limited{Colors.RESET} "
                          f"(Retry-After: {headers.get('Retry-After', 'N/A')})")
                elif status in [200, 201, 202]:
                    results["successful"] += 1
                    result_entry["result"] = "SUCCESS"
                    print(f"  Request {i:2d}: {Colors.GREEN}{status} OK{Colors.RESET}")
                elif status == 401:
                    results["errors"] += 1
                    result_entry["result"] = "UNAUTHORIZED"
                    print(f"  Request {i:2d}: {Colors.YELLOW}401 Unauthorized{Colors.RESET}")
                elif status == 422:
                    results["errors"] += 1
                    result_entry["result"] = "VALIDATION_ERROR"
                    print(f"  Request {i:2d}: {Colors.YELLOW}422 Validation Error{Colors.RESET}")
                else:
                    results["errors"] += 1
                    result_entry["result"] = f"ERROR_{status}"
                    print(f"  Request {i:2d}: {Colors.YELLOW}{status} Error{Colors.RESET}")
                
                results["responses"].append(result_entry)
                
                # Small delay to avoid overwhelming the server
                time.sleep(0.1)
                
            except requests.exceptions.RequestException as e:
                results["errors"] += 1
                print(f"  Request {i:2d}: {Colors.RED}Exception: {str(e)}{Colors.RESET}")
                results["responses"].append({
                    "request": i,
                    "status": "ERROR",
                    "error": str(e)
                })
        
        return True, results
    
    def analyze_results(self, results: Dict, expected_limit: int = 10) -> bool:
        """
        Analyze test results and determine if rate limiting works correctly.
        
        Args:
            results: Test results dictionary
            expected_limit: Expected rate limit
        
        Returns:
            True if rate limiting appears to work correctly
        """
        print(f"\n{Colors.BOLD}Results Summary:{Colors.RESET}")
        print(f"  Total requests: {results['total_requests']}")
        print(f"  Successful (2xx): {results['successful']}")
        print(f"  Rate limited (429): {results['rate_limited']}")
        print(f"  Errors: {results['errors']}")
        
        # Check if rate limiting is working
        if results["rate_limited"] > 0:
            self.print_success("Rate limiting is active (429 responses received)")
            
            # Check if the limit is approximately correct
            if results["successful"] <= expected_limit + 2:  # Allow some tolerance
                self.print_success(f"Rate limit appears correct (~{expected_limit} requests allowed)")
            else:
                self.print_warning(
                    f"Rate limit may be too high: {results['successful']} requests succeeded "
                    f"(expected ~{expected_limit})"
                )
            
            # Check for rate limit headers
            has_headers = False
            for resp in results["responses"]:
                if resp.get("status") == 429:
                    headers = resp.get("headers", {})
                    if headers.get("retry-after") != "N/A":
                        has_headers = True
                        break
            
            if has_headers:
                self.print_success("Rate limit headers present in 429 responses")
            else:
                self.print_warning("Rate limit headers may be missing in 429 responses")
            
            return True
        else:
            if results["errors"] > 0 and results["successful"] == 0:
                self.print_error("All requests failed - API may not be accessible or endpoint may require auth")
                return False
            else:
                self.print_warning(
                    "No rate limiting detected - all requests succeeded. "
                    "This could mean:\n"
                    "  - Rate limiting is not working\n"
                    "  - Rate limit is higher than test count\n"
                    "  - Requests are being made too slowly"
                )
                return False
    
    def run_full_test_suite(self):
        """Run a full test suite on all protected trading endpoints."""
        self.print_header("Rate Limiting Test Suite")
        
        # Check API health
        self.print_info("Checking API health...")
        if not self.check_api_health():
            self.print_error(f"API is not accessible at {self.base_url}")
            self.print_info("Make sure the API server is running:")
            self.print_info("  cd services/api && python src/main.py")
            self.print_info("  or")
            self.print_info("  uvicorn fastapi_main:app --reload --port 8001")
            return False
        
        self.print_success("API is accessible")
        
        # Test endpoints
        test_endpoints = [
            {
                "method": "POST",
                "endpoint": "/api/v1/trading/orders",
                "data": {
                    "symbol": "BTCUSDT",
                    "side": "buy",
                    "type": "market",
                    "quantity": 0.01
                },
                "expected_limit": 10,
                "description": "Create Order"
            },
            {
                "method": "POST",
                "endpoint": "/api/v1/trading/orders/bulk",
                "data": {
                    "orders": [
                        {
                            "symbol": "BTCUSDT",
                            "side": "buy",
                            "type": "market",
                            "quantity": 0.01
                        }
                    ]
                },
                "expected_limit": 5,
                "description": "Bulk Orders"
            },
            {
                "method": "PUT",
                "endpoint": "/api/v1/trading/positions/BTCUSDT",
                "data": {
                    "stop_loss": 50000.0
                },
                "expected_limit": 10,
                "description": "Update Position"
            },
            {
                "method": "POST",
                "endpoint": "/api/v1/trading/positions/BTCUSDT/close",
                "data": {},
                "expected_limit": 10,
                "description": "Close Position"
            },
        ]
        
        all_passed = True
        
        for test in test_endpoints:
            self.print_header(f"Test: {test['description']}")
            success, results = self.test_endpoint(
                method=test["method"],
                endpoint=test["endpoint"],
                data=test.get("data"),
                expected_limit=test["expected_limit"],
                test_count=15
            )
            
            if success:
                test_passed = self.analyze_results(results, test["expected_limit"])
                if not test_passed:
                    all_passed = False
            else:
                all_passed = False
                self.print_error(f"Test failed for {test['endpoint']}")
        
        # Final summary
        self.print_header("Test Suite Summary")
        if all_passed:
            self.print_success("All rate limiting tests passed!")
        else:
            self.print_warning("Some tests had issues - review the output above")
        
        return all_passed


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Test rate limiting on API endpoints",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Test with default settings (localhost:8001, no auth)
  python test_rate_limiting.py

  # Test with custom base URL
  python test_rate_limiting.py --base-url http://localhost:8000

  # Test with authentication token
  python test_rate_limiting.py --token YOUR_JWT_TOKEN

  # Test a specific endpoint
  python test_rate_limiting.py --endpoint /api/v1/trading/orders --method POST

  # Run full test suite
  python test_rate_limiting.py --full-suite
        """
    )
    
    parser.add_argument(
        "--base-url",
        default="http://localhost:8001",
        help="Base URL of the API (default: http://localhost:8001)"
    )
    
    parser.add_argument(
        "--token",
        default=None,
        help="JWT token for authenticated requests"
    )
    
    parser.add_argument(
        "--endpoint",
        default=None,
        help="Specific endpoint to test (e.g., /api/v1/trading/orders)"
    )
    
    parser.add_argument(
        "--method",
        default="POST",
        choices=["GET", "POST", "PUT", "DELETE"],
        help="HTTP method (default: POST)"
    )
    
    parser.add_argument(
        "--expected-limit",
        type=int,
        default=10,
        help="Expected rate limit (default: 10)"
    )
    
    parser.add_argument(
        "--test-count",
        type=int,
        default=15,
        help="Number of requests to make (default: 15)"
    )
    
    parser.add_argument(
        "--full-suite",
        action="store_true",
        help="Run full test suite on all protected endpoints"
    )
    
    args = parser.parse_args()
    
    # Create tester
    tester = RateLimitTester(base_url=args.base_url, token=args.token)
    
    if args.full_suite:
        # Run full test suite
        success = tester.run_full_test_suite()
        sys.exit(0 if success else 1)
    elif args.endpoint:
        # Test single endpoint
        tester.print_header(f"Testing: {args.method} {args.endpoint}")
        success, results = tester.test_endpoint(
            method=args.method,
            endpoint=args.endpoint,
            expected_limit=args.expected_limit,
            test_count=args.test_count
        )
        if success:
            test_passed = tester.analyze_results(results, args.expected_limit)
            sys.exit(0 if test_passed else 1)
        else:
            sys.exit(1)
    else:
        # Default: run full suite
        success = tester.run_full_test_suite()
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
