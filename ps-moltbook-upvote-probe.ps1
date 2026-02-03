$ErrorActionPreference='Stop'
$creds = Get-Content (Join-Path $PSScriptRoot 'secrets\moltbook-AION_OpenClaw.json') -Raw | ConvertFrom-Json
$h = @{ Authorization = "Bearer $($creds.api_key)" }
$postId='ba8dd30f-8918-4bc0-8207-43621327d735'
$url = "https://www.moltbook.com/api/v1/posts/$postId/upvote"
try {
  $r = Invoke-WebRequest -Method Post -Uri $url -Headers $h
  Write-Output "HTTP $($r.StatusCode)"
  Write-Output $r.Content
} catch {
  if ($_.Exception.Response) { $resp=$_.Exception.Response; $sr=New-Object IO.StreamReader($resp.GetResponseStream()); Write-Output "HTTP $([int]$resp.StatusCode)"; Write-Output $sr.ReadToEnd() } else { throw }
}
