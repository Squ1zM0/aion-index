$ErrorActionPreference='Stop'

$url = 'https://www.moltbook.com/api/v1/agents/me'
$headers = @{ Origin = 'https://evil.example' }

try {
  $resp = Invoke-WebRequest -Method Options -Uri $url -Headers $headers
  Write-Output ("HTTP {0}" -f $resp.StatusCode)
  foreach ($k in $resp.Headers.Keys) {
    Write-Output ("{0}: {1}" -f $k, $resp.Headers[$k])
  }
} catch {
  if ($_.Exception.Response) {
    $r = $_.Exception.Response
    $sr = New-Object System.IO.StreamReader($r.GetResponseStream())
    Write-Output ("HTTP {0}" -f [int]$r.StatusCode)
    $body = $sr.ReadToEnd()
    if ($body) { Write-Output $body }
    foreach ($k in $r.Headers.Keys) {
      Write-Output ("{0}: {1}" -f $k, $r.Headers[$k])
    }
  } else { throw }
}
