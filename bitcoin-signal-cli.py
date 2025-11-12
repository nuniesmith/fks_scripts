#!/usr/bin/env python3
"""
Bitcoin Signal CLI Tool
Generate, display, and manage Bitcoin trading signals for daily manual trading.
"""

import sys
import json
import requests
import argparse
from datetime import datetime
from typing import Dict, Any, Optional

# Configuration
APP_SERVICE_URL = "http://localhost:8002"
EXECUTION_SERVICE_URL = "http://localhost:8004"

# ANSI color codes for terminal output
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'


def print_header(text: str):
    """Print a formatted header"""
    print(f"\n{Colors.HEADER}{Colors.BOLD}{'='*60}{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}{text.center(60)}{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}{'='*60}{Colors.ENDC}\n")


def print_signal(signal: Dict[str, Any], detailed: bool = False):
    """Print a formatted signal"""
    symbol = signal.get("symbol", "N/A")
    signal_type = signal.get("signal_type", "N/A")
    category = signal.get("category", "N/A")
    entry_price = signal.get("entry_price", 0)
    take_profit = signal.get("take_profit", 0)
    stop_loss = signal.get("stop_loss", 0)
    confidence = signal.get("confidence", 0)
    rationale = signal.get("rationale", "N/A")
    timestamp = signal.get("timestamp", "")
    
    # Color code signal type
    if signal_type == "BUY":
        signal_color = Colors.OKGREEN
    elif signal_type == "SELL":
        signal_color = Colors.FAIL
    else:
        signal_color = Colors.WARNING
    
    # Print basic signal info
    print(f"{Colors.BOLD}Symbol:{Colors.ENDC} {symbol}")
    print(f"{Colors.BOLD}Signal:{Colors.ENDC} {signal_color}{signal_type}{Colors.ENDC}")
    print(f"{Colors.BOLD}Category:{Colors.ENDC} {category}")
    print(f"{Colors.BOLD}Entry Price:{Colors.ENDC} ${entry_price:,.2f}")
    print(f"{Colors.BOLD}Take Profit:{Colors.ENDC} ${take_profit:,.2f} ({((take_profit/entry_price - 1) * 100):.2f}%)")
    print(f"{Colors.BOLD}Stop Loss:{Colors.ENDC} ${stop_loss:,.2f} ({((stop_loss/entry_price - 1) * 100):.2f}%)")
    print(f"{Colors.BOLD}Confidence:{Colors.ENDC} {confidence*100:.2f}%")
    print(f"{Colors.BOLD}Rationale:{Colors.ENDC} {rationale}")
    print(f"{Colors.BOLD}Timestamp:{Colors.ENDC} {timestamp}")
    
    if detailed:
        # Print detailed info
        position_size_pct = signal.get("position_size_pct", 0)
        position_size_usd = signal.get("position_size_usd", 0)
        position_size_units = signal.get("position_size_units", 0)
        risk_amount = signal.get("risk_amount", 0)
        risk_pct = signal.get("risk_pct", 0)
        risk_reward = signal.get("risk_reward", 0)
        indicators = signal.get("indicators", {})
        ai_enhanced = signal.get("ai_enhanced", False)
        
        print(f"\n{Colors.BOLD}Position Sizing:{Colors.ENDC}")
        print(f"  Position Size: {position_size_pct:.2f}% of portfolio")
        print(f"  Position Size: ${position_size_usd:,.2f} USD")
        print(f"  Position Size: {position_size_units:.6f} units")
        print(f"  Risk Amount: ${risk_amount:,.2f} ({risk_pct:.2f}% risk)")
        print(f"  Risk/Reward: {risk_reward:.2f}")
        
        if indicators:
            print(f"\n{Colors.BOLD}Indicators:{Colors.ENDC}")
            for key, value in indicators.items():
                print(f"  {key.upper()}: {value:.2f}")
        
        if ai_enhanced:
            print(f"\n{Colors.OKCYAN}AI Enhanced: Yes{Colors.ENDC}")
        else:
            print(f"\n{Colors.WARNING}AI Enhanced: No{Colors.ENDC}")


