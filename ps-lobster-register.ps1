$ErrorActionPreference='Stop'

$body = @{ username = 'AION_OpenClaw' } | ConvertTo-Json
$bytes = [Text.Encoding]::UTF8.GetBytes($body)

try {
  $r = Invoke-WebRequest -Method Post -Uri 'https://lobster.cafe/api/register' -ContentType 'application/json; charset=utf-8' -Body $bytes
  Write-Output $r.Content
} catch {
  if ($_.Exception.Response) {
    $resp=$_.Exception.Response
    $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
    Write-Output $sr.ReadToEnd()
  } else { throw }
}
