# Track Performance Script
# Track and analyze signal performance

param(
    [string]$Date = (Get-Date -Format "yyyyMMdd"),
    [string]$Symbol = "BTCUSDT",
    [switch]$Summary = $false,
    [switch]$Detailed = $false
)

# Configuration
$SIGNALS_DIR = "signals"
$APPROVED_DIR = Join-Path $SIGNALS_DIR "approved"
$REJECTED_DIR = Join-Path $SIGNALS_DIR "rejected"
$PERFORMANCE_DIR = Join-Path $SIGNALS_DIR "performance"

# Create performance directory if it doesn't exist
if (-not (Test-Path $PERFORMANCE_DIR)) {
    New-Item -ItemType Directory -Path $PERFORMANCE_DIR | Out-Null
}

function Get-PerformanceMetrics {
    param([string]$Date, [string]$Symbol)
    
    $approvedFile = Join-Path $APPROVED_DIR "approved_${Date}.json"
    $rejectedFile = Join-Path $REJECTED_DIR "rejected_${Date}.json"
    $summaryFile = Join-Path $SIGNALS_DIR "daily_signals_summary_${Date}.json"
    
    $metrics = @{
        date = $Date
        symbol = $Symbol
        total_signals = 0
        approved_signals = 0
        rejected_signals = 0
        pending_signals = 0
        buy_signals = 0
        sell_signals = 0
        hold_signals = 0
        avg_confidence = 0
        by_category = @{}
        by_strategy = @{}
    }
    
    # Get total signals
    if (Test-Path $summaryFile) {
        $summary = Get-Content $summaryFile | ConvertFrom-Json
        $metrics.total_signals = $summary.total
        $metrics.buy_signals = ($summary.signals | Where-Object { $_.signal_type -eq "BUY" }).Count
        $metrics.sell_signals = ($summary.signals | Where-Object { $_.signal_type -eq "SELL" }).Count
        $metrics.hold_signals = ($summary.signals | Where-Object { $_.signal_type -eq "HOLD" }).Count
        $metrics.avg_confidence = ($summary.signals | Measure-Object -Property confidence -Average).Average * 100
    }
    
    # Get approved signals
    if (Test-Path $approvedFile) {
        $approvedSignals = Get-Content $approvedFile | ConvertFrom-Json
        # Handle single signal object (not array)
        if ($approvedSignals -isnot [Array]) {
            $approvedSignals = @($approvedSignals)
        }
        $metrics.approved_signals = $approvedSignals.Count
    }
    
    # Get rejected signals
    if (Test-Path $rejectedFile) {
        $rejectedSignals = Get-Content $rejectedFile | ConvertFrom-Json
        # Handle single signal object (not array)
        if ($rejectedSignals -isnot [Array]) {
            $rejectedSignals = @($rejectedSignals)
        }
        $metrics.rejected_signals = $rejectedSignals.Count
    }
    
    $metrics.pending_signals = $metrics.total_signals - $metrics.approved_signals - $metrics.rejected_signals
    
    # Category breakdown
    if (Test-Path $summaryFile) {
        $summary = Get-Content $summaryFile | ConvertFrom-Json
        $categories = @("scalp", "swing", "long_term")
        
        foreach ($category in $categories) {
            $categorySignals = $summary.by_category.$category
            
            # Handle single signal object (not array)
            if ($categorySignals) {
                if ($categorySignals -isnot [Array]) {
                    $categorySignals = @($categorySignals)
                }
                
                if ($categorySignals.Count -gt 0) {
                $categoryMetrics = @{
                    total = $categorySignals.Count
                    buy = ($categorySignals | Where-Object { $_.signal_type -eq "BUY" }).Count
                    sell = ($categorySignals | Where-Object { $_.signal_type -eq "SELL" }).Count
                    hold = ($categorySignals | Where-Object { $_.signal_type -eq "HOLD" }).Count
                    avg_confidence = ($categorySignals | Measure-Object -Property confidence -Average).Average * 100
                }
                
                # Get approved/rejected for this category
                if (Test-Path $approvedFile) {
                    $approvedSignals = Get-Content $approvedFile | ConvertFrom-Json
                    # Handle single signal object (not array)
                    if ($approvedSignals -isnot [Array]) {
                        $approvedSignals = @($approvedSignals)
                    }
                    $categoryMetrics.approved = ($approvedSignals | Where-Object { $_.category -eq $category }).Count
                } else {
                    $categoryMetrics.approved = 0
                }
                
                if (Test-Path $rejectedFile) {
                    $rejectedSignals = Get-Content $rejectedFile | ConvertFrom-Json
                    # Handle single signal object (not array)
                    if ($rejectedSignals -isnot [Array]) {
                        $rejectedSignals = @($rejectedSignals)
                    }
                    $categoryMetrics.rejected = ($rejectedSignals | Where-Object { $_.category -eq $category }).Count
                } else {
                    $categoryMetrics.rejected = 0
                }
                
                $categoryMetrics.pending = $categoryMetrics.total - $categoryMetrics.approved - $categoryMetrics.rejected
                
                $metrics.by_category[$category] = $categoryMetrics
                }
            }
        }
        
        # Strategy breakdown
        $strategies = $summary.signals | Select-Object -ExpandProperty strategy -Unique | Where-Object { $_ -ne $null }
        
        foreach ($strategy in $strategies) {
            $strategySignals = $summary.signals | Where-Object { $_.strategy -eq $strategy }
            if ($strategySignals) {
                $strategyMetrics = @{
                    total = $strategySignals.Count
                    avg_confidence = ($strategySignals | Measure-Object -Property confidence -Average).Average * 100
                }
                
                $metrics.by_strategy[$strategy] = $strategyMetrics
            }
        }
    }
    
    return $metrics
}