def generate_signal(symbol: str, category: str = "swing", use_ai: bool = False, strategy: Optional[str] = None) -> Optional[Dict[str, Any]]:
    """Generate a signal for a symbol"""
    try:
        params = {
            "category": category,
            "use_ai": str(use_ai).lower()
        }
        if strategy:
            params["strategy"] = strategy
        
        response = requests.get(
            f"{APP_SERVICE_URL}/api/v1/signals/latest/{symbol}",
            params=params,
            timeout=30
        )
        
        if response.status_code == 200:
            return response.json()
        else:
            print(f"{Colors.FAIL}Error: {response.status_code} - {response.text}{Colors.ENDC}")
            return None
            
    except requests.exceptions.RequestException as e:
        print(f"{Colors.FAIL}Error: Failed to connect to signal service: {e}{Colors.ENDC}")
        return None


def approve_signal(signal: Dict[str, Any], save_to_file: bool = True) -> bool:
    """Approve a signal (save to file or send to execution service)"""
    try:
        signal_id = f"{signal.get('symbol')}_{signal.get('category')}_{int(datetime.now().timestamp())}"
        
        # Create order data
        order_data = {
            "symbol": signal.get("symbol"),
            "side": signal.get("signal_type"),
            "order_type": "MARKET",
            "quantity": signal.get("position_size_units", 0),
            "price": signal.get("entry_price", 0),
            "stop_loss": signal.get("stop_loss"),
            "take_profit": signal.get("take_profit"),
            "signal_id": signal_id,
            "category": signal.get("category"),
            "confidence": signal.get("confidence", 0),
            "strategy": signal.get("strategy", "fks_app_pipeline"),
            "timestamp": datetime.now().isoformat(),
            "status": "approved"
        }
        
        if save_to_file:
            # Save to file for manual execution
            filename = f"approved_signals_{datetime.now().strftime('%Y%m%d')}.json"
            try:
                # Load existing signals
                try:
                    with open(filename, 'r') as f:
                        signals = json.load(f)
                except FileNotFoundError:
                    signals = []
                
                # Add new signal
                signals.append(order_data)
                
                # Save to file
                with open(filename, 'w') as f:
                    json.dump(signals, f, indent=2)
                
                print(f"{Colors.OKGREEN}Signal approved and saved to {filename}{Colors.ENDC}")
                return True
                
            except Exception as e:
                print(f"{Colors.FAIL}Error saving signal: {e}{Colors.ENDC}")
                return False
        else:
            # Send to execution service (if available)
            try:
                response = requests.post(
                    f"{EXECUTION_SERVICE_URL}/orders",
                    json=order_data,
                    timeout=30
                )
                
                if response.status_code == 200:
                    result = response.json()
                    print(f"{Colors.OKGREEN}Signal approved and sent to execution service{Colors.ENDC}")
                    print(f"Order ID: {result.get('order_id', 'N/A')}")
                    return True
                else:
                    print(f"{Colors.FAIL}Error: Execution service returned {response.status_code}{Colors.ENDC}")
                    print(f"Response: {response.text}")
                    return False
                    
            except requests.exceptions.RequestException as e:
                print(f"{Colors.WARNING}Execution service not available: {e}{Colors.ENDC}")
                print(f"{Colors.WARNING}Falling back to file save...{Colors.ENDC}")
                return approve_signal(signal, save_to_file=True)
                
    except Exception as e:
        print(f"{Colors.FAIL}Error approving signal: {e}{Colors.ENDC}")
        return False


def reject_signal(signal: Dict[str, Any], reason: Optional[str] = None) -> bool:
    """Reject a signal (log rejection)"""
    try:
        signal_id = f"{signal.get('symbol')}_{signal.get('category')}_{int(datetime.now().timestamp())}"
        
        rejection_data = {
            "signal_id": signal_id,
            "symbol": signal.get("symbol"),
            "category": signal.get("category"),
            "signal_type": signal.get("signal_type"),
            "entry_price": signal.get("entry_price"),
            "confidence": signal.get("confidence", 0),
            "reason": reason or "Manual rejection",
            "timestamp": datetime.now().isoformat(),
            "status": "rejected"
        }
        
        # Save to file
        filename = f"rejected_signals_{datetime.now().strftime('%Y%m%d')}.json"
        try:
            # Load existing rejections
            try:
                with open(filename, 'r') as f:
                    rejections = json.load(f)
            except FileNotFoundError:
                rejections = []
            
            # Add new rejection
            rejections.append(rejection_data)
            
            # Save to file
            with open(filename, 'w') as f:
                json.dump(rejections, f, indent=2)
            
            print(f"{Colors.WARNING}Signal rejected and logged to {filename}{Colors.ENDC}")
            if reason:
                print(f"Reason: {reason}")
            return True
            
        except Exception as e:
            print(f"{Colors.FAIL}Error saving rejection: {e}{Colors.ENDC}")
            return False
            
    except Exception as e:
        print(f"{Colors.FAIL}Error rejecting signal: {e}{Colors.ENDC}")
        return False


