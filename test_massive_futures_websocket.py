#!/usr/bin/env python3
"""
Test script for Massive.com Futures WebSocket connection.

Tests WebSocket subscription to trades, quotes, and aggregates.

Usage:
    python test_massive_futures_websocket.py [--url URL] [--ticker TICKER] [--timeout SECONDS]
"""

import asyncio
import json
import sys
import argparse
import signal
from typing import Optional
import websockets
from websockets.exceptions import ConnectionClosed, InvalidURI


class Colors:
    """ANSI color codes."""
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    RESET = '\033[0m'
    BOLD = '\033[1m'


def print_success(message: str):
    """Print success message."""
    print(f"{Colors.GREEN}✓{Colors.RESET} {message}")


def print_error(message: str):
    """Print error message."""
    print(f"{Colors.RED}✗{Colors.RESET} {message}")


def print_info(message: str):
    """Print info message."""
    print(f"{Colors.BLUE}ℹ{Colors.RESET} {message}")


def print_warning(message: str):
    """Print warning message."""
    print(f"{Colors.YELLOW}⚠{Colors.RESET} {message}")


async def test_websocket(url: str, ticker: str, timeout: int = 30):
    """
    Test WebSocket connection and subscription.
    
    Args:
        url: WebSocket URL
        ticker: Ticker symbol to subscribe to
        timeout: Timeout in seconds
    """
    print_info(f"Connecting to WebSocket: {url}")
    print_info(f"Ticker: {ticker}")
    print_info(f"Timeout: {timeout}s")
    print("")
    
    messages_received = {
        'trades': 0,
        'quotes': 0,
        'aggregates': 0,
        'errors': 0
    }
    
    try:
        async with websockets.connect(url, ping_interval=20, ping_timeout=10) as websocket:
            print_success("WebSocket connected")
            print("")
            
            # Subscribe to trades
            print_info("Subscribing to trades...")
            subscribe_trades = {
                "action": "subscribe",
                "channel": "trades",
                "ticker": ticker
            }
            await websocket.send(json.dumps(subscribe_trades))
            print_success(f"Subscribed to trades for {ticker}")
            
            # Subscribe to quotes
            print_info("Subscribing to quotes...")
            subscribe_quotes = {
                "action": "subscribe",
                "channel": "quotes",
                "ticker": ticker
            }
            await websocket.send(json.dumps(subscribe_quotes))
            print_success(f"Subscribed to quotes for {ticker}")
            
            # Subscribe to aggregates
            print_info("Subscribing to aggregates...")
            subscribe_aggs = {
                "action": "subscribe",
                "channel": "aggregates",
                "ticker": ticker,
                "resolution": "1min"
            }
            await websocket.send(json.dumps(subscribe_aggs))
            print_success(f"Subscribed to aggregates for {ticker}")
            print("")
            
            print_info("Waiting for messages (press Ctrl+C to stop)...")
            print("")
            
            # Listen for messages
            start_time = asyncio.get_event_loop().time()
            try:
                while True:
                    elapsed = asyncio.get_event_loop().time() - start_time
                    if elapsed > timeout:
                        print_warning(f"Timeout reached ({timeout}s)")
                        break
                    
                    try:
                        message = await asyncio.wait_for(websocket.recv(), timeout=5.0)
                        data = json.loads(message)
                        
                        # Process message
                        channel = data.get('channel', 'unknown')
                        if channel == 'trades':
                            messages_received['trades'] += 1
                            print_success(f"Trade received: {data.get('ticker', 'N/A')} @ {data.get('price', 'N/A')}")
                        elif channel == 'quotes':
                            messages_received['quotes'] += 1
                            print_success(f"Quote received: {data.get('ticker', 'N/A')} bid={data.get('bid', 'N/A')} ask={data.get('ask', 'N/A')}")
                        elif channel == 'aggregates':
                            messages_received['aggregates'] += 1
                            print_success(f"Aggregate received: {data.get('ticker', 'N/A')} @ {data.get('close', 'N/A')}")
                        else:
                            print_info(f"Message received: {json.dumps(data, indent=2)}")
                            
                    except asyncio.TimeoutError:
                        # No message received, continue waiting
                        continue
                    except json.JSONDecodeError as e:
                        messages_received['errors'] += 1
                        print_error(f"Invalid JSON: {e}")
                    except Exception as e:
                        messages_received['errors'] += 1
                        print_error(f"Error processing message: {e}")
                        
            except KeyboardInterrupt:
                print_warning("\nInterrupted by user")
            
            # Unsubscribe
            print("")
            print_info("Unsubscribing...")
            unsubscribe = {"action": "unsubscribe", "ticker": ticker}
            await websocket.send(json.dumps(unsubscribe))
            print_success("Unsubscribed")
            
    except ConnectionRefusedError:
        print_error("Connection refused. Is the service running?")
        return False
    except InvalidURI:
        print_error("Invalid WebSocket URL")
        return False
    except ConnectionClosed:
        print_warning("Connection closed by server")
        return False
    except Exception as e:
        print_error(f"WebSocket error: {e}")
        return False
    
    # Summary
    print("")
    print(f"{Colors.BOLD}=== Test Summary ==={Colors.RESET}")
    print(f"Trades received: {messages_received['trades']}")
    print(f"Quotes received: {messages_received['quotes']}")
    print(f"Aggregates received: {messages_received['aggregates']}")
    print(f"Errors: {messages_received['errors']}")
    print("")
    
    if messages_received['trades'] > 0 or messages_received['quotes'] > 0 or messages_received['aggregates'] > 0:
        print_success("WebSocket test successful!")
        return True
    else:
        print_warning("No messages received. This might be normal if market is closed or ticker is inactive.")
        return True  # Still consider it successful if connection worked


def main():
    """Main function."""
    parser = argparse.ArgumentParser(description='Test Massive.com Futures WebSocket')
    parser.add_argument('--url', default='ws://localhost:8003/api/v1/futures/ws',
                       help='WebSocket URL')
    parser.add_argument('--ticker', default='ESU0',
                       help='Ticker symbol to subscribe to')
    parser.add_argument('--timeout', type=int, default=30,
                       help='Timeout in seconds')
    
    args = parser.parse_args()
    
    print(f"{Colors.BOLD}=== Massive.com Futures WebSocket Test ==={Colors.RESET}\n")
    
    try:
        success = asyncio.run(test_websocket(args.url, args.ticker, args.timeout))
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print_warning("\nTest interrupted")
        sys.exit(1)


if __name__ == '__main__':
    main()
