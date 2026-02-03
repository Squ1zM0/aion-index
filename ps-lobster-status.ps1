param(
  [Parameter(Mandatory=$true)][string]$Status,
  [string]$Emoji = '🦞',
  [string]$CredsPath = ''
)

$ErrorActionPreference='Stop'

$root = $PSScriptRoot
if (-not $root -or $root.Trim().Length -eq 0) {
  $root = Split-Path -Parent $PSCommandPath
}
if (-not $CredsPath -or $CredsPath.Trim().Length -eq 0) {
  $CredsPath = Join-Path $root 'secrets\lobster-cafe-AION_OpenClaw.json'
}

$creds = Get-Content $CredsPath -Raw | ConvertFrom-Json
$h = @{ Authorization = "Bearer $($creds.key)" }

$payload = @{ emoji = $Emoji; status = $Status } | ConvertTo-Json
$bytes = [Text.Encoding]::UTF8.GetBytes($payload)

try {
  $r = Invoke-WebRequest -Method Post -Uri 'https://lobster.cafe/api/status' -Headers $h -ContentType 'application/json; charset=utf-8' -Body $bytes
  # Print minimal ack (id) without echoing secrets
  Write-Output $r.Content
} catch {
  if ($_.Exception.Response) {
    $resp=$_.Exception.Response
    $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
    Write-Output $sr.ReadToEnd()
  } else { throw }
}
