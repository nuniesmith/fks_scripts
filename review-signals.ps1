# Review Signals Script
# Review and analyze signals from all categories

param(
    [string]$Date = (Get-Date -Format "yyyyMMdd"),
    [string]$Symbol = "BTCUSDT",
    [switch]$Detailed = $false,
    [switch]$Compare = $false
)

# Configuration
$SIGNALS_DIR = "signals"
$SUMMARY_FILE = Join-Path $SIGNALS_DIR "daily_signals_summary_${Date}.json"

# Colors
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Format-Signal {
    param([object]$Signal)
    
    $signalType = $Signal.signal_type
    $category = $Signal.category
    $strategy = $Signal.strategy
    $entryPrice = $Signal.entry_price
    $takeProfit = $Signal.take_profit
    $stopLoss = $Signal.stop_loss
    $confidence = $Signal.confidence
    $rationale = $Signal.rationale
    $tpPct = (($takeProfit / $entryPrice - 1) * 100)
    $slPct = (($stopLoss / $entryPrice - 1) * 100)
    $riskReward = [math]::Abs($tpPct / $slPct)
    
    # Color code signal type
    $signalColor = if ($signalType -eq "BUY") { "Green" } elseif ($signalType -eq "SELL") { "Red" } else { "Yellow" }
    
    Write-ColorOutput $signalColor "`n============================================================"
    Write-ColorOutput $signalColor "Signal: $signalType | Category: $category | Strategy: $strategy"
    Write-ColorOutput $signalColor "============================================================"
    
    Write-Host "Symbol: $($Signal.symbol)" -ForegroundColor White
    Write-Host "Entry Price: `$$($entryPrice.ToString('N2'))" -ForegroundColor White
    Write-Host "Take Profit: `$$($takeProfit.ToString('N2')) ($($tpPct.ToString('F2'))%)" -ForegroundColor Green
    Write-Host "Stop Loss: `$$($stopLoss.ToString('N2')) ($($slPct.ToString('F2'))%)" -ForegroundColor Red
    Write-Host "Confidence: $($confidence * 100)%" -ForegroundColor $(if ($confidence -gt 0.6) { "Green" } elseif ($confidence -gt 0.5) { "Yellow" } else { "Red" })
    Write-Host "Risk/Reward: $($riskReward.ToString('F2')):1" -ForegroundColor White
    Write-Host "Rationale: $rationale" -ForegroundColor White
    
    if ($Detailed) {
        Write-Host "`nDetailed Information:" -ForegroundColor Cyan
        Write-Host "  Position Size: $($Signal.position_size_pct)%" -ForegroundColor White
        Write-Host "  Position Size: `$$($Signal.position_size_usd.ToString('N2')) USD" -ForegroundColor White
        Write-Host "  Position Size: $($Signal.position_size_units.ToString('F6')) units" -ForegroundColor White
        Write-Host "  Risk Amount: `$$($Signal.risk_amount.ToString('N2'))" -ForegroundColor White
        Write-Host "  Risk %: $($Signal.risk_pct)%" -ForegroundColor White
        
        if ($Signal.indicators) {
            Write-Host "`nIndicators:" -ForegroundColor Cyan
            $Signal.indicators.PSObject.Properties | ForEach-Object {
                Write-Host "  $($_.Name): $($_.Value.ToString('F2'))" -ForegroundColor White
            }
        }
        
        Write-Host "  Timestamp: $($Signal.timestamp)" -ForegroundColor White
        Write-Host "  AI Enhanced: $($Signal.ai_enhanced)" -ForegroundColor White
    }
}