def interactive_mode(symbol: str = "BTCUSDT", category: str = "swing", use_ai: bool = False):
    """Interactive mode for signal generation and approval"""
    print_header(f"Bitcoin Signal CLI - Interactive Mode")
    
    while True:
        try:
            # Generate signal
            print(f"{Colors.OKCYAN}Generating signal for {symbol}...{Colors.ENDC}\n")
            signal = generate_signal(symbol, category, use_ai)
            
            if not signal:
                print(f"{Colors.FAIL}Failed to generate signal{Colors.ENDC}")
                break
            
            # Display signal
            print_signal(signal, detailed=True)
            
            # Ask for action
            print(f"\n{Colors.BOLD}Actions:{Colors.ENDC}")
            print(f"  [a] Approve signal")
            print(f"  [r] Reject signal")
            print(f"  [n] Generate new signal")
            print(f"  [q] Quit")
            
            action = input(f"\n{Colors.BOLD}Enter action: {Colors.ENDC}").strip().lower()
            
            if action == 'a':
                if approve_signal(signal):
                    print(f"{Colors.OKGREEN}Signal approved!{Colors.ENDC}")
                break
            elif action == 'r':
                reason = input(f"{Colors.BOLD}Enter rejection reason (optional): {Colors.ENDC}").strip()
                if reject_signal(signal, reason if reason else None):
                    print(f"{Colors.WARNING}Signal rejected!{Colors.ENDC}")
                break
            elif action == 'n':
                continue
            elif action == 'q':
                print(f"{Colors.OKCYAN}Exiting...{Colors.ENDC}")
                break
            else:
                print(f"{Colors.WARNING}Invalid action. Please try again.{Colors.ENDC}")
                
        except KeyboardInterrupt:
            print(f"\n{Colors.OKCYAN}Exiting...{Colors.ENDC}")
            break
        except Exception as e:
            print(f"{Colors.FAIL}Error: {e}{Colors.ENDC}")
            break


def main():
    parser = argparse.ArgumentParser(description="Bitcoin Signal CLI Tool")
    parser.add_argument("symbol", nargs="?", default="BTCUSDT", help="Trading symbol (default: BTCUSDT)")
    parser.add_argument("--category", choices=["scalp", "swing", "long_term"], default="swing", help="Trade category")
    parser.add_argument("--strategy", help="Strategy (rsi, macd, ema_scalp, ema_swing, asmbtr)")
    parser.add_argument("--use-ai", action="store_true", help="Use AI enhancement")
    parser.add_argument("--detailed", action="store_true", help="Show detailed signal information")
    parser.add_argument("--approve", action="store_true", help="Approve signal automatically")
    parser.add_argument("--reject", action="store_true", help="Reject signal automatically")
    parser.add_argument("--interactive", "-i", action="store_true", help="Interactive mode")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    
    args = parser.parse_args()
    
    # Interactive mode
    if args.interactive:
        interactive_mode(args.symbol, args.category, args.use_ai)
        return
    
    # Generate signal
    signal = generate_signal(args.symbol, args.category, args.use_ai, args.strategy)
    
    if not signal:
        sys.exit(1)
    
    # Output signal
    if args.json:
        print(json.dumps(signal, indent=2))
    else:
        print_header(f"Bitcoin Signal - {args.symbol}")
        print_signal(signal, detailed=args.detailed)
    
    # Auto-approve or reject
    if args.approve:
        if approve_signal(signal):
            sys.exit(0)
        else:
            sys.exit(1)
    elif args.reject:
        if reject_signal(signal):
            sys.exit(0)
        else:
            sys.exit(1)


if __name__ == "__main__":
    main()

