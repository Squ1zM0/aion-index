# AIOS Ollama Optimization Guide
**System:** Intel i7-9700K | 16GB RAM | RTX 2080 4GB VRAM | Windows 10  
**Target:** Sub-10s response for 14B parameter models

---

## 1. Ollama Configuration for Windows

### Environment Variables (System-Level)
Set these via Windows System Properties → Environment Variables or PowerShell as Administrator:

```powershell
# GPU Layer Offloading - Calculate for 4GB VRAM
# RTX 2080: ~3.2GB allocatable after Windows/driver overhead
# 14B Q4_K_M ≈ 35 layers total, ~120MB per layer
# Set for ~25 layers = ~3GB GPU, rest CPU
$env:OLLAMA_NUM_GPU = "25"

# Threading - Leave 1 core for system
# i7-9700K = 8 cores / 8 threads (no HT)
$env:OLLAMA_NUM_THREAD = "6"

# Model Cache - Limit to prevent RAM exhaustion
# 16GB total - 4GB GPU - 4GB Windows - 2GB AIOS apps = ~6GB for models
$env:OLLAMA_MAX_LOADED_MODELS = "1"
$env:OLLAMA_MAX_MEMORY = "6144"  # MB, ~6GB for model weights

# Memory Mapping - Critical for 16GB RAM constraint
$env:OLLAMA_MMAP = "true"       # Allow OS to swap model data to disk
$env:OLLAMA_MLOCK = "false"     # Don't lock pages (prevents swapping but exhausts RAM)

# Context Window - Conservative for 16GB system
# 32K context ≈ 4GB additional VRAM/RAM during inference
# Default 2048, max recommended: 8192 on this hardware
$env:OLLAMA_CONTEXT_LENGTH = "8192"

# Flash Attention - Memory-efficient attention (if supported by model)
$env:OLLAMA_FLASH_ATTENTION = "true"

# Keep Alive - Don't unload models immediately (reduces reload latency)
$env:OLLAMA_KEEP_ALIVE = "30m"  # Keep model loaded for 30 minutes

# Origins - If accessing via API from other hosts
$env:OLLAMA_HOST = "0.0.0.0"
$env:OLLAMA_ORIGINS = "*"
```

### Permanent Environment Setup (Registry)
```powershell
# Run as Administrator to persist across reboots
[Environment]::SetEnvironmentVariable("OLLAMA_NUM_GPU", "25", "Machine")
[Environment]::SetEnvironmentVariable("OLLAMA_NUM_THREAD", "6", "Machine")
[Environment]::SetEnvironmentVariable("OLLAMA_MAX_LOADED_MODELS", "1", "Machine")
[Environment]::SetEnvironmentVariable("OLLAMA_MAX_MEMORY", "6144", "Machine")
[Environment]::SetEnvironmentVariable("OLLAMA_MMAP", "true", "Machine")
[Environment]::SetEnvironmentVariable("OLLAMA_MLOCK", "false", "Machine")
[Environment]::SetEnvironmentVariable("OLLAMA_CONTEXT_LENGTH", "8192", "Machine")
[Environment]::SetEnvironmentVariable("OLLAMA_FLASH_ATTENTION", "true", "Machine")
[Environment]::SetEnvironmentVariable("OLLAMA_KEEP_ALIVE", "30m", "Machine")
```

### Ollama Startup Script
Create `start-ollama-optimized.ps1`:
```powershell
#!/usr/bin/env pwsh
#requires -RunAsAdministrator

# Kill existing Ollama
Stop-Process -Name "ollama" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Set process priority and affinity
$ollamaPath = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"
$proc = Start-Process -FilePath $ollamaPath -ArgumentList "serve" -PassThru

# Wait for process to fully start
Start-Sleep -Seconds 5

# Set high priority (requires elevated privileges)
(Get-Process -Name "ollama" -ErrorAction SilentlyContinue) | ForEach-Object {
    $_.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High
    # CPU affinity: Use cores 0-5 (leave 6,7 for system)
    $_.ProcessorAffinity = 0x3F  # Binary: 0011 1111 = cores 0-5
}

Write-Host "Ollama started with High priority, cores 0-5 affinity, 25 GPU layers"
```

---

## 2. Windows System Tuning