function Save-PerformanceMetrics {
    param([object]$Metrics, [string]$Date)
    
    $filename = Join-Path $PERFORMANCE_DIR "performance_${Date}.json"
    
    try {
        $metrics | ConvertTo-Json -Depth 10 | Set-Content $filename
        Write-Host "Performance metrics saved to $filename" -ForegroundColor Green
    } catch {
        Write-Host "Error saving performance metrics: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Display-PerformanceMetrics {
    param([object]$Metrics, [switch]$Detailed)
    
    Write-Host "`n$('='*60)" -ForegroundColor Cyan
    Write-Host "Performance Metrics - $($Metrics.date)" -ForegroundColor Cyan
    Write-Host "$('='*60)`n" -ForegroundColor Cyan
    
    Write-Host "Symbol: $($Metrics.symbol)" -ForegroundColor White
    Write-Host "Date: $($Metrics.date)" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Signal Summary:" -ForegroundColor Yellow
    Write-Host "  Total Signals: $($Metrics.total_signals)" -ForegroundColor White
    Write-Host "  Approved: $($Metrics.approved_signals)" -ForegroundColor Green
    Write-Host "  Rejected: $($Metrics.rejected_signals)" -ForegroundColor Red
    Write-Host "  Pending: $($Metrics.pending_signals)" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "Signal Types:" -ForegroundColor Yellow
    Write-Host "  Buy: $($Metrics.buy_signals)" -ForegroundColor Green
    Write-Host "  Sell: $($Metrics.sell_signals)" -ForegroundColor Red
    Write-Host "  Hold: $($Metrics.hold_signals)" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "Average Confidence: $($Metrics.avg_confidence.ToString('F1'))%" -ForegroundColor White
    Write-Host ""
    
    if ($Metrics.by_category.Count -gt 0) {
        Write-Host "By Category:" -ForegroundColor Yellow
        foreach ($category in $Metrics.by_category.Keys) {
            $categoryMetrics = $Metrics.by_category[$category]
            Write-Host "  $category :" -ForegroundColor Cyan
            Write-Host "    Total: $($categoryMetrics.total) | Approved: $($categoryMetrics.approved) | Rejected: $($categoryMetrics.rejected) | Pending: $($categoryMetrics.pending)" -ForegroundColor White
            Write-Host "    Buy: $($categoryMetrics.buy) | Sell: $($categoryMetrics.sell) | Hold: $($categoryMetrics.hold)" -ForegroundColor White
            Write-Host "    Avg Confidence: $($categoryMetrics.avg_confidence.ToString('F1'))%" -ForegroundColor White
        }
        Write-Host ""
    }
    
    if ($Metrics.by_strategy.Count -gt 0) {
        Write-Host "By Strategy:" -ForegroundColor Yellow
        foreach ($strategy in $Metrics.by_strategy.Keys) {
            $strategyMetrics = $Metrics.by_strategy[$strategy]
            Write-Host "  $strategy :" -ForegroundColor Cyan
            Write-Host "    Total: $($strategyMetrics.total) | Avg Confidence: $($strategyMetrics.avg_confidence.ToString('F1'))%" -ForegroundColor White
        }
        Write-Host ""
    }
    
    # Approval rate
    if ($Metrics.total_signals -gt 0) {
        $approvalRate = ($Metrics.approved_signals / $Metrics.total_signals) * 100
        $rejectionRate = ($Metrics.rejected_signals / $Metrics.total_signals) * 100
        
        Write-Host "Approval Rate: $($approvalRate.ToString('F1'))%" -ForegroundColor Green
        Write-Host "Rejection Rate: $($rejectionRate.ToString('F1'))%" -ForegroundColor Red
        Write-Host ""
    }
    
    Write-Host "$('='*60)`n" -ForegroundColor Cyan
}

# Main execution
$metrics = Get-PerformanceMetrics -Date $Date -Symbol $Symbol

if ($Summary) {
    Display-PerformanceMetrics -Metrics $metrics -Detailed:$Detailed
} else {
    Display-PerformanceMetrics -Metrics $metrics -Detailed:$Detailed
    Save-PerformanceMetrics -Metrics $metrics -Date $Date
}

