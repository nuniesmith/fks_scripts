#!/usr/bin/env python3
"""
Daily AI Screening Job

Runs the full AI screening pipeline on the watchlist and sends results to Discord.

Usage:
    python daily_screening.py [--symbols AAPL,GOOGL,MSFT] [--top-n 10]
    
Schedule via cron:
    0 8 * * * /path/to/venv/bin/python /path/to/daily_screening.py >> /var/log/fks/screening.log 2>&1
    
Or via systemd timer:
    [Timer]
    OnCalendar=*-*-* 08:00:00
    Persistent=true
"""

import asyncio
import argparse
import json
import logging
import os
import sys
from datetime import datetime, timezone
from typing import List, Optional

# Add project paths
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../services/ai/src"))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../services/portfolio/src"))

import httpx

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("/var/log/fks/daily_screening.log", mode="a"),
    ] if os.path.exists("/var/log/fks") else [logging.StreamHandler()],
)
logger = logging.getLogger("daily_screening")


# Default watchlist if fks_app is unavailable
DEFAULT_WATCHLIST = [
    # US Large Cap
    "AAPL", "MSFT", "GOOGL", "AMZN", "META", "NVDA", "TSLA",
    # US Value
    "BRK-B", "JPM", "JNJ", "PG", "KO", "XOM", "CVX",
    # US Growth
    "CRM", "ADBE", "NFLX", "AMD", "PYPL",
    # International (if supported)
    # "2317.HK", "005930.KS", "ASML",
]


async def fetch_watchlist(fks_app_url: str) -> List[str]:
    """Fetch enabled symbols from fks_app."""
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(f"{fks_app_url}/api/assets/enabled")
            if response.status_code == 200:
                data = response.json()
                symbols = [asset["symbol"] for asset in data.get("assets", [])]
                logger.info(f"Fetched {len(symbols)} symbols from watchlist")
                return symbols
            else:
                logger.warning(f"Failed to fetch watchlist: {response.status_code}")
    except Exception as e:
        logger.error(f"Error fetching watchlist: {e}")
    
    return DEFAULT_WATCHLIST


async def run_batch_screening(
    fks_ai_url: str,
    symbols: List[str],
    top_n: int = 10,
) -> Optional[dict]:
    """Run batch screening via fks_ai API."""
    try:
        async with httpx.AsyncClient(timeout=300.0) as client:  # 5 min timeout
            response = await client.post(
                f"{fks_ai_url}/ai/batch/screen",
                json={
                    "symbols": symbols,
                    "max_concurrent": 10,
                    "top_n_results": top_n,
                    "include_failures": False,
                }
            )
            if response.status_code == 200:
                return response.json()
            else:
                logger.error(f"Screening failed: {response.status_code} - {response.text}")
    except Exception as e:
        logger.error(f"Error running screening: {e}")
    
    return None


async def send_discord_notification(
    webhook_url: str,
    result: dict,
    mention_role: Optional[str] = None,
) -> bool:
    """Send results to Discord webhook."""
    try:
        # Import notifier
        from services.discord_notifier import DiscordNotifier
        
        notifier = DiscordNotifier(webhook_url=webhook_url)
        
        success = await notifier.send_daily_opportunities(
            opportunities=result.get("top_opportunities", []),
            summary=result.get("summary", {}),
            mention_role=mention_role,
        )
        
        await notifier.close()
        return success
        
    except ImportError:
        # Fallback: direct webhook post
        return await send_discord_direct(webhook_url, result, mention_role)


async def send_discord_direct(
    webhook_url: str,
    result: dict,
    mention_role: Optional[str] = None,
) -> bool:
    """Fallback: send directly to Discord webhook."""
    date_str = datetime.now(timezone.utc).strftime("%B %d, %Y")
    summary = result.get("summary", {})
    
    # Build message
    lines = [
        f"🚨 **DAILY OPPORTUNITIES** - {date_str}",
        "",
        f"Screened: {summary.get('total_screened', 0)} | "
        f"Passed: {summary.get('passed_thesis', 0)} | "
        f"Failed: {summary.get('failed_thesis', 0)} | "
        f"Poor Data: {summary.get('poor_data_quality', 0)}",
        "",
    ]
    
    if mention_role:
        lines.insert(0, f"<@&{mention_role}>")
        lines.insert(1, "")
    
    for opp in result.get("top_opportunities", [])[:5]:
        conviction = opp.get("conviction_score", 0)
        stars = "⭐" * min(5, int(conviction / 20) + 1)
        
        lines.extend([
            f"**{opp.get('rank', '?')}. {opp.get('symbol', 'N/A')}** - {conviction:.0f}/100 {stars}",
            f"   Health: {opp.get('health_score', 0):.0f}% | "
            f"Growth: {opp.get('growth_score', 0):.0f}% | "
            f"Liquidity: ${opp.get('daily_liquidity', 0)/1e6:.1f}M",
            f"   Position: {opp.get('position_sizing', {}).get('balanced_pct', 0):.1f}% (Balanced)",
            "",
        ])
    
    if not result.get("top_opportunities"):
        lines.append("_No opportunities meeting all criteria today._")
    
    message = "\n".join(lines)
    
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                webhook_url,
                json={
                    "content": message,
                    "username": "FKS Trading Bot",
                }
            )
            return response.status_code in (200, 204)
    except Exception as e:
        logger.error(f"Failed to send Discord notification: {e}")
        return False


