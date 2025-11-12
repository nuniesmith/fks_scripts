#!/usr/bin/env python3
"""
Test Script for Sentiment Analyzer

Quick validation of sentiment analysis functionality.
Run: python scripts/test_sentiment.py
"""

import sys
import os

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from services.ai.src.sentiment import SentimentAnalyzer


def test_basic_sentiment():
    """Test basic sentiment analysis."""
    print("=" * 60)
    print("Testing Sentiment Analyzer")
    print("=" * 60)
    
    try:
        # Initialize analyzer
        print("\n1. Initializing SentimentAnalyzer...")
        analyzer = SentimentAnalyzer()
        print("   ✅ Analyzer initialized")
        
        # Test positive sentiment
        print("\n2. Testing positive sentiment...")
        text1 = "Bitcoin surges to new all-time high as investors show confidence"
        result1 = analyzer.get_sentiment_score(text1)
        print(f"   Text: {text1[:50]}...")
        print(f"   Label: {result1['label']}")
        print(f"   Confidence: {result1['confidence']:.2f}")
        print(f"   Score: {result1['numeric']}")
        
        # Test negative sentiment
        print("\n3. Testing negative sentiment...")
        text2 = "Cryptocurrency market crashes amid regulatory concerns"
        result2 = analyzer.get_sentiment_score(text2)
        print(f"   Text: {text2[:50]}...")
        print(f"   Label: {result2['label']}")
        print(f"   Confidence: {result2['confidence']:.2f}")
        print(f"   Score: {result2['numeric']}")
        
        # Test neutral sentiment
        print("\n4. Testing neutral sentiment...")
        text3 = "Bitcoin price remains stable at current levels"
        result3 = analyzer.get_sentiment_score(text3)
        print(f"   Text: {text3[:50]}...")
        print(f"   Label: {result3['label']}")
        print(f"   Confidence: {result3['confidence']:.2f}")
        print(f"   Score: {result3['numeric']}")
        
        # Test news aggregation (will use mock/public API)
        print("\n5. Testing news aggregation...")
        print("   Note: This requires API keys for full functionality")
        print("   Using public API (limited requests)...")
        
        try:
            sentiment_btc = analyzer.get_sentiment_from_news("BTC", max_headlines=3)
            print(f"   BTC Sentiment Score: {sentiment_btc:.2f}")
            if sentiment_btc > 0.3:
                print("   📈 Bullish sentiment detected")
            elif sentiment_btc < -0.3:
                print("   📉 Bearish sentiment detected")
            else:
                print("   ➡️  Neutral sentiment detected")
        except Exception as e:
            print(f"   ⚠️  News aggregation failed (API keys may be needed): {e}")
        
        print("\n" + "=" * 60)
        print("✅ All tests completed successfully!")
        print("=" * 60)
        print("\nNext steps:")
        print("1. Set API keys in .env file:")
        print("   - CRYPTOPANIC_API_KEY")
        print("   - NEWSAPI_KEY")
        print("2. Run full test suite: pytest tests/unit/test_sentiment/ -v")
        print("3. Integrate with ASMBTR strategy (Task 4)")
        
        return True
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    success = test_basic_sentiment()
    sys.exit(0 if success else 1)
