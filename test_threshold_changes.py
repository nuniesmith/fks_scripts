#!/usr/bin/env python3
"""
Test Threshold Changes Script
Day 47: Compare old vs new threshold performance

This script simulates signal filtering with old (0.6) vs new (0.65) thresholds
to estimate the impact of threshold changes.
"""

import sys
import os
import json
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
from collections import defaultdict

# Add project root to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../'))

try:
    import django
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'trading.settings')
    django.setup()
    
    from django.db import connection
    from django.utils import timezone
except ImportError:
    print("Warning: Django not available, using mock data mode")
    django = None


class ThresholdTester:
    """Test threshold changes by comparing old vs new filtering"""
    
    def __init__(self, days: int = 30):
        """Initialize tester with time period"""
        self.days = days
        self.end_date = timezone.now() if django else datetime.now()
        self.start_date = self.end_date - timedelta(days=days)
        self.old_threshold = 0.6
        self.new_threshold = 0.65
    
    def get_signals_with_outcomes(self) -> List[Dict[str, Any]]:
        """Get signals with their outcomes"""
        if not django:
            return self._mock_signals()
        
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT 
                    s.id,
                    s.symbol,
                    s.confidence,
                    s.created_at,
                    se.id as execution_id,
                    se.pnl_usd,
                    se.pnl_pct,
                    se.closed_at
                FROM signals s
                LEFT JOIN signal_executions se ON s.id = se.signal_id
                WHERE s.created_at >= %s AND s.created_at <= %s
                AND (se.closed_at IS NOT NULL OR se.id IS NULL)
                ORDER BY s.created_at DESC
            """, [self.start_date, self.end_date])
            
            signals = []
            for row in cursor.fetchall():
                signals.append({
                    'id': row[0],
                    'symbol': row[1],
                    'confidence': float(row[2]) if row[2] else 0.0,
                    'created_at': row[3],
                    'execution_id': row[4],
                    'pnl_usd': float(row[5]) if row[5] else None,
                    'pnl_pct': float(row[6]) if row[6] else None,
                    'closed_at': row[7]
                })
            
            return signals
    
    def compare_thresholds(self, signals: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Compare old vs new threshold filtering"""
        old_filtered = [s for s in signals if s['confidence'] >= self.old_threshold]
        new_filtered = [s for s in signals if s['confidence'] >= self.new_threshold]
        
        # Calculate metrics for old threshold
        old_metrics = self._calculate_metrics(old_filtered)
        
        # Calculate metrics for new threshold
        new_metrics = self._calculate_metrics(new_filtered)
        
        # Calculate impact
        impact = {
            'signals_filtered_out': len(old_filtered) - len(new_filtered),
            'signals_reduction_pct': ((len(old_filtered) - len(new_filtered)) / len(old_filtered) * 100) if old_filtered else 0,
            'win_rate_change': new_metrics['win_rate'] - old_metrics['win_rate'],
            'signal_accuracy_change': new_metrics['signal_accuracy'] - old_metrics['signal_accuracy'],
            'false_positive_change': new_metrics['false_positive_rate'] - old_metrics['false_positive_rate'],
            'avg_return_change': new_metrics['avg_return'] - old_metrics['avg_return']
        }
        
        return {
            'old_threshold': self.old_threshold,
            'new_threshold': self.new_threshold,
            'old_metrics': old_metrics,
            'new_metrics': new_metrics,
            'impact': impact
        }
    
    def _calculate_metrics(self, signals: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Calculate performance metrics for a set of signals"""
        total_signals = len(signals)
        executed = [s for s in signals if s['execution_id'] is not None]
        closed = [s for s in executed if s['closed_at'] is not None]
        winning = [s for s in closed if s['pnl_usd'] and s['pnl_usd'] > 0]
        losing = [s for s in closed if s['pnl_usd'] and s['pnl_usd'] < 0]
        
        win_rate = (len(winning) / len(closed) * 100) if closed else 0.0
        signal_accuracy = (len(winning) / len(executed) * 100) if executed else 0.0
        false_positive_rate = (len(losing) / len(executed) * 100) if executed else 0.0
        
        avg_return = sum([s['pnl_pct'] for s in closed if s['pnl_pct']]) / len(closed) if closed else 0.0
        total_pnl = sum([s['pnl_usd'] for s in closed if s['pnl_usd']]) if closed else 0.0
        
        return {
            'total_signals': total_signals,
            'executed_signals': len(executed),
            'closed_trades': len(closed),
            'winning_trades': len(winning),
            'losing_trades': len(losing),
            'win_rate': round(win_rate, 2),
            'signal_accuracy': round(signal_accuracy, 2),
            'false_positive_rate': round(false_positive_rate, 2),
            'avg_return': round(avg_return, 2),
            'total_pnl': round(total_pnl, 2)
        }
    
    def _mock_signals(self) -> List[Dict[str, Any]]:
        """Mock signals for testing"""
        return [
            {'id': 1, 'symbol': 'AAPL', 'confidence': 0.75, 'created_at': datetime.now(), 'execution_id': 1, 'pnl_usd': 100.0, 'pnl_pct': 2.0, 'closed_at': datetime.now()},
            {'id': 2, 'symbol': 'MSFT', 'confidence': 0.70, 'created_at': datetime.now(), 'execution_id': 2, 'pnl_usd': 80.0, 'pnl_pct': 1.5, 'closed_at': datetime.now()},
            {'id': 3, 'symbol': 'TSLA', 'confidence': 0.62, 'created_at': datetime.now(), 'execution_id': 3, 'pnl_usd': -50.0, 'pnl_pct': -1.0, 'closed_at': datetime.now()},
            {'id': 4, 'symbol': 'GOOGL', 'confidence': 0.68, 'created_at': datetime.now(), 'execution_id': 4, 'pnl_usd': 60.0, 'pnl_pct': 1.2, 'closed_at': datetime.now()},
            {'id': 5, 'symbol': 'AMZN', 'confidence': 0.64, 'created_at': datetime.now(), 'execution_id': 5, 'pnl_usd': -30.0, 'pnl_pct': -0.5, 'closed_at': datetime.now()},
            {'id': 6, 'symbol': 'NVDA', 'confidence': 0.72, 'created_at': datetime.now(), 'execution_id': 6, 'pnl_usd': 120.0, 'pnl_pct': 2.5, 'closed_at': datetime.now()},
        ]


def main():
    """Main test function"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Test threshold changes')
    parser.add_argument('--days', type=int, default=30, help='Number of days to analyze')
    parser.add_argument('--output', type=str, help='Output JSON file path')
    
    args = parser.parse_args()
    
    tester = ThresholdTester(days=args.days)
    
    print(f"Testing threshold changes for last {args.days} days...")
    print(f"Old Threshold: {tester.old_threshold} (60%)")
    print(f"New Threshold: {tester.new_threshold} (65%)")
    print(f"Period: {tester.start_date} to {tester.end_date}\n")
    
    # Get signals
    signals = tester.get_signals_with_outcomes()
    print(f"Total signals found: {len(signals)}")
    
    # Compare thresholds
    comparison = tester.compare_thresholds(signals)
    
    # Print results
    print("\n" + "=" * 60)
    print("THRESHOLD COMPARISON RESULTS")
    print("=" * 60)
    
    print(f"\nOld Threshold ({comparison['old_threshold']:.0%}):")
    old = comparison['old_metrics']
    print(f"  Signals: {old['total_signals']}")
    print(f"  Win Rate: {old['win_rate']}%")
    print(f"  Signal Accuracy: {old['signal_accuracy']}%")
    print(f"  False Positive Rate: {old['false_positive_rate']}%")
    print(f"  Average Return: {old['avg_return']}%")
    
    print(f"\nNew Threshold ({comparison['new_threshold']:.0%}):")
    new = comparison['new_metrics']
    print(f"  Signals: {new['total_signals']}")
    print(f"  Win Rate: {new['win_rate']}%")
    print(f"  Signal Accuracy: {new['signal_accuracy']}%")
    print(f"  False Positive Rate: {new['false_positive_rate']}%")
    print(f"  Average Return: {new['avg_return']}%")
    
    print(f"\nImpact:")
    impact = comparison['impact']
    print(f"  Signals Filtered Out: {impact['signals_filtered_out']} ({impact['signals_reduction_pct']:.1f}% reduction)")
    print(f"  Win Rate Change: {impact['win_rate_change']:+.2f}%")
    print(f"  Signal Accuracy Change: {impact['signal_accuracy_change']:+.2f}%")
    print(f"  False Positive Change: {impact['false_positive_change']:+.2f}%")
    print(f"  Average Return Change: {impact['avg_return_change']:+.2f}%")
    
    # Save to file if requested
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(comparison, f, indent=2, default=str)
        print(f"\nResults saved to {args.output}")
    
    return comparison


if __name__ == '__main__':
    main()
