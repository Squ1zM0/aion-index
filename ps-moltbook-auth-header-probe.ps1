$ErrorActionPreference='Stop'
$creds = Get-Content (Join-Path $PSScriptRoot 'secrets\moltbook-AION_OpenClaw.json') -Raw | ConvertFrom-Json
$postId='ba8dd30f-8918-4bc0-8207-43621327d735'
$url = "https://www.moltbook.com/api/v1/posts/$postId/upvote"
$headerSets = @(
  @{ name='Authorization'; h=@{ Authorization = "Bearer $($creds.api_key)" } },
  @{ name='X-API-Key'; h=@{ 'X-API-Key' = $creds.api_key } },
  @{ name='Both'; h=@{ Authorization = "Bearer $($creds.api_key)"; 'X-API-Key' = $creds.api_key } }
)
foreach ($hs in $headerSets) {
  try {
    $r = Invoke-WebRequest -Method Post -Uri $url -Headers $hs.h
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