function Review-Signals {
    param([string]$Date, [string]$Symbol)
    
    $summaryFile = Join-Path $SIGNALS_DIR "daily_signals_summary_${Date}.json"
    
    if (-not (Test-Path $summaryFile)) {
        Write-Host "Error: Summary file not found: $summaryFile" -ForegroundColor Red
        Write-Host "Generate signals first using: .\generate-daily-signals.ps1 -Symbol $Symbol" -ForegroundColor Yellow
        return
    }
    
    try {
        $summary = Get-Content $summaryFile | ConvertFrom-Json
        
        Write-Host "`n$('='*60)" -ForegroundColor Cyan
        Write-Host "Signal Review - $($summary.date)" -ForegroundColor Cyan
        Write-Host "$('='*60)`n" -ForegroundColor Cyan
        
        Write-Host "Symbol: $($summary.symbol)" -ForegroundColor White
        Write-Host "Total Signals: $($summary.total)" -ForegroundColor White
        Write-Host "Timestamp: $($summary.timestamp)" -ForegroundColor White
        Write-Host ""
        
        # Review signals by category
        $categories = @("scalp", "swing", "long_term")
        
        foreach ($category in $categories) {
            $categorySignals = $summary.by_category.$category
            
            if ($categorySignals -and $categorySignals.Count -gt 0) {
                Write-Host "`n$('='*60)" -ForegroundColor Yellow
                Write-Host "Category: $category" -ForegroundColor Yellow
                Write-Host "$('='*60)" -ForegroundColor Yellow
                
                foreach ($signal in $categorySignals) {
                    Format-Signal -Signal $signal -Detailed:$Detailed
                }
            }
        }
        
        # Summary statistics
        Write-Host "`n$('='*60)" -ForegroundColor Cyan
        Write-Host "Summary Statistics" -ForegroundColor Cyan
        Write-Host "$('='*60)" -ForegroundColor Cyan
        
        $buyCount = ($summary.signals | Where-Object { $_.signal_type -eq "BUY" }).Count
        $sellCount = ($summary.signals | Where-Object { $_.signal_type -eq "SELL" }).Count
        $holdCount = ($summary.signals | Where-Object { $_.signal_type -eq "HOLD" }).Count
        $avgConfidence = ($summary.signals | Measure-Object -Property confidence -Average).Average * 100
        
        Write-Host "Total Signals: $($summary.total)" -ForegroundColor White
        Write-Host "Buy Signals: $buyCount" -ForegroundColor Green
        Write-Host "Sell Signals: $sellCount" -ForegroundColor Red
        Write-Host "Hold Signals: $holdCount" -ForegroundColor Yellow
        Write-Host "Average Confidence: $($avgConfidence.ToString('F1'))%" -ForegroundColor White
        
        # Category breakdown
        Write-Host "`nBy Category:" -ForegroundColor Cyan
        foreach ($category in $categories) {
            $categorySignals = $summary.by_category.$category
            
            # Handle single signal object (not array)
            if ($categorySignals) {
                if ($categorySignals -isnot [Array]) {
                    $categorySignals = @($categorySignals)
                }
                
                if ($categorySignals.Count -gt 0) {
                    $categoryBuy = ($categorySignals | Where-Object { $_.signal_type -eq "BUY" }).Count
                    $categorySell = ($categorySignals | Where-Object { $_.signal_type -eq "SELL" }).Count
                    $categoryHold = ($categorySignals | Where-Object { $_.signal_type -eq "HOLD" }).Count
                    $categoryConfidence = ($categorySignals | Measure-Object -Property confidence -Average).Average * 100
                    
                    Write-Host "  $category :" -ForegroundColor Yellow
                    Write-Host "    Buy: $categoryBuy | Sell: $categorySell | Hold: $categoryHold" -ForegroundColor White
                    Write-Host "    Average Confidence: $($categoryConfidence.ToString('F1'))%" -ForegroundColor White
                }
            }
        }
        
        # Comparison
        if ($Compare) {
            Write-Host "`n$('='*60)" -ForegroundColor Cyan
            Write-Host "Strategy Comparison" -ForegroundColor Cyan
            Write-Host "$('='*60)" -ForegroundColor Cyan
            
            $strategies = $summary.signals | Select-Object -ExpandProperty strategy -Unique
            
            foreach ($strategy in $strategies) {
                $strategySignals = $summary.signals | Where-Object { $_.strategy -eq $strategy }
                $strategyConfidence = ($strategySignals | Measure-Object -Property confidence -Average).Average * 100
                $strategyCount = $strategySignals.Count
                
                Write-Host "  $strategy :" -ForegroundColor Yellow
                Write-Host "    Signals: $strategyCount" -ForegroundColor White
                Write-Host "    Average Confidence: $($strategyConfidence.ToString('F1'))%" -ForegroundColor White
            }
        }
        
        Write-Host "`n$('='*60)`n" -ForegroundColor Cyan
        
    } catch {
        Write-Host "Error reviewing signals: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Main execution
Review-Signals -Date $Date -Symbol $Symbol

