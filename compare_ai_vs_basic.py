#!/usr/bin/env python3
"""
Compare AI-Enhanced vs Basic Signals
Day 49: Analyze performance difference between AI-enhanced and basic signals

This script compares the performance of AI-enhanced signals vs basic signals
to validate AI enhancement effectiveness.
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


class AIVsBasicComparator:
    """Compare AI-enhanced vs basic signal performance"""
    
    def __init__(self, days: int = 30):
        """Initialize comparator with time period"""
        self.days = days
        self.end_date = timezone.now() if django else datetime.now()
        self.start_date = self.end_date - timedelta(days=days)
    
    def get_signals_with_outcomes(self) -> List[Dict[str, Any]]:
        """Get signals with their outcomes and AI enhancement status"""
        if not django:
            return self._mock_signals()
        
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT 
                    s.id,
                    s.symbol,
                    s.confidence,
                    s.ai_enhanced,
                    s.ai_confidence,
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
                    'ai_enhanced': bool(row[3]) if row[3] is not None else False,
                    'ai_confidence': float(row[4]) if row[4] else None,
                    'created_at': row[5],
                    'execution_id': row[6],
                    'pnl_usd': float(row[7]) if row[7] else None,
                    'pnl_pct': float(row[8]) if row[8] else None,
                    'closed_at': row[9]
                })
            
            return signals
    
    def compare_performance(self, signals: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Compare AI-enhanced vs basic signal performance"""
        ai_signals = [s for s in signals if s.get('ai_enhanced', False)]
        basic_signals = [s for s in signals if not s.get('ai_enhanced', False)]
        
        # Calculate metrics for AI-enhanced signals
        ai_metrics = self._calculate_metrics(ai_signals)
        
        # Calculate metrics for basic signals
        basic_metrics = self._calculate_metrics(basic_signals)
        
        # Calculate improvement
        improvement = {}
        if basic_metrics['closed_trades'] > 0 and ai_metrics['closed_trades'] > 0:
            improvement = {
                'win_rate_improvement': ai_metrics['win_rate'] - basic_metrics['win_rate'],
                'signal_accuracy_improvement': ai_metrics['signal_accuracy'] - basic_metrics['signal_accuracy'],
                'avg_return_improvement': ai_metrics['avg_return'] - basic_metrics['avg_return'],
                'false_positive_improvement': basic_metrics['false_positive_rate'] - ai_metrics['false_positive_rate'],
                'total_pnl_improvement': ai_metrics['total_pnl'] - basic_metrics['total_pnl']
            }
        
        return {
            'ai_enhanced': ai_metrics,
            'basic': basic_metrics,
            'improvement': improvement,
            'summary': {
                'total_signals': len(signals),
                'ai_enhanced_count': len(ai_signals),
                'basic_count': len(basic_signals),
                'ai_enhanced_pct': (len(ai_signals) / len(signals) * 100) if signals else 0.0
            }
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
        
        avg_confidence = sum([s['confidence'] for s in signals]) / len(signals) if signals else 0.0
        
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
            'total_pnl': round(total_pnl, 2),
            'avg_confidence': round(avg_confidence, 2)
        }
    
    def _mock_signals(self) -> List[Dict[str, Any]]:
        """Mock signals for testing"""
        return [
            {'id': 1, 'symbol': 'AAPL', 'confidence': 0.75, 'ai_enhanced': True, 'ai_confidence': 0.80, 'created_at': datetime.now(), 'execution_id': 1, 'pnl_usd': 120.0, 'pnl_pct': 2.5, 'closed_at': datetime.now()},
            {'id': 2, 'symbol': 'MSFT', 'confidence': 0.70, 'ai_enhanced': True, 'ai_confidence': 0.75, 'created_at': datetime.now(), 'execution_id': 2, 'pnl_usd': 90.0, 'pnl_pct': 1.8, 'closed_at': datetime.now()},
            {'id': 3, 'symbol': 'TSLA', 'confidence': 0.65, 'ai_enhanced': False, 'ai_confidence': None, 'created_at': datetime.now(), 'execution_id': 3, 'pnl_usd': -40.0, 'pnl_pct': -0.8, 'closed_at': datetime.now()},
            {'id': 4, 'symbol': 'GOOGL', 'confidence': 0.68, 'ai_enhanced': True, 'ai_confidence': 0.72, 'created_at': datetime.now(), 'execution_id': 4, 'pnl_usd': 70.0, 'pnl_pct': 1.4, 'closed_at': datetime.now()},
            {'id': 5, 'symbol': 'AMZN', 'confidence': 0.64, 'ai_enhanced': False, 'ai_confidence': None, 'created_at': datetime.now(), 'execution_id': 5, 'pnl_usd': -20.0, 'pnl_pct': -0.4, 'closed_at': datetime.now()},
        ]


