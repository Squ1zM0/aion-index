#!/usr/bin/env pwsh
# Ollama Benchmark Script for AIOS Performance Testing
# Tests response time across different model configurations

param(
    [string[]]$Models = @("qwen2.5:14b", "qwen2.5:7b"),
    [int]$TokensToGenerate = 256,
    [int]$TimeoutSeconds = 120
)

$prompts = @(
    "Explain the concept of machine learning in simple terms.",
    "Write a Python function to calculate the factorial of a number.",
    "Analyze the trade-offs between performance and resource consumption in AI systems.",
    "Summarize three key benefits of local AI deployment versus cloud-based solutions."
)

$results = @()
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
Write-Host "=== Ollama Performance Benchmark ===" -ForegroundColor Cyan
Write-Host "Started: $(Get-Date)" -ForegroundColor Gray
Write-Host "Tokens per test: $TokensToGenerate" -ForegroundColor Gray
Write-Host "Models: $($Models -join ', ')" -ForegroundColor Gray
Write-Host ""

$testNum = 0
$totalTests = $Models.Count * $prompts.Count

foreach ($model in $Models) {
    Write-Host "Testing model: $model" -ForegroundColor Yellow
    
    foreach ($prompt in $prompts) {
        $testNum++
        $promptShort = if ($prompt.Length -gt 50) { $prompt.Substring(0, 50) + "..." } else { $prompt }
        Write-Host "  [$testNum/$totalTests] $promptShort" -ForegroundColor Gray -NoNewline
        
        $body = @{
            model = $model
            prompt = $prompt
            stream = $false
            options = @{
                num_predict = $TokensToGenerate
                temperature = 0.7
            }
        } | ConvertTo-Json -Depth 3
        
        $start = Get-Date
        $success = $false
        $errorMsg = ""
        
        try {
            $response = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" `
                -Method POST -Body $body -ContentType "application/json" -TimeoutSec $TimeoutSeconds
            $end = Get-Date
            $duration = ($end - $start).TotalSeconds
            $actualTokens = $response.eval_count
            $tokensPerSec = if ($duration -gt 0) { $actualTokens / $duration } else { 0 }
            $success = $true
            
            Write-Host " - $($duration.ToString('F1'))s ($($tokensPerSec.ToString('F1')) t/s)" -ForegroundColor Green
        } catch {
            $end = Get-Date
            $duration = ($end - $start).TotalSeconds
            $errorMsg = $_.Exception.Message
            $actualTokens = 0
            $tokensPerSec = 0
            
            Write-Host " - FAILED after $($duration.ToString('F1'))s" -ForegroundColor Red
        }
        
        $results += [PSCustomObject]@{
            Model = $model
            Prompt = $promptShort
            PromptFull = $prompt
            DurationSeconds = [math]::Round($duration, 2)
            TokensPerSecond = [math]::Round($tokensPerSec, 2)
            TokensGenerated = $actualTokens
            TargetTokens = $TokensToGenerate
            Success = $success
            Error = $errorMsg
            Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        }
        
        # Brief pause between tests to let system settle
        Start-Sleep -Milliseconds 500
    }
    Write-Host ""
}

# Summary
Write-Host "=== Results Summary ===" -ForegroundColor Cyan
$results | Where-Object { $_.Success } | Group-Object -Property Model | ForEach-Object {
    $model = $_.Name
    $avgTps = ($_.Group | Measure-Object -Property TokensPerSecond -Average).Average
    $avgTime = ($_.Group | Measure-Object -Property DurationSeconds -Average).Average
    Write-Host "$model`: Avg $($avgTps.ToString('F1')) t/s, $($avgTime.ToString('F1'))s per response" -ForegroundColor $(if ($avgTps -gt 8) { 'Green' } elseif ($avgTps -gt 5) { 'Yellow' } else { 'Red' })
}

# Save results
$csvPath = "ollama_benchmark_$timestamp.csv"
$results | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host ""
Write-Host "Results saved to: $csvPath" -ForegroundColor Green

# Return summary object
$results | Format-Table Model, Prompt, DurationSeconds, TokensPerSecond, TokensGenerated, Success -AutoSize
