# Approve Signals Script
# Approve or reject signals from daily generation

param(
    [string]$Date = (Get-Date -Format "yyyyMMdd"),
    [string]$Symbol = "BTCUSDT",
    [string]$Category = "",
    [string]$Action = "interactive",  # approve, reject, interactive
    [string]$Reason = ""
)

# Configuration
$SIGNALS_DIR = "signals"
$APPROVED_DIR = Join-Path $SIGNALS_DIR "approved"
$REJECTED_DIR = Join-Path $SIGNALS_DIR "rejected"
$SUMMARY_FILE = Join-Path $SIGNALS_DIR "daily_signals_summary_${Date}.json"

# Create directories if they don't exist
if (-not (Test-Path $APPROVED_DIR)) {
    New-Item -ItemType Directory -Path $APPROVED_DIR | Out-Null
}

if (-not (Test-Path $REJECTED_DIR)) {
    New-Item -ItemType Directory -Path $REJECTED_DIR | Out-Null
}

function Save-ApprovedSignal {
    param([object]$Signal, [string]$Date)
    
    $filename = Join-Path $APPROVED_DIR "approved_${Date}.json"
    
    try {
        $approvedSignals = @()
        if (Test-Path $filename) {
            $approvedSignals = Get-Content $filename | ConvertFrom-Json
        }
        
        $signal | Add-Member -NotePropertyName "approved_at" -NotePropertyValue (Get-Date -Format "yyyy-MM-ddTHH:mm:ss") -Force
        $signal | Add-Member -NotePropertyName "status" -NotePropertyValue "approved" -Force
        
        $approvedSignals += $signal
        
        $approvedSignals | ConvertTo-Json -Depth 10 | Set-Content $filename
        
        Write-Host "Signal approved and saved to $filename" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "Error saving approved signal: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Save-RejectedSignal {
    param([object]$Signal, [string]$Date, [string]$Reason)
    
    $filename = Join-Path $REJECTED_DIR "rejected_${Date}.json"
    
    try {
        $rejectedSignals = @()
        if (Test-Path $filename) {
            $rejectedSignals = Get-Content $filename | ConvertFrom-Json
        }
        
        $signal | Add-Member -NotePropertyName "rejected_at" -NotePropertyValue (Get-Date -Format "yyyy-MM-ddTHH:mm:ss") -Force
        $signal | Add-Member -NotePropertyName "status" -NotePropertyValue "rejected" -Force
        $signal | Add-Member -NotePropertyName "rejection_reason" -NotePropertyValue $Reason -Force
        
        $rejectedSignals += $signal
        
        $rejectedSignals | ConvertTo-Json -Depth 10 | Set-Content $filename
        
        Write-Host "Signal rejected and saved to $filename" -ForegroundColor Yellow
        return $true
    } catch {
        Write-Host "Error saving rejected signal: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Format-SignalSummary {
    param([object]$Signal)
    
    $signalType = $Signal.signal_type
    $category = $Signal.category
    $strategy = $Signal.strategy
    $entryPrice = $Signal.entry_price
    $takeProfit = $Signal.take_profit
    $stopLoss = $Signal.stop_loss
    $confidence = $Signal.confidence
    $tpPct = (($takeProfit / $entryPrice - 1) * 100)
    $slPct = (($stopLoss / $entryPrice - 1) * 100)
    $riskReward = [math]::Abs($tpPct / $slPct)
    
    $summary = @"
[$category] $signalType - $strategy
  Entry: `$$($entryPrice.ToString('N2'))
  TP: `$$($takeProfit.ToString('N2')) ($($tpPct.ToString('F2'))%)
  SL: `$$($stopLoss.ToString('N2')) ($($slPct.ToString('F2'))%)
  Confidence: $($confidence * 100)%
  Risk/Reward: $($riskReward.ToString('F2')):1
"@
    
    return $summary
}

function Approve-Signals {
    param([string]$Date, [string]$Symbol, [string]$Category, [string]$Action, [string]$Reason)
    
    $summaryFile = Join-Path $SIGNALS_DIR "daily_signals_summary_${Date}.json"
    
    if (-not (Test-Path $summaryFile)) {
        Write-Host "Error: Summary file not found: $summaryFile" -ForegroundColor Red
        Write-Host "Generate signals first using: .\generate-daily-signals.ps1 -Symbol $Symbol" -ForegroundColor Yellow
        return
    }
    
    try {
        $summary = Get-Content $summaryFile | ConvertFrom-Json
        $signals = $summary.signals
        
        # Filter by category if specified
        if ($Category) {
            $signals = $signals | Where-Object { $_.category -eq $Category }
        }
        
        if ($signals.Count -eq 0) {
            Write-Host "No signals found for date $Date" -ForegroundColor Yellow
            return
        }
        
        Write-Host "`n$('='*60)" -ForegroundColor Cyan
        Write-Host "Signal Approval - $($summary.date)" -ForegroundColor Cyan
        Write-Host "$('='*60)`n" -ForegroundColor Cyan
        
        if ($Action -eq "interactive") {
            # Interactive mode
            foreach ($signal in $signals) {
                Write-Host (Format-SignalSummary -Signal $signal) -ForegroundColor White
                Write-Host "Rationale: $($signal.rationale)" -ForegroundColor Gray
                Write-Host ""
                
                $choice = Read-Host "Approve (a), Reject (r), or Skip (s)?"
                
                if ($choice -eq "a" -or $choice -eq "approve") {
                    $reason = Read-Host "Enter approval reason (optional)"
                    Save-ApprovedSignal -Signal $signal -Date $Date
                } elseif ($choice -eq "r" -or $choice -eq "reject") {
                    $reason = Read-Host "Enter rejection reason (required)"
                    if ($reason) {
                        Save-RejectedSignal -Signal $signal -Date $Date -Reason $reason
                    } else {
                        Write-Host "Rejection reason required. Signal skipped." -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "Signal skipped." -ForegroundColor Yellow
                }
                
                Write-Host ""
            }
        } elseif ($Action -eq "approve") {
            # Auto-approve all
            foreach ($signal in $signals) {
                Write-Host "Approving signal: $($signal.category) - $($signal.signal_type)" -ForegroundColor Green
                Save-ApprovedSignal -Signal $signal -Date $Date
            }
        } elseif ($Action -eq "reject") {
            # Auto-reject all
            $rejectReason = if ($Reason) { $Reason } else { "Manual rejection" }
            foreach ($signal in $signals) {
                Write-Host "Rejecting signal: $($signal.category) - $($signal.signal_type)" -ForegroundColor Yellow
                Save-RejectedSignal -Signal $signal -Date $Date -Reason $rejectReason
            }
        }
        
        # Summary
        $approvedFile = Join-Path $APPROVED_DIR "approved_${Date}.json"
        $rejectedFile = Join-Path $REJECTED_DIR "rejected_${Date}.json"
        
        $approvedCount = 0
        $rejectedCount = 0
        
        if (Test-Path $approvedFile) {
            $approvedSignals = Get-Content $approvedFile | ConvertFrom-Json
            # Handle single signal object (not array)
            if ($approvedSignals -isnot [Array]) {
                $approvedSignals = @($approvedSignals)
            }
            $approvedCount = $approvedSignals.Count
        }
        
        if (Test-Path $rejectedFile) {
            $rejectedSignals = Get-Content $rejectedFile | ConvertFrom-Json
            # Handle single signal object (not array)
            if ($rejectedSignals -isnot [Array]) {
                $rejectedSignals = @($rejectedSignals)
            }
            $rejectedCount = $rejectedSignals.Count
        }
        
        Write-Host "`n$('='*60)" -ForegroundColor Cyan
        Write-Host "Approval Summary" -ForegroundColor Cyan
        Write-Host "$('='*60)" -ForegroundColor Cyan
        Write-Host "Approved: $approvedCount" -ForegroundColor Green
        Write-Host "Rejected: $rejectedCount" -ForegroundColor Yellow
        Write-Host "Pending: $($signals.Count - $approvedCount - $rejectedCount)" -ForegroundColor White
        Write-Host "$('='*60)`n" -ForegroundColor Cyan
        
    } catch {
        Write-Host "Error approving signals: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Main execution
Approve-Signals -Date $Date -Symbol $Symbol -Category $Category -Action $Action -Reason $Reason

