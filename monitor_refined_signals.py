#!/usr/bin/env python3
"""
Monitor Refined Signals
Day 50: Monitor refined signals for 24 hours and track improvements

This script monitors signal generation and performance after Week 10 refinements
to validate improvements.
"""

import sys
import os
import json
import time
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


class RefinedSignalMonitor:
    """Monitor refined signals and track improvements"""
    
    def __init__(self, hours: int = 24):
        """Initialize monitor with time period"""
        self.hours = hours
        self.end_date = timezone.now() if django else datetime.now()
        self.start_date = self.end_date - timedelta(hours=hours)
    
    def get_refined_signals(self) -> Dict[str, Any]:
        """Get signals generated after refinements"""
        if not django:
            return self._mock_refined_signals()
        
        with connection.cursor() as cursor:
            # Get signals with confidence >= 0.65 (new threshold)
            cursor.execute("""
                SELECT 
                    COUNT(*) as total_signals,
                    COUNT(CASE WHEN confidence >= 0.65 THEN 1 END) as above_threshold,
                    COUNT(CASE WHEN ai_enhanced = TRUE THEN 1 END) as ai_enhanced,
                    AVG(confidence) as avg_confidence,
                    COUNT(CASE WHEN quality_score >= 70 THEN 1 END) as high_quality
                FROM signals
                WHERE created_at >= %s AND created_at <= %s
            """, [self.start_date, self.end_date])
            
            row = cursor.fetchone()
            return {
                'total_signals': row[0] or 0,
                'above_threshold': row[1] or 0,
                'ai_enhanced': row[2] or 0,
                'avg_confidence': float(row[3]) if row[3] else 0.0,
                'high_quality': row[4] or 0
            }
    
    def get_performance_metrics(self) -> Dict[str, Any]:
        """Get performance metrics for refined signals"""
        if not django:
            return self._mock_performance()
        
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT 
                    COUNT(DISTINCT s.id) as total_signals,
                    COUNT(DISTINCT se.signal_id) as executed_signals,
                    COUNT(se.id) as closed_trades,
                    SUM(CASE WHEN se.pnl_usd > 0 THEN 1 ELSE 0 END) as winning_trades,
                    SUM(CASE WHEN se.pnl_usd < 0 THEN 1 ELSE 0 END) as losing_trades,
                    AVG(se.pnl_pct) as avg_return,
                    SUM(se.pnl_usd) as total_pnl
                FROM signals s
                LEFT JOIN signal_executions se ON s.id = se.signal_id
                WHERE s.created_at >= %s AND s.created_at <= %s
                AND s.confidence >= 0.65
                AND (se.closed_at IS NOT NULL OR se.id IS NULL)
            """, [self.start_date, self.end_date])
            
            row = cursor.fetchone()
            total_signals = row[0] or 0
            executed = row[1] or 0
            closed = row[2] or 0
            winning = row[3] or 0
            losing = row[4] or 0
            
            win_rate = (winning / closed * 100) if closed > 0 else 0.0
            signal_accuracy = (winning / executed * 100) if executed > 0 else 0.0
            false_positive_rate = (losing / executed * 100) if executed > 0 else 0.0
            execution_rate = (executed / total_signals * 100) if total_signals > 0 else 0.0
            
            return {
                'total_signals': total_signals,
                'executed_signals': executed,
                'closed_trades': closed,
                'winning_trades': winning,
                'losing_trades': losing,
                'win_rate': round(win_rate, 2),
                'signal_accuracy': round(signal_accuracy, 2),
                'false_positive_rate': round(false_positive_rate, 2),
                'avg_return': round(float(row[5]) if row[5] else 0.0, 2),
                'total_pnl': round(float(row[6]) if row[6] else 0.0, 2),
                'execution_rate': round(execution_rate, 2)
            }
    
    def compare_with_baseline(self, refined: Dict, baseline: Dict) -> Dict[str, Any]:
        """Compare refined metrics with baseline (Week 9)"""
        comparison = {}
        
        for metric in ['win_rate', 'signal_accuracy', 'false_positive_rate', 'avg_return', 'execution_rate']:
            if metric in refined and metric in baseline:
                refined_val = refined.get(metric, 0)
                baseline_val = baseline.get(metric, 0)
                improvement = refined_val - baseline_val
                improvement_pct = (improvement / baseline_val * 100) if baseline_val > 0 else 0.0
                
                comparison[metric] = {
                    'baseline': baseline_val,
                    'refined': refined_val,
                    'improvement': round(improvement, 2),
                    'improvement_pct': round(improvement_pct, 2),
                    'status': 'improved' if improvement > 0 or (metric == 'false_positive_rate' and improvement < 0) else 'needs_work'
                }
        
        return comparison
    
    def _mock_refined_signals(self) -> Dict[str, Any]:
        """Mock refined signals for testing"""
        return {
            'total_signals': 120,
            'above_threshold': 110,
            'ai_enhanced': 85,
            'avg_confidence': 0.72,
            'high_quality': 95
        }
    
    def _mock_performance(self) -> Dict[str, Any]:
        """Mock performance for testing"""
        return {
            'total_signals': 120,
            'executed_signals': 90,
            'closed_trades': 75,
            'winning_trades': 42,
            'losing_trades': 33,
            'win_rate': 56.0,
            'signal_accuracy': 46.7,
            'false_positive_rate': 36.7,
            'avg_return': 1.8,
            'total_pnl': 1350.0,
            'execution_rate': 75.0
        }


def main():
    """Main monitoring function"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Monitor refined signals')
    parser.add_argument('--hours', type=int, default=24, help='Number of hours to monitor')
    parser.add_argument('--baseline', type=str, help='Baseline metrics JSON file')
    parser.add_argument('--output', type=str, help='Output JSON file path')
    
    args = parser.parse_args()
    
    monitor = RefinedSignalMonitor(hours=args.hours)
    
    print(f"Monitoring refined signals for last {args.hours} hours...")
    print(f"Period: {monitor.start_date} to {monitor.end_date}\n")
    
    # Get refined signals
    refined_signals = monitor.get_refined_signals()
    print(f"Refined Signals:")
    print(f"  Total: {refined_signals['total_signals']}")
    print(f"  Above Threshold (≥0.65): {refined_signals['above_threshold']}")
    print(f"  AI-Enhanced: {refined_signals['ai_enhanced']}")
    print(f"  High Quality (≥70): {refined_signals['high_quality']}")
    print(f"  Avg Confidence: {refined_signals['avg_confidence']:.2%}")
    
    # Get performance metrics
    performance = monitor.get_performance_metrics()
    print(f"\nPerformance Metrics:")
    print(f"  Total Signals: {performance['total_signals']}")
    print(f"  Executed: {performance['executed_signals']} ({performance['execution_rate']}%)")
    print(f"  Closed Trades: {performance['closed_trades']}")
    print(f"  Win Rate: {performance['win_rate']}%")
    print(f"  Signal Accuracy: {performance['signal_accuracy']}%")
    print(f"  False Positive Rate: {performance['false_positive_rate']}%")
    print(f"  Average Return: {performance['avg_return']}%")
    print(f"  Total P&L: ${performance['total_pnl']:.2f}")
    
    # Compare with baseline if provided
    if args.baseline:
        with open(args.baseline, 'r') as f:
            baseline = json.load(f)
        
        comparison = monitor.compare_with_baseline(performance, baseline)
        print(f"\nComparison with Baseline:")
        for metric, comp in comparison.items():
            status_icon = "✅" if comp['status'] == 'improved' else "⚠️"
            print(f"  {metric.replace('_', ' ').title()}:")
            print(f"    Baseline: {comp['baseline']}")
            print(f"    Refined: {comp['refined']}")
            print(f"    Improvement: {comp['improvement']:+.2f} ({comp['improvement_pct']:+.1f}%) {status_icon}")
    
    # Compile results
    results = {
        'monitoring_period': {
            'start_date': monitor.start_date.isoformat(),
            'end_date': monitor.end_date.isoformat(),
            'hours': args.hours
        },
        'refined_signals': refined_signals,
        'performance': performance,
        'comparison': comparison if args.baseline else None
    }
    
    # Save to file if requested
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        print(f"\nResults saved to {args.output}")
    
    return results


if __name__ == '__main__':
    main()