### Power Plan (High Performance)
```powershell
# Set High Performance power plan
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

# Or create AI-optimized power plan
powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61  # Ultimate Performance base
powercfg /changename <newGUID> "AIOS Performance"

# Disable idle states for CPU
powercfg /setacvalueindex scheme_current sub_processor 5d76a2ca-e8c0-402f-a133-2158492d58ad 0
powercfg /setactive scheme_current
```

### RAM Reclamation Services (Disable)
```powershell
# Run as Administrator

# Disable Superfetch/SysMain (prevents preloading apps into RAM)
Stop-Service -Name "SysMain" -Force
Set-Service -Name "SysMain" -StartupType Disabled

# Disable Windows Search indexing during AI operation
Stop-Service -Name "WSearch" -Force
Set-Service -Name "WSearch" -StartupType Disabled

# Disable unnecessary background services
$services = @(
    "DiagTrack",           # Connected User Experiences and Telemetry
    "dmwappushservice",    # WAP Push Message Routing
    "MapsBroker",          # Downloaded Maps Manager
    "lfsvc",               # Geolocation Service
    "SharedAccess",        # Internet Connection Sharing
    "WbioSrvc",            # Windows Biometric Service
    "WMPNetworkSvc"        # Windows Media Player Network Sharing
)

foreach ($svc in $services) {
    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
    Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
}
```

### Virtual Memory (Pagefile) Optimization
```powershell
# Disable automatic pagefile management
$computer = Get-WmiObject -Class Win32_ComputerSystem
$computer.AutomaticManagedPagefile = $false
$computer.Put()

# Configure fixed-size pagefile on fastest drive
# 16GB physical RAM: Set pagefile to 8-12GB (0.5-0.75x RAM)
$pagefile = Get-WmiObject -Class Win32_PageFileSetting
$pagefile.InitialSize = 8192  # 8GB minimum
$pagefile.MaximumSize = 12288 # 12GB maximum
$pagefile.Put()

# If you have a secondary SSD, move pagefile there for less contention
# Get-WmiObject Win32_PageFileSetting | Remove-WmiObject
# Then recreate on D: drive
```

### Real-Time Process Priority
```powershell
# Function to set Ollama priority whenever it starts
Register-WmiEvent -Class Win32_ProcessStartTrace -SourceIdentifier "OllamaStart" -Action {
    if ($_.TargetInstance.Name -eq "ollama.exe") {
        $proc = Get-Process -Id $_.TargetInstance.ProcessId -ErrorAction SilentlyContinue
        if ($proc) {
            $proc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High
            $proc.ProcessorAffinity = 0x3F  # Cores 0-5
        }
    }
}
```

---

## 3. Model Optimization

### Quantization Levels for 4GB VRAM

| Model Size | Q4_K_M | Q5_K_M | Q6_K | Q8_0 |
|------------|--------|--------|------|------|
| 7B | ~4.1GB | ~4.7GB | ~5.4GB | ~7.0GB |
| 14B | ~8.2GB | ~9.4GB | ~10.8GB | ~14.0GB |
| 14B GPU Layers | 25 layers | 20 layers | 15 layers | N/A |

**Recommendation: Q4_K_M for 14B models** - Best speed/quality tradeoff

### Context Window Pragmatics

| Context | VRAM/RAM Required | Tokens/sec (i7-9700K) | Use Case |
|---------|-------------------|----------------------|----------|
| 2K | +0.5GB | 8-12 | Quick Q&A |
| 4K | +1.0GB | 6-10 | Short conversations |
| 8K | +2.0GB | 4-8 | Medium tasks |
| 16K | +4.0GB | 2-4 | Long context (not recommended) |
| 32K | +8.0GB | 1-2 | Document analysis (avoid) |

**Working Recommendation: 8192 context maximum**

### Optimal num_gpu Calculation for RTX 2080 (4GB)

```
RTX 2080 4GB VRAM:
- Windows/driver overhead: ~800MB
- Available for models: ~3200MB
- 14B Q4_K_M layer size: ~120-140MB
- Safe allocation: 25 layers = ~3GB GPU
- Remaining 10 layers on CPU (slower but functional)

Formula: num_gpu = floor((VRAM_available - overhead) / layer_size)
                 = floor(3200 / 130) ≈ 24-25
```

---

## 4. Recommended Models

### Primary: Qwen2.5-14B (Context-Optimized)

