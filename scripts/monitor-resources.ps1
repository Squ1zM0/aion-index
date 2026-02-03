#!/usr/bin/env pwsh
# Real-time resource monitoring for Ollama/AIOS

param(
    [int]$IntervalSeconds = 5,
    [switch]$LogToFile
)

$logFile = if ($LogToFile) { "resource_monitor_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" } else { $null }

if ($logFile) {
    "Timestamp,RAM_Used_MB,RAM_Total_MB,RAM_Percent,Ollama_RAM_MB,GPU_Used_MB,GPU_Total_MB,GPU_Util_Percent,CPU_Util_Percent" | Out-File -FilePath $logFile
}

Write-Host "=== AIOS Resource Monitor ===" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop" -ForegroundColor Gray
Write-Host ""
Write-Host "Legend: RAM% | Ollama(MB) | GPU(Used/Total MB) | GPU% | CPU%" -ForegroundColor Gray
Write-Host "---" -ForegroundColor Gray

try {
    while ($true) {
        $timestamp = Get-Date -Format 'HH:mm:ss'
        
        # RAM stats
        $ram = Get-CimInstance -ClassName Win32_OperatingSystem
        $usedRamMB = [math]::Round(($ram.TotalVisibleMemorySize - $ram.FreePhysicalMemory) / 1KB, 1)
        $totalRamMB = [math]::Round($ram.TotalVisibleMemorySize / 1KB, 1)
        $ramPercent = [math]::Round(($usedRamMB / $totalRamMB) * 100, 1)
        
        # Ollama RAM usage
        $ollamaProcs = Get-Process -Name "ollama" -ErrorAction SilentlyContinue
        $ollamaRamMB = 0
        if ($ollamaProcs) {
            $ollamaRamMB = [math]::Round(($ollamaProcs | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB, 1)
        }
        
        # GPU stats (requires nvidia-smi)
        $gpuUsedMB = "N/A"
        $gpuTotalMB = "N/A"
        $gpuUtil = "N/A"
        
        try {
            $nvidiaSmi = & nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits 2>$null
            if ($nvidiaSmi) {
                $parts = $nvidiaSmi.Split(',').Trim()
                $gpuUsedMB = [int]$parts[0]
                $gpuTotalMB = [int]$parts[1]
                $gpuUtil = $parts[2]
            }
        } catch {}
        
        # CPU utilization (quick sample)
        $cpuUtil = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples[0].CookedValue
        $cpuUtil = [math]::Round($cpuUtil, 1)
        
        # Color-code output based on thresholds
        $ramColor = if ($ramPercent -lt 70) { 'Green' } elseif ($ramPercent -lt 85) { 'Yellow' } else { 'Red' }
        $ollamaColor = if ($ollamaRamMB -lt 4096) { 'Gray' } elseif ($ollamaRamMB -lt 8192) { 'Yellow' } else { 'Red' }
        
        $gpuUsedStr = if ($gpuUsedMB -ne "N/A") { "$gpuUsedMB" } else { "N/A" }
        $gpuTotalStr = if ($gpuTotalMB -ne "N/A") { "$gpuTotalMB" } else { "N/A" }
        $gpuUtilStr = if ($gpuUtil -ne "N/A") { $gpuUtil } else { "N/A" }
        
        # Output
        Write-Host "[$timestamp] " -ForegroundColor DarkGray -NoNewline
        Write-Host "RAM: %${ramPercent} " -ForegroundColor $ramColor -NoNewline
        Write-Host "| Ollama: ${ollamaRamMB}MB " -ForegroundColor $ollamaColor -NoNewline
        Write-Host "| GPU: ${gpuUsedStr}/${gpuTotalStr}MB (${gpuUtilStr}%) " -ForegroundColor Gray -NoNewline
        Write-Host "| CPU: ${cpuUtil}%" -ForegroundColor $(if ($cpuUtil -lt 50) { 'Green' } elseif ($cpuUtil -lt 80) { 'Yellow' } else { 'Red' })
        
        # Log to file if requested
        if ($logFile) {
            "$timestamp,$usedRamMB,$totalRamMB,$ramPercent,$ollamaRamMB,$gpuUsedMB,$gpuTotalMB,$gpuUtil,$cpuUtil" | Out-File -FilePath $logFile -Append
        }
        
        Start-Sleep -Seconds $IntervalSeconds
    }
} catch {
    Write-Host ""
    Write-Host "Monitoring stopped." -ForegroundColor Yellow
} finally {
    if ($logFile) {
        Write-Host "Log saved to: $logFile" -ForegroundColor Green
    }
}