async def save_results(result: dict, output_dir: str):
    """Save results to JSON file."""
    date_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    filename = os.path.join(output_dir, f"screening_{date_str}.json")
    
    os.makedirs(output_dir, exist_ok=True)
    
    with open(filename, "w") as f:
        json.dump(result, f, indent=2)
    
    logger.info(f"Results saved to {filename}")


async def main():
    parser = argparse.ArgumentParser(description="Daily AI Screening Job")
    parser.add_argument(
        "--symbols",
        type=str,
        help="Comma-separated list of symbols (overrides watchlist)",
    )
    parser.add_argument(
        "--top-n",
        type=int,
        default=10,
        help="Number of top opportunities to return",
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default="/var/log/fks/screening",
        help="Directory to save results JSON",
    )
    parser.add_argument(
        "--no-discord",
        action="store_true",
        help="Skip Discord notification",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be done without actually doing it",
    )
    
    args = parser.parse_args()
    
    # Configuration from environment
    fks_app_url = os.environ.get("FKS_APP_URL", "http://localhost:8001")
    fks_ai_url = os.environ.get("FKS_AI_URL", "http://localhost:8002")
    discord_webhook_url = os.environ.get("DISCORD_WEBHOOK_URL")
    discord_mention_role = os.environ.get("DISCORD_MENTION_ROLE")
    
    logger.info("=" * 60)
    logger.info("Daily AI Screening Job Started")
    logger.info(f"Time: {datetime.now(timezone.utc).isoformat()}")
    logger.info("=" * 60)
    
    # Get symbols
    if args.symbols:
        symbols = [s.strip() for s in args.symbols.split(",")]
        logger.info(f"Using provided symbols: {symbols}")
    else:
        symbols = await fetch_watchlist(fks_app_url)
        logger.info(f"Using watchlist: {len(symbols)} symbols")
    
    if args.dry_run:
        logger.info("[DRY RUN] Would screen symbols: %s", symbols[:10])
        logger.info("[DRY RUN] Discord: %s", "enabled" if discord_webhook_url else "disabled")
        return
    
    # Run screening
    logger.info(f"Starting screening of {len(symbols)} symbols...")
    result = await run_batch_screening(fks_ai_url, symbols, args.top_n)
    
    if not result:
        logger.error("Screening failed - no results")
        sys.exit(1)
    
    # Log summary
    summary = result.get("summary", {})
    logger.info(f"Screening complete:")
    logger.info(f"  Total screened: {summary.get('total_screened', 0)}")
    logger.info(f"  Passed thesis: {summary.get('passed_thesis', 0)}")
    logger.info(f"  Failed thesis: {summary.get('failed_thesis', 0)}")
    logger.info(f"  Poor data: {summary.get('poor_data_quality', 0)}")
    logger.info(f"  Duration: {summary.get('duration_secs', 0):.1f}s")
    
    # Save results
    await save_results(result, args.output_dir)
    
    # Send Discord notification
    if not args.no_discord and discord_webhook_url:
        logger.info("Sending Discord notification...")
        success = await send_discord_notification(
            discord_webhook_url,
            result,
            discord_mention_role,
        )
        if success:
            logger.info("Discord notification sent successfully")
        else:
            logger.warning("Discord notification failed")
    elif not discord_webhook_url:
        logger.info("Discord webhook not configured - skipping notification")
    
    # Print top opportunities
    logger.info("\nTop Opportunities:")
    for opp in result.get("top_opportunities", [])[:5]:
        logger.info(
            f"  {opp.get('rank')}. {opp.get('symbol')}: "
            f"Conviction {opp.get('conviction_score', 0):.0f}, "
            f"Health {opp.get('health_score', 0):.0f}%, "
            f"Growth {opp.get('growth_score', 0):.0f}%"
        )
    
    logger.info("\nDaily screening job complete!")


if __name__ == "__main__":
    asyncio.run(main())