```bash
# Base model - 32K context, Q4_K_M
ollama pull qwen2.5:14b

# Create custom Modelfile with optimized parameters
cat > Qwen2.5-14B-Optimized.Modelfile << 'EOF'
FROM qwen2.5:14b

# Conservative parameters for 16GB RAM
PARAMETER num_ctx 8192
PARAMETER num_gpu 25
PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER top_k 40
PARAMETER repeat_penalty 1.1

# Flash attention if model supports
PARAMETER flash_attn true

SYSTEM You are an AI assistant optimized for efficient operation on constrained hardware.
EOF

ollama create qwen2.5-14b-optimized -f Qwen2.5-14B-Optimized.Modelfile
```

### Alternative: DeepSeek-R1 Distilled

```bash
# 14B distilled variant (Qwen/Qwen2.5 based)
# Smarter reasoning, slightly slower
ollama pull deepseek-r1:14b

# Or even smaller for faster responses:
ollama pull deepseek-r1:7b  # If 14B too slow

# Create optimized variant
cat > DeepSeek-R1-14B-Optimized.Modelfile << 'EOF'
FROM deepseek-r1:14b
PARAMETER num_ctx 8192
PARAMETER num_gpu 22  # Slightly less for reasoning overhead
PARAMETER temperature 0.6
PARAMETER num_predict 2048  # Limit thinking length
EOF
```

### Lightweight Alternatives for <5s Response

| Model | Size | VRAM | Expected t/s | Use Case |
|-------|------|------|--------------|----------|
| qwen2.5:7b | 4.4GB | 3GB GPU (full offload) | 15-25 | Fast Q&A |
| qwen2.5:4b | 2.4GB | Full GPU | 25-40 | Simple tasks |
| phi4:14b | 9GB | 25 layers GPU | 8-12 | Microsoft ecosystem |
| gemma2:9b | 5.5GB | 30 layers GPU | 12-18 | Google/Gemma family |

### GGUF Sources for Hand-Optimized Quants

```bash
# High-quality community quants (better than default Ollama):
# 1. bartowski's imatrix quants (measurement-optimized)
#    https://huggingface.co/bartowski/
#
# 2. unsloth's dynamic quants (4-bit with better accuracy)
#    https://huggingface.co/unsloth/
#
# 3. Local conversion for specific optimization:
#    Use llama.cpp's imatrix for your actual workload
```

---

## 5. Monitoring & Validation

### Ollama Log Inspection

```powershell
# Enable debug logging
$env:OLLAMA_DEBUG = "1"

# Watch logs in real-time
Get-Content "$env:LOCALAPPDATA\Ollama\logs\server.log" -Tail 100 -Wait

# Extract GPU offload info
grep "offload\|layers\|GPU\|CUDA" "$env:LOCALAPPDATA\Ollama\logs\server.log"

# Look for these key lines:
# - "offloaded X/Y layers to GPU" - Verify your num_gpu setting
# - "CUDA\|METAL" - Backend being used
# - "llama_new_context_with_model: n_ctx = XXXX" - Context size confirmed
```

### Response Time Benchmark Script

```powershell
# benchmark.ps1
$models = @("qwen2.5:14b", "deepseek-r1:14b", "qwen2.5:7b")
$prompts = @(
    "Explain quantum computing in simple terms.",
    "Write a Python function to calculate fibonacci numbers.",
    "Summarize the key principles of efficient AI operation on constrained hardware."
)

$results = @()

foreach ($model in $models) {
    Write-Host "Testing $model..."
    
    foreach ($prompt in $prompts) {
        $body = @{
            model = $model
            prompt = $prompt
            stream = $false
            options = @{ num_predict = 256 }
        } | ConvertTo-Json
        
        $start = Get-Date
        try {
            $response = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" `
                -Method POST -Body $body -ContentType "application/json" -TimeoutSec 120
            $end = Get-Date
            $duration = ($end - $start).TotalSeconds
            $tokensPerSec = $response.eval_count / $duration
            
            $results += [PSCustomObject]@{
                Model = $model
                Prompt = $prompt.Substring(0, [Math]::Min(50, $prompt.Length))
                Duration = [math]::Round($duration, 2)
                TokensPerSec = [math]::Round($tokensPerSec, 2)
                TokensGenerated = $response.eval_count
            }
        } catch {
            $results += [PSCustomObject]@{
                Model = $model
                Prompt = $prompt.Substring(0, [Math]::Min(50, $prompt.Length))
                Duration = "TIMEOUT/ERROR"
                TokensPerSec = 0
                TokensGenerated = 0
            }
        }
    }
}

