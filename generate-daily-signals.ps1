# Daily Signal Generation Script (PowerShell)
# Automatically generate Bitcoin signals for daily manual trading workflow.

param(
    [string]$Symbol = "BTCUSDT",
    [string[]]$Categories = @("scalp", "swing", "long_term"),
    [switch]$UseAI = $false,
    [string]$OutputDir = "signals",
    [switch]$NoSave = $false,
    [switch]$SummaryOnly = $false
)

# Configuration
$APP_SERVICE_URL = "http://localhost:8002"
$TIMESTAMP = Get-Date -Format "yyyyMMdd"
$TIMESTAMP_ISO = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"

# Output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

# Strategy mapping
$Strategies = @{
    "scalp" = "ema_scalp"
    "swing" = "rsi"
    "long_term" = "macd"
}

function Generate-Signal {
    param(
        [string]$Symbol,
        [string]$Category,
        [string]$Strategy,
        [bool]$UseAI
    )
    
    try {
        $params = @{
            category = $Category
            use_ai = $UseAI.ToString().ToLower()
        }
        
        if ($Strategy) {
            $params.strategy = $Strategy
        }
        
        $url = "$APP_SERVICE_URL/api/v1/signals/latest/$Symbol"
        $queryString = ($params.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "&"
        $fullUrl = "$url`?$queryString"
        
        $response = Invoke-RestMethod -Uri $fullUrl -Method Get -TimeoutSec 30
        
        return $response
    }
    catch {
        Write-Host "Error: Failed to generate signal for $Category - $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Format-SignalSummary {
    param([object]$Signal)
    
    $symbol = $Signal.symbol
    $signalType = $Signal.signal_type
    $entryPrice = $Signal.entry_price
    $takeProfit = $Signal.take_profit
    $stopLoss = $Signal.stop_loss
    $confidence = $Signal.confidence
    $rationale = $Signal.rationale
    $category = $Signal.category
    $strategy = $Signal.strategy
    
    $tpPct = (($takeProfit / $entryPrice - 1) * 100)
    $slPct = (($stopLoss / $entryPrice - 1) * 100)
    
    $summary = @"
Signal: $signalType
Symbol: $symbol
Category: $category
Strategy: $strategy
Entry: `$$($entryPrice.ToString('N2'))
Take Profit: `$$($takeProfit.ToString('N2')) ($($tpPct.ToString('F2'))%)
Stop Loss: `$$($stopLoss.ToString('N2')) ($($slPct.ToString('F2'))%)
Confidence: $($confidence * 100)%
Rationale: $rationale
"@
    
    return $summary
}

function Save-Signal {
    param(
        [object]$Signal,
        [string]$Filename
    )
    
    $filepath = Join-Path $OutputDir $Filename
    
    try {
        # Load existing signals
        $signals = @()
        if (Test-Path $filepath) {
            $signals = Get-Content $filepath | ConvertFrom-Json
        }
        
        # Add timestamp
        $Signal | Add-Member -NotePropertyName "generated_at" -NotePropertyValue $TIMESTAMP_ISO -Force
        
        # Add new signal
        $signals += $Signal
        
        # Save to file
        $signals | ConvertTo-Json -Depth 10 | Set-Content $filepath
        
        Write-Host "Signal saved to $filepath" -ForegroundColor Green
    }
    catch {
        Write-Host "Error saving signal: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Main execution
Write-Host "`n$('='*60)" -ForegroundColor Cyan
Write-Host "Daily Signal Generation - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "$('='*60)`n" -ForegroundColor Cyan

$allSignals = @()

foreach ($category in $Categories) {
    $strategy = $Strategies[$category]
    
    Write-Host "Generating $category signal..." -ForegroundColor Yellow
    Write-Host "Strategy: $strategy" -ForegroundColor Yellow
    
    $signal = Generate-Signal -Symbol $Symbol -Category $category -Strategy $strategy -UseAI $UseAI
    
    if ($signal) {
        # Add category and strategy info
        $signal | Add-Member -NotePropertyName "category" -NotePropertyValue $category -Force
        $signal | Add-Member -NotePropertyName "strategy" -NotePropertyValue $strategy -Force
        
        # Print summary
        Write-Host (Format-SignalSummary -Signal $signal) -ForegroundColor White
        
        # Save to file
        if (-not $NoSave -and -not $SummaryOnly) {
            $filename = "signals_${category}_${TIMESTAMP}.json"
            Save-Signal -Signal $signal -Filename $filename
        }
        
        $allSignals += $signal
    }
    else {
        Write-Host "Failed to generate $category signal`n" -ForegroundColor Red
    }
}

# Generate summary file
if (-not $NoSave -and -not $SummaryOnly -and $allSignals.Count -gt 0) {
    $summaryFile = Join-Path $OutputDir "daily_signals_summary_${TIMESTAMP}.json"
    $summary = @{
        date = Get-Date -Format "yyyy-MM-dd"
        timestamp = $TIMESTAMP_ISO
        symbol = $Symbol
        signals = $allSignals
        total = $allSignals.Count
        by_category = @{}
    }
    
    foreach ($category in $Categories) {
        $summary.by_category[$category] = $allSignals | Where-Object { $_.category -eq $category }
    }
    
    $summary | ConvertTo-Json -Depth 10 | Set-Content $summaryFile
    Write-Host "`nSummary saved to $summaryFile" -ForegroundColor Green
}

# Print daily summary
if ($allSignals.Count -gt 0) {
    Write-Host "`n$('='*60)" -ForegroundColor Cyan
    Write-Host "Daily Signal Summary" -ForegroundColor Cyan
    Write-Host "$('='*60)`n" -ForegroundColor Cyan
    
    $buyCount = ($allSignals | Where-Object { $_.signal_type -eq "BUY" }).Count
    $sellCount = ($allSignals | Where-Object { $_.signal_type -eq "SELL" }).Count
    $holdCount = ($allSignals | Where-Object { $_.signal_type -eq "HOLD" }).Count
    $avgConfidence = ($allSignals | Measure-Object -Property confidence -Average).Average * 100
    
    Write-Host "Total Signals: $($allSignals.Count)" -ForegroundColor White
    Write-Host "Buy Signals: $buyCount" -ForegroundColor Green
    Write-Host "Sell Signals: $sellCount" -ForegroundColor Red
    Write-Host "Hold Signals: $holdCount" -ForegroundColor Yellow
    Write-Host "Average Confidence: $($avgConfidence.ToString('F1'))%" -ForegroundColor White
    Write-Host "`nBy Category:" -ForegroundColor White
    
    foreach ($category in $Categories) {
        $categorySignals = $allSignals | Where-Object { $_.category -eq $category }
        $categoryBuy = ($categorySignals | Where-Object { $_.signal_type -eq "BUY" }).Count
        $categorySell = ($categorySignals | Where-Object { $_.signal_type -eq "SELL" }).Count
        $categoryHold = ($categorySignals | Where-Object { $_.signal_type -eq "HOLD" }).Count
        
        Write-Host "  $category :" -ForegroundColor Cyan
        Write-Host "    Buy: $categoryBuy" -ForegroundColor Green
        Write-Host "    Sell: $categorySell" -ForegroundColor Red
        Write-Host "    Hold: $categoryHold" -ForegroundColor Yellow
    }
    
    Write-Host "`n$('='*60)`n" -ForegroundColor Cyan
}
else {
    Write-Host "No signals generated" -ForegroundColor Red
    exit 1
}

exit 0

