#!/usr/bin/env python3
"""
Daily Signal Generation Script
Automatically generate Bitcoin signals for daily manual trading workflow.
"""

import sys
import json
import requests
import argparse
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, List, Optional

# Configuration
APP_SERVICE_URL = "http://localhost:8002"
DEFAULT_SYMBOL = "BTCUSDT"
DEFAULT_CATEGORIES = ["scalp", "swing", "long_term"]
DEFAULT_STRATEGIES = {
    "scalp": "ema_scalp",
    "swing": "rsi",
    "long_term": "macd"
}

# Output directory
OUTPUT_DIR = Path("signals")
OUTPUT_DIR.mkdir(exist_ok=True)


def generate_signal(
    symbol: str,
    category: str = "swing",
    strategy: Optional[str] = None,
    use_ai: bool = False
) -> Optional[Dict[str, Any]]:
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
            print(f"Error: {response.status_code} - {response.text}")
            return None
            
    except requests.exceptions.RequestException as e:
        print(f"Error: Failed to connect to signal service: {e}")
        return None


def format_signal_summary(signal: Dict[str, Any]) -> str:
    """Format signal as a readable summary"""
    symbol = signal.get("symbol", "N/A")
    signal_type = signal.get("signal_type", "N/A")
    entry_price = signal.get("entry_price", 0)
    take_profit = signal.get("take_profit", 0)
    stop_loss = signal.get("stop_loss", 0)
    confidence = signal.get("confidence", 0)
    rationale = signal.get("rationale", "N/A")
    category = signal.get("category", "N/A")
    strategy = signal.get("strategy", "auto")
    
    tp_pct = ((take_profit / entry_price - 1) * 100) if entry_price > 0 else 0
    sl_pct = ((stop_loss / entry_price - 1) * 100) if entry_price > 0 else 0
    
    summary = f"""
Signal: {signal_type}
Symbol: {symbol}
Category: {category}
Strategy: {strategy}
Entry: ${entry_price:,.2f}
Take Profit: ${take_profit:,.2f} ({tp_pct:+.2f}%)
Stop Loss: ${stop_loss:,.2f} ({sl_pct:+.2f}%)
Confidence: {confidence*100:.1f}%
Rationale: {rationale}
"""
    return summary


def save_signal(signal: Dict[str, Any], filename: str):
    """Save signal to JSON file"""
    filepath = OUTPUT_DIR / filename
    try:
        # Load existing signals
        if filepath.exists():
            with open(filepath, 'r') as f:
                signals = json.load(f)
        else:
            signals = []
        
        # Add timestamp
        signal["generated_at"] = datetime.now().isoformat()
        
        # Add new signal
        signals.append(signal)
        
        # Save to file
        with open(filepath, 'w') as f:
            json.dump(signals, f, indent=2)
        
        print(f"Signal saved to {filepath}")
        
    except Exception as e:
        print(f"Error saving signal: {e}")


