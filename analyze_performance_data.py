#!/usr/bin/env python3
"""
Performance Data Analysis Script
Day 46: Analyze Week 9 performance data and identify signal quality issues

This script analyzes performance data from the performance tracking system
to identify signal quality issues and areas for improvement.
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
    from trading.models import SignalExecution
except ImportError:
    print("Warning: Django not available, using mock data mode")
    django = None


class PerformanceAnalyzer:
    """Analyze performance data to identify signal quality issues"""
    
    def __init__(self, days: int = 30):
        """Initialize analyzer with time period"""
        self.days = days
        self.end_date = timezone.now() if django else datetime.now()
        self.start_date = self.end_date - timedelta(days=days)
    
    def analyze_overall_performance(self) -> Dict[str, Any]:
        """Analyze overall performance metrics"""
        if not django:
            return self._mock_overall_performance()
        
        with connection.cursor() as cursor:
            # Get total signals
            cursor.execute("""
                SELECT COUNT(*) as total_signals
                FROM signals
                WHERE created_at >= %s AND created_at <= %s
            """, [self.start_date, self.end_date])
            total_signals = cursor.fetchone()[0] or 0
            
            # Get executed signals
            cursor.execute("""
                SELECT COUNT(DISTINCT se.signal_id) as executed_signals
                FROM signal_executions se
                JOIN signals s ON se.signal_id = s.id
                WHERE s.created_at >= %s AND s.created_at <= %s
            """, [self.start_date, self.end_date])
            executed_signals = cursor.fetchone()[0] or 0
            
            # Get closed trades
            cursor.execute("""
                SELECT 
                    COUNT(*) as closed_trades,
                    SUM(CASE WHEN pnl_usd > 0 THEN 1 ELSE 0 END) as winning_trades,
                    SUM(CASE WHEN pnl_usd < 0 THEN 1 ELSE 0 END) as losing_trades,
                    AVG(pnl_pct) as avg_return,
                    SUM(pnl_usd) as total_pnl
                FROM signal_executions
                WHERE closed_at IS NOT NULL
                AND closed_at >= %s AND closed_at <= %s
            """, [self.start_date, self.end_date])
            
            row = cursor.fetchone()
            closed_trades = row[0] or 0
            winning_trades = row[1] or 0
            losing_trades = row[2] or 0
            avg_return = float(row[3]) if row[3] else 0.0
            total_pnl = float(row[4]) if row[4] else 0.0
            
            # Calculate metrics
            win_rate = (winning_trades / closed_trades * 100) if closed_trades > 0 else 0.0
            signal_accuracy = (winning_trades / executed_signals * 100) if executed_signals > 0 else 0.0
            false_positive_rate = (losing_trades / executed_signals * 100) if executed_signals > 0 else 0.0
            execution_rate = (executed_signals / total_signals * 100) if total_signals > 0 else 0.0
            
            return {
                'total_signals': total_signals,
                'executed_signals': executed_signals,
                'closed_trades': closed_trades,
                'winning_trades': winning_trades,
                'losing_trades': losing_trades,
                'win_rate': round(win_rate, 2),
                'signal_accuracy': round(signal_accuracy, 2),
                'false_positive_rate': round(false_positive_rate, 2),
                'avg_return': round(avg_return, 2),
                'total_pnl': round(total_pnl, 2),
                'execution_rate': round(execution_rate, 2)
            }
    
    def analyze_by_confidence(self) -> Dict[str, Any]:
        """Analyze performance by confidence level"""
        if not django:
            return self._mock_confidence_analysis()
        
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT 
                    CASE 
                        WHEN s.confidence >= 0.8 THEN 'High (≥80%)'
                        WHEN s.confidence >= 0.6 THEN 'Medium (60-79%)'
                        WHEN s.confidence >= 0.4 THEN 'Low (40-59%)'
                        ELSE 'Very Low (<40%)'
                    END as confidence_range,
                    COUNT(DISTINCT s.id) as total_signals,
                    COUNT(DISTINCT se.signal_id) as executed_signals,
                    COUNT(se.id) as closed_trades,
                    SUM(CASE WHEN se.pnl_usd > 0 THEN 1 ELSE 0 END) as winning_trades,
                    AVG(se.pnl_pct) as avg_return,
                    SUM(se.pnl_usd) as total_pnl
                FROM signals s
                LEFT JOIN signal_executions se ON s.id = se.signal_id
                WHERE s.created_at >= %s AND s.created_at <= %s
                AND (se.closed_at IS NULL OR se.closed_at >= %s)
                GROUP BY confidence_range
                ORDER BY 
                    CASE confidence_range
                        WHEN 'High (≥80%)' THEN 1
                        WHEN 'Medium (60-79%)' THEN 2
                        WHEN 'Low (40-59%)' THEN 3
                        ELSE 4
                    END
            """, [self.start_date, self.end_date, self.start_date])
            
            results = []
            for row in cursor.fetchall():
                closed = row[3] or 0
                winning = row[4] or 0
                win_rate = (winning / closed * 100) if closed > 0 else 0.0
                
                results.append({
                    'confidence_range': row[0],
                    'total_signals': row[1] or 0,
                    'executed_signals': row[2] or 0,
                    'closed_trades': closed,
                    'winning_trades': winning,
                    'win_rate': round(win_rate, 2),
                    'avg_return': round(float(row[5]) if row[5] else 0.0, 2),
                    'total_pnl': round(float(row[6]) if row[6] else 0.0, 2)
                })
            
            return {'by_confidence': results}
    
    def analyze_by_symbol(self) -> Dict[str, Any]:
        """Analyze performance by symbol"""
        if not django:
            return self._mock_symbol_analysis()
        
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT 
                    se.signal_symbol,
                    COUNT(DISTINCT se.signal_id) as total_signals,
                    COUNT(se.id) as closed_trades,
                    SUM(CASE WHEN se.pnl_usd > 0 THEN 1 ELSE 0 END) as winning_trades,
                    AVG(se.pnl_pct) as avg_return,
                    SUM(se.pnl_usd) as total_pnl
                FROM signal_executions se
                WHERE se.closed_at IS NOT NULL
                AND se.closed_at >= %s AND se.closed_at <= %s
                GROUP BY se.signal_symbol
                HAVING COUNT(se.id) >= 3
                ORDER BY 
                    SUM(CASE WHEN se.pnl_usd > 0 THEN 1 ELSE 0 END)::float / NULLIF(COUNT(se.id), 0) DESC
            """, [self.start_date, self.end_date])
            
            results = []
            for row in cursor.fetchall():
                closed = row[2] or 0
                winning = row[3] or 0
                win_rate = (winning / closed * 100) if closed > 0 else 0.0
                
                results.append({
                    'symbol': row[0],
                    'total_signals': row[1] or 0,
                    'closed_trades': closed,
                    'winning_trades': winning,
                    'win_rate': round(win_rate, 2),
                    'avg_return': round(float(row[4]) if row[4] else 0.0, 2),
                    'total_pnl': round(float(row[5]) if row[5] else 0.0, 2)
                })
            
            return {'by_symbol': results}
    
    def identify_issues(self, overall: Dict, by_confidence: Dict, by_symbol: Dict) -> List[Dict[str, Any]]:
        """Identify signal quality issues based on analysis"""
        issues = []
        
        # Check overall win rate
        if overall.get('win_rate', 0) < 55:
            issues.append({
                'severity': 'high',
                'category': 'win_rate',
                'issue': f"Overall win rate ({overall['win_rate']}%) is below target (55%)",
                'recommendation': 'Increase confidence threshold or improve signal filtering'
            })
        
        # Check false positive rate
        if overall.get('false_positive_rate', 0) > 40:
            issues.append({
                'severity': 'high',
                'category': 'false_positive_rate',
                'issue': f"False positive rate ({overall['false_positive_rate']}%) is above target (40%)",
                'recommendation': 'Improve signal validation and filtering'
            })
        
        # Check signal accuracy
        if overall.get('signal_accuracy', 0) < 60:
            issues.append({
                'severity': 'medium',
                'category': 'signal_accuracy',
                'issue': f"Signal accuracy ({overall['signal_accuracy']}%) is below target (60%)",
                'recommendation': 'Review signal generation logic and improve quality scoring'
            })
        
        # Check execution rate
        if overall.get('execution_rate', 0) < 70:
            issues.append({
                'severity': 'low',
                'category': 'execution_rate',
                'issue': f"Execution rate ({overall['execution_rate']}%) is below target (70%)",
                'recommendation': 'Review why signals are not being executed'
            })
        
        # Check confidence-based performance
        if 'by_confidence' in by_confidence:
            for conf_data in by_confidence['by_confidence']:
                if conf_data['closed_trades'] >= 5:  # Only analyze if enough data
                    if conf_data['win_rate'] < 50 and 'High' in conf_data['confidence_range']:
                        issues.append({
                            'severity': 'high',
                            'category': 'confidence_threshold',
                            'issue': f"High confidence signals ({conf_data['confidence_range']}) have low win rate ({conf_data['win_rate']}%)",
                            'recommendation': 'Review confidence calculation logic'
                        })
        
        # Check symbol performance
        if 'by_symbol' in by_symbol:
            poor_performers = [s for s in by_symbol['by_symbol'] 
                             if s['closed_trades'] >= 5 and s['win_rate'] < 45]
            if poor_performers:
                symbols = ', '.join([s['symbol'] for s in poor_performers[:5]])
                issues.append({
                    'severity': 'medium',
                    'category': 'symbol_performance',
                    'issue': f"Poor performing symbols: {symbols}",
                    'recommendation': 'Review signal generation for these symbols or consider excluding them'
                })
        
        return issues
    
    def _mock_overall_performance(self) -> Dict[str, Any]:
        """Mock data for testing without Django"""
        return {
            'total_signals': 150,
            'executed_signals': 100,
            'closed_trades': 80,
            'winning_trades': 42,
            'losing_trades': 38,
            'win_rate': 52.5,
            'signal_accuracy': 42.0,
            'false_positive_rate': 38.0,
            'avg_return': 1.2,
            'total_pnl': 960.0,
            'execution_rate': 66.7
        }
    
    def _mock_confidence_analysis(self) -> Dict[str, Any]:
        """Mock confidence analysis"""
        return {
            'by_confidence': [
                {
                    'confidence_range': 'High (≥80%)',
                    'total_signals': 30,
                    'executed_signals': 25,
                    'closed_trades': 20,
                    'winning_trades': 12,
                    'win_rate': 60.0,
                    'avg_return': 2.5,
                    'total_pnl': 500.0
                },
                {
                    'confidence_range': 'Medium (60-79%)',
                    'total_signals': 80,
                    'executed_signals': 55,
                    'closed_trades': 45,
                    'winning_trades': 22,
                    'win_rate': 48.9,
                    'avg_return': 0.8,
                    'total_pnl': 360.0
                },
                {
                    'confidence_range': 'Low (40-59%)',
                    'total_signals': 40,
                    'executed_signals': 20,
                    'closed_trades': 15,
                    'winning_trades': 8,
                    'win_rate': 53.3,
                    'avg_return': 0.5,
                    'total_pnl': 100.0
                }
            ]
        }
    
    def _mock_symbol_analysis(self) -> Dict[str, Any]:
        """Mock symbol analysis"""
        return {
            'by_symbol': [
                {'symbol': 'AAPL', 'total_signals': 15, 'closed_trades': 12, 'winning_trades': 8, 'win_rate': 66.7, 'avg_return': 2.1, 'total_pnl': 252.0},
                {'symbol': 'MSFT', 'total_signals': 12, 'closed_trades': 10, 'winning_trades': 6, 'win_rate': 60.0, 'avg_return': 1.8, 'total_pnl': 180.0},
                {'symbol': 'TSLA', 'total_signals': 10, 'closed_trades': 8, 'winning_trades': 3, 'win_rate': 37.5, 'avg_return': -0.5, 'total_pnl': -40.0},
            ]
        }


def main():
    """Main analysis function"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Analyze performance data')
    parser.add_argument('--days', type=int, default=30, help='Number of days to analyze')
    parser.add_argument('--output', type=str, help='Output JSON file path')
    
    args = parser.parse_args()
    
    analyzer = PerformanceAnalyzer(days=args.days)
    
    print(f"Analyzing performance data for last {args.days} days...")
    print(f"Period: {analyzer.start_date} to {analyzer.end_date}\n")
    
    # Run analyses
    overall = analyzer.analyze_overall_performance()
    by_confidence = analyzer.analyze_by_confidence()
    by_symbol = analyzer.analyze_by_symbol()
    
    # Identify issues
    issues = analyzer.identify_issues(overall, by_confidence, by_symbol)
    
    # Compile results
    results = {
        'analysis_period': {
            'start_date': analyzer.start_date.isoformat(),
            'end_date': analyzer.end_date.isoformat(),
            'days': args.days
        },
        'overall_performance': overall,
        'by_confidence': by_confidence,
        'by_symbol': by_symbol,
        'issues': issues,
        'summary': {
            'total_issues': len(issues),
            'high_severity': len([i for i in issues if i['severity'] == 'high']),
            'medium_severity': len([i for i in issues if i['severity'] == 'medium']),
            'low_severity': len([i for i in issues if i['severity'] == 'low'])
        }
    }
    
    # Print summary
    print("=" * 60)
    print("PERFORMANCE ANALYSIS SUMMARY")
    print("=" * 60)
    print(f"\nOverall Performance:")
    print(f"  Total Signals: {overall['total_signals']}")
    print(f"  Executed: {overall['executed_signals']} ({overall['execution_rate']}%)")
    print(f"  Closed Trades: {overall['closed_trades']}")
    print(f"  Win Rate: {overall['win_rate']}%")
    print(f"  Signal Accuracy: {overall['signal_accuracy']}%")
    print(f"  False Positive Rate: {overall['false_positive_rate']}%")
    print(f"  Average Return: {overall['avg_return']}%")
    print(f"  Total P&L: ${overall['total_pnl']:.2f}")
    
    print(f"\nIssues Identified: {len(issues)}")
    for issue in issues:
        print(f"  [{issue['severity'].upper()}] {issue['category']}: {issue['issue']}")
        print(f"    Recommendation: {issue['recommendation']}")
    
    # Save to file if requested
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        print(f"\nResults saved to {args.output}")
    
    return results


if __name__ == '__main__':
    main()
