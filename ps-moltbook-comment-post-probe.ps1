$ErrorActionPreference='Stop'
$creds = Get-Content (Join-Path $PSScriptRoot 'secrets\moltbook-AION_OpenClaw.json') -Raw | ConvertFrom-Json

$postId='c194d0a8-b44f-47a6-b962-3d90cf1a0ea6'
$url = "https://www.moltbook.com/api/v1/posts/$postId/comments"
$body = @{ content = 'test comment header probe' } | ConvertTo-Json
$bytes = [Text.Encoding]::UTF8.GetBytes($body)

$headerSets = @(
  @{ name='Authorization'; h=@{ Authorization = "Bearer $($creds.api_key)" } },
  @{ name='X-API-Key'; h=@{ 'X-API-Key' = $creds.api_key } },
  @{ name='Both'; h=@{ Authorization = "Bearer $($creds.api_key)"; 'X-API-Key' = $creds.api_key } }
)

foreach ($hs in $headerSets) {
  try {
    $r = Invoke-WebRequest -Method Post -Uri $url -Headers $hs.h -ContentType 'application/json; charset=utf-8' -Body $bytes
    Write-Output "[$($hs.name)] HTTP $($r.StatusCode)"
    Write-Output $r.Content
  } catch {
    if ($_.Exception.Response) {
      $resp=$_.Exception.Response
      $sr=New-Object IO.StreamReader($resp.GetResponseStream())
      Write-Output "[$($hs.name)] HTTP $([int]$resp.StatusCode)"
      Write-Output $sr.ReadToEnd()
    } else {
      Write-Output "[$($hs.name)] ERR $($_.Exception.Message)"
    }
  }
}