def generate_daily_signals(
    symbol: str = DEFAULT_SYMBOL,
    categories: Optional[List[str]] = None,
    strategies: Optional[Dict[str, str]] = None,
    use_ai: bool = False,
    save_to_file: bool = True
) -> List[Dict[str, Any]]:
    """Generate signals for all categories"""
    if categories is None:
        categories = DEFAULT_CATEGORIES
    
    if strategies is None:
        strategies = DEFAULT_STRATEGIES
    
    signals = []
    timestamp = datetime.now().strftime("%Y%m%d")
    
    print(f"\n{'='*60}")
    print(f"Daily Signal Generation - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"{'='*60}\n")
    
    for category in categories:
        strategy = strategies.get(category)
        print(f"Generating {category} signal...")
        print(f"Strategy: {strategy or 'auto'}")
        
        signal = generate_signal(symbol, category, strategy, use_ai)
        
        if signal:
            # Add category and strategy info
            signal["category"] = category
            signal["strategy"] = strategy or "auto"
            
            # Print summary
            print(format_signal_summary(signal))
            
            # Save to file
            if save_to_file:
                filename = f"signals_{category}_{timestamp}.json"
                save_signal(signal, filename)
            
            signals.append(signal)
        else:
            print(f"Failed to generate {category} signal\n")
    
    # Generate summary file
    if save_to_file and signals:
        summary_file = OUTPUT_DIR / f"daily_signals_summary_{timestamp}.json"
        summary = {
            "date": datetime.now().strftime("%Y-%m-%d"),
            "timestamp": datetime.now().isoformat(),
            "symbol": symbol,
            "signals": signals,
            "total": len(signals),
            "by_category": {
                category: [s for s in signals if s.get("category") == category]
                for category in categories
            }
        }
        
        with open(summary_file, 'w') as f:
            json.dump(summary, f, indent=2)
        
        print(f"\nSummary saved to {summary_file}")
    
    return signals


def print_daily_summary(signals: List[Dict[str, Any]]):
    """Print daily summary of signals"""
    if not signals:
        print("No signals generated")
        return
    
    print(f"\n{'='*60}")
    print("Daily Signal Summary")
    print(f"{'='*60}\n")
    
    # Count by signal type
    buy_count = sum(1 for s in signals if s.get("signal_type") == "BUY")
    sell_count = sum(1 for s in signals if s.get("signal_type") == "SELL")
    hold_count = sum(1 for s in signals if s.get("signal_type") == "HOLD")
    
    # Average confidence
    avg_confidence = sum(s.get("confidence", 0) for s in signals) / len(signals) * 100
    
    # Count by category
    by_category = {}
    for signal in signals:
        category = signal.get("category", "unknown")
        if category not in by_category:
            by_category[category] = {"buy": 0, "sell": 0, "hold": 0}
        signal_type = signal.get("signal_type", "HOLD")
        by_category[category][signal_type.lower()] = by_category[category].get(signal_type.lower(), 0) + 1
    
    print(f"Total Signals: {len(signals)}")
    print(f"Buy Signals: {buy_count}")
    print(f"Sell Signals: {sell_count}")
    print(f"Hold Signals: {hold_count}")
    print(f"Average Confidence: {avg_confidence:.1f}%")
    print(f"\nBy Category:")
    for category, counts in by_category.items():
        print(f"  {category}:")
        print(f"    Buy: {counts.get('buy', 0)}")
        print(f"    Sell: {counts.get('sell', 0)}")
        print(f"    Hold: {counts.get('hold', 0)}")
    
    print(f"\n{'='*60}\n")


def main():
    parser = argparse.ArgumentParser(description="Daily Signal Generation Script")
    parser.add_argument("symbol", nargs="?", default=DEFAULT_SYMBOL, help="Trading symbol (default: BTCUSDT)")
    parser.add_argument("--categories", nargs="+", choices=["scalp", "swing", "long_term"], 
                       default=DEFAULT_CATEGORIES, help="Trade categories to generate")
    parser.add_argument("--strategies", nargs="+", help="Strategies for each category (format: category:strategy)")
    parser.add_argument("--use-ai", action="store_true", help="Use AI enhancement")
    parser.add_argument("--no-save", action="store_true", help="Don't save signals to files")
    parser.add_argument("--output-dir", default="signals", help="Output directory for signals")
    parser.add_argument("--summary-only", action="store_true", help="Only print summary, don't save files")
    
    args = parser.parse_args()
    
    # Parse strategies
    strategies = DEFAULT_STRATEGIES.copy()
    if args.strategies:
        for strategy_arg in args.strategies:
            if ":" in strategy_arg:
                category, strategy = strategy_arg.split(":", 1)
                strategies[category] = strategy
    
    # Set output directory
    global OUTPUT_DIR
    OUTPUT_DIR = Path(args.output_dir)
    OUTPUT_DIR.mkdir(exist_ok=True)
    
    # Generate signals
    signals = generate_daily_signals(
        symbol=args.symbol,
        categories=args.categories,
        strategies=strategies,
        use_ai=args.use_ai,
        save_to_file=not args.no_save and not args.summary_only
    )
    
    # Print summary
    print_daily_summary(signals)
    
    # Exit with appropriate code
    if signals:
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()

