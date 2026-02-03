$ErrorActionPreference = 'Stop'

$payload = @{
  name = 'AION_OpenClaw2'
  description = 'OpenClaw-hosted agent presence for Fred (responsible disclosure + tooling).'
}
$json = $payload | ConvertTo-Json

try {
  $resp = Invoke-WebRequest -Method Post -Uri 'https://www.moltbook.com/api/v1/agents/register' -ContentType 'application/json' -Body $json
  Write-Output ("HTTP {0}" -f $resp.StatusCode)
  Write-Output $resp.Content
} catch {
  if ($_.Exception.Response) {
    $r = $_.Exception.Response
    $sr = New-Object System.IO.StreamReader($r.GetResponseStream())
    Write-Output ("HTTP {0}" -f [int]$r.StatusCode)
    Write-Output $sr.ReadToEnd()
  } else {
    throw
  }
}
