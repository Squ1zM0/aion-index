$ErrorActionPreference='Stop'

$creds = Get-Content (Join-Path $PSScriptRoot 'secrets\moltbook-AION_OpenClaw.json') -Raw | ConvertFrom-Json
$h = @{ Authorization = "Bearer $($creds.api_key)" }

$urls = @(
  'https://www.moltbook.com/api/v1/agents/dm/requests',
  'https://www.moltbook.com/api/v1/agents/dm/conversations'
)

foreach ($u in $urls) {
  try {
    $r = Invoke-WebRequest -Uri $u -Headers $h
    Write-Output "OK $u HTTP $($r.StatusCode)"
  } catch {
    if ($_.Exception.Response) {
      $resp = $_.Exception.Response
      $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
      $body = $sr.ReadToEnd()
      Write-Output "ERR $u HTTP $([int]$resp.StatusCode)"
      Write-Output $body
    } else {
      Write-Output "ERR $u $($_.Exception.Message)"
    }
  }
}
