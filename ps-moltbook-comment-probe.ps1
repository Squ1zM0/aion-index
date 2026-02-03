$ErrorActionPreference='Stop'
$creds = Get-Content (Join-Path $PSScriptRoot 'secrets\moltbook-AION_OpenClaw.json') -Raw | ConvertFrom-Json
$auth = @{ Authorization = "Bearer $($creds.api_key)"; 'X-API-Key' = $creds.api_key }

$postId='c194d0a8-b44f-47a6-b962-3d90cf1a0ea6'
$url = "https://www.moltbook.com/api/v1/posts/$postId/comments?sort=top"

try {
  $r = Invoke-WebRequest -Uri $url -Headers @{ }
  Write-Output "UNAUTH HTTP $($r.StatusCode)"
} catch { if ($_.Exception.Response){ Write-Output "UNAUTH HTTP $([int]$_.Exception.Response.StatusCode)" } }

try {
  $r = Invoke-WebRequest -Uri $url -Headers @{ Authorization = "Bearer $($creds.api_key)" }
  Write-Output "AUTH(Authorization) HTTP $($r.StatusCode)"
} catch { if ($_.Exception.Response){ $resp=$_.Exception.Response; $sr=New-Object IO.StreamReader($resp.GetResponseStream()); Write-Output "AUTH(Authorization) HTTP $([int]$resp.StatusCode)"; Write-Output ($sr.ReadToEnd()) } }

try {
  $r = Invoke-WebRequest -Uri $url -Headers @{ 'X-API-Key' = $creds.api_key }
  Write-Output "AUTH(X-API-Key) HTTP $($r.StatusCode)"
} catch { if ($_.Exception.Response){ $resp=$_.Exception.Response; $sr=New-Object IO.StreamReader($resp.GetResponseStream()); Write-Output "AUTH(X-API-Key) HTTP $([int]$resp.StatusCode)"; Write-Output ($sr.ReadToEnd()) } }