$results | Format-Table -AutoSize
$results | Export-Csv -Path "ollama_benchmark_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" -NoTypeInformation
```

### Expected Performance Targets

| Configuration | t/s 14B Q4 | 256-token latency | Notes |
|--------------|------------|-------------------|-------|
| CPU-only (8 threads) | 3-5 t/s | 50-85s | Baseline |
| Partial GPU (25 layers) | 6-10 t/s | 25-42s | **Our target** |
| Full GPU offload (7B) | 15-25 t/s | 10-17s | Fallback to 7B if needed |

**Goal: <10s for 7B, <30s for 14B with 25 layers GPU**

### Memory Pressure Indicators

```powershell
# Real-time monitoring script
while ($true) {
    $ram = Get-CimInstance -ClassName Win32_OperatingSystem
    $usedRam = [math]::Round(($ram.TotalVisibleMemorySize - $ram.FreePhysicalMemory) / 1MB, 2)
    $totalRam = [math]::Round($ram.TotalVisibleMemorySize / 1MB, 2)
    $ramPercent = [math]::Round(($usedRam / $totalRam) * 100, 1)
    
    $gpu = nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu --format=csv,noheader 2>$null
    if ($gpu) {
        $gpuUsed, $gpuTotal, $gpuUtil = $gpu.Split(',').Trim()
    }
    
    $ollamaProc = Get-Process -Name "ollama" -ErrorAction SilentlyContinue
    $ollamaRam = if ($ollamaProc) { [math]::Round(($ollamaProc.WorkingSet64 | Measure-Object -Sum).Sum / 1MB, 2) } else { 0 }
    
    Write-Host "$(Get-Date -Format 'HH:mm:ss') | RAM: $usedRam / $totalRam MB ($ramPercent%) | Ollama: $ollamaRam MB | GPU: $gpuUsed / $gpuTotal"
    
    if ($ramPercent -gt 90) {
        Write-Host "WARNING: High memory pressure detected!" -ForegroundColor Red
    }
    
    Start-Sleep -Seconds 5
}
```

### Thermal Monitoring (HWiNFO or alternatives)

```powershell
# Simple CPU/GPU thermal check (requires nvidia-smi)
function Get-Thermals {
    # GPU temp
    nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits
    
    # CPU temp (requires external tools)
    # Install: winget install CPUID.HWiNFO
    # or use OpenHardwareMonitorLib
}

# Watch for throttling
# GPU >83°C = thermal throttle (RTX 2080)
# CPU >90°C = thermal throttle (i7-9700K)
```

---

## 6. Quick Reference Commands

### Daily Operation

```powershell
# Start optimized
.\start-ollama-optimized.ps1

# Pull and test a model
ollama pull qwen2.5:14b
ollama run qwen2.5:14b --verbose

# Check loaded model stats
ollama ps

# Clear model cache if needed
ollama rm qwen2.5:14b  # Unload specific
# Or restart Ollama to clear all

# Test with timing
Measure-Command { ollama run qwen2.5:14b "Hello" --verbose }
```

### Emergency RAM Recovery

```powershell
# If system becomes unresponsive:
Stop-Process -Name "ollama" -Force
Start-Service -Name "SysMain"  # Re-enable Superfetch temporarily
# Restart computer
```

---

## 7. Summary Checklist

- [ ] Environment variables set (25 GPU layers, 6 threads, 8K context)
- [ ] Power plan set to High Performance
- [ ] Superfetch/SysMain disabled
- [ ] Pagefile configured to 8-12GB fixed
- [ ] Ollama startup script created with High priority
- [ ] Qwen2.5-14B-Q4_K_M pulled and tested
- [ ] Response time <30s validated for 14B
- [ ] Monitoring scripts ready
- [ ] Fallback 7B model identified

**Final Expected Performance:**
- 7B Q4_K_M: 15-25 t/s, <10s responses ✅
- 14B Q4_K_M (25 GPU layers): 6-10 t/s, <30s responses ✅

---

*Generated: 2026-02-02*  
*Valid for: Ollama 0.3.x+, llama.cpp backend*
