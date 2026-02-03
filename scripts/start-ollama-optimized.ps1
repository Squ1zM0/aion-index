#!/usr/bin/env pwsh
#requires -RunAsAdministrator
# Ollama Optimized Startup for AIOS
# Target: i7-9700K, 16GB RAM, RTX 2080 4GB VRAM

Write-Host "=== Ollama Optimized Startup ===" -ForegroundColor Cyan
Write-Host "Hardware: i7-9700K | 16GB RAM | RTX 2080 4GB" -ForegroundColor Gray

# Kill existing Ollama processes
Write-Host "Stopping existing Ollama processes..." -ForegroundColor Yellow
Stop-Process -Name "ollama" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Set environment optimizations
$env:OLLAMA_NUM_GPU = "25"          # ~3GB GPU layers for 14B Q4_K_M
$env:OLLAMA_NUM_THREAD = "6"        # Leave 2 cores for system
$env:OLLAMA_MAX_LOADED_MODELS = "1" # Prevent RAM exhaustion
$env:OLLAMA_MAX_MEMORY = "6144"     # ~6GB for models
$env:OLLAMA_MMAP = "true"           # Allow memory-mapped I/O
$env:OLLAMA_MLOCK = "false"         # Don't lock pages
$env:OLLAMA_CONTEXT_LENGTH = "8192" # Conservative for 16GB RAM
$env:OLLAMA_FLASH_ATTENTION = "true" # Memory-efficient attention
$env:OLLAMA_KEEP_ALIVE = "30m"      # Keep models loaded

Write-Host "Environment configured:" -ForegroundColor Green
Write-Host "  GPU Layers: 25 (~3GB GPU)" -ForegroundColor Gray
Write-Host "  CPU Threads: 6 (cores 0-5)" -ForegroundColor Gray
Write-Host "  Context: 8192 tokens" -ForegroundColor Gray
Write-Host "  Max Memory: 6144 MB" -ForegroundColor Gray

# Start Ollama
$ollamaPath = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"
if (-not (Test-Path $ollamaPath)) {
    $ollamaPath = "ollama.exe"  # Fallback to PATH
}

Write-Host "Starting Ollama..." -ForegroundColor Yellow
$proc = Start-Process -FilePath $ollamaPath -ArgumentList "serve" -PassThru -WindowStyle Hidden

# Wait for startup
Start-Sleep -Seconds 5

# Get the actual server process (ollama.exe spawn child processes)
$attempts = 0
$maxAttempts = 10
while ($attempts -lt $maxAttempts) {
    $ollamaProcs = Get-Process -Name "ollama" -ErrorAction SilentlyContinue
    if ($ollamaProcs) {
        foreach ($p in $ollamaProcs) {
            try {
                # Set High priority
                $p.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High
                # CPU affinity: cores 0-5 (0x3F = 0011 1111)
                $p.ProcessorAffinity = 0x3F
                Write-Host "  PID $($p.Id): Priority=High, Affinity=0-5" -ForegroundColor Gray
            } catch {
                # Process might have exited or access denied
            }
        }
        break
    }
    Start-Sleep -Seconds 1
    $attempts++
}

if ($attempts -eq $maxAttempts) {
    Write-Host "WARNING: Could not find Ollama processes to optimize" -ForegroundColor Red
} else {
    Write-Host "Ollama optimized and running!" -ForegroundColor Green
}

Write-Host ""
Write-Host "Test with: ollama run qwen2.5:14b --verbose" -ForegroundColor Cyan
Write-Host "Benchmark: .\scripts\benchmark.ps1" -ForegroundColor Cyan