def main():
    """Main comparison function"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Compare AI-enhanced vs basic signals')
    parser.add_argument('--days', type=int, default=30, help='Number of days to analyze')
    parser.add_argument('--output', type=str, help='Output JSON file path')
    
    args = parser.parse_args()
    
    comparator = AIVsBasicComparator(days=args.days)
    
    print(f"Comparing AI-enhanced vs basic signals for last {args.days} days...")
    print(f"Period: {comparator.start_date} to {comparator.end_date}\n")
    
    # Get signals
    signals = comparator.get_signals_with_outcomes()
    print(f"Total signals found: {len(signals)}")
    
    # Compare performance
    comparison = comparator.compare_performance(signals)
    
    # Print results
    print("\n" + "=" * 60)
    print("AI-ENHANCED VS BASIC SIGNAL COMPARISON")
    print("=" * 60)
    
    print(f"\nSummary:")
    print(f"  Total Signals: {comparison['summary']['total_signals']}")
    print(f"  AI-Enhanced: {comparison['summary']['ai_enhanced_count']} ({comparison['summary']['ai_enhanced_pct']:.1f}%)")
    print(f"  Basic: {comparison['summary']['basic_count']}")
    
    print(f"\nAI-Enhanced Signals:")
    ai = comparison['ai_enhanced']
    print(f"  Total: {ai['total_signals']}")
    print(f"  Executed: {ai['executed_signals']}")
    print(f"  Closed: {ai['closed_trades']}")
    print(f"  Win Rate: {ai['win_rate']}%")
    print(f"  Signal Accuracy: {ai['signal_accuracy']}%")
    print(f"  False Positive Rate: {ai['false_positive_rate']}%")
    print(f"  Average Return: {ai['avg_return']}%")
    print(f"  Total P&L: ${ai['total_pnl']:.2f}")
    print(f"  Avg Confidence: {ai['avg_confidence']:.2%}")
    
    print(f"\nBasic Signals:")
    basic = comparison['basic']
    print(f"  Total: {basic['total_signals']}")
    print(f"  Executed: {basic['executed_signals']}")
    print(f"  Closed: {basic['closed_trades']}")
    print(f"  Win Rate: {basic['win_rate']}%")
    print(f"  Signal Accuracy: {basic['signal_accuracy']}%")
    print(f"  False Positive Rate: {basic['false_positive_rate']}%")
    print(f"  Average Return: {basic['avg_return']}%")
    print(f"  Total P&L: ${basic['total_pnl']:.2f}")
    print(f"  Avg Confidence: {basic['avg_confidence']:.2%}")
    
    if comparison['improvement']:
        print(f"\nImprovement (AI vs Basic):")
        imp = comparison['improvement']
        print(f"  Win Rate: {imp['win_rate_improvement']:+.2f}%")
        print(f"  Signal Accuracy: {imp['signal_accuracy_improvement']:+.2f}%")
        print(f"  Average Return: {imp['avg_return_improvement']:+.2f}%")
        print(f"  False Positive Rate: {imp['false_positive_improvement']:+.2f}%")
        print(f"  Total P&L: ${imp['total_pnl_improvement']:+.2f}")
    
    # Save to file if requested
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(comparison, f, indent=2, default=str)
        print(f"\nResults saved to {args.output}")
    
    return comparison


if __name__ == '__main__':
    main()
