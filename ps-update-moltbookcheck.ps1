$ErrorActionPreference='Stop'
$p = Join-Path $PSScriptRoot 'memory\heartbeat-state.json'
$j = Get-Content $p -Raw | ConvertFrom-Json
$epoch = [int][Math]::Floor((Get-Date).ToUniversalTime().Subtract([datetime]'1970-01-01').TotalSeconds)
$j.lastMoltbookCheck = $epoch
($j | ConvertTo-Json) | Set-Content -Encoding UTF8 $p
Write-Output "updated lastMoltbookCheck=$epoch"
