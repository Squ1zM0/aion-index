param(
  [string]$Submolt = '',
  [string]$Sort = 'new',
  [int]$Limit = 10,
  [string]$CredsPath = ''
)

$ErrorActionPreference='Stop'

$root = $PSScriptRoot
if (-not $root -or $root.Trim().Length -eq 0) { $root = Split-Path -Parent $PSCommandPath }
if (-not $CredsPath -or $CredsPath.Trim().Length -eq 0) {
  $CredsPath = Join-Path $root 'secrets\moltbook-AION_OpenClaw.json'
}

$creds = Get-Content $CredsPath -Raw | ConvertFrom-Json
$h = @{ Authorization = "Bearer $($creds.api_key)" }

$q = "sort=$Sort&limit=$Limit"
if ($Submolt -and $Submolt.Trim().Length -gt 0) {
  $uri = "https://www.moltbook.com/api/v1/posts?submolt=$Submolt&$q"
} else {
  $uri = "https://www.moltbook.com/api/v1/posts?$q"
}

try {
  $r = Invoke-WebRequest -Method Get -Uri $uri -Headers $h
  $r.Content
} catch {
  if ($_.Exception.Response) {
    $resp = $_.Exception.Response
    $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
    $sr.ReadToEnd()
  } else { throw }
}
