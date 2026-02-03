param(
  [string]$Base = "https://www.moltbook.com",
  [string]$ApiBase = "https://www.moltbook.com/api/v1",
  [string]$Origin = "https://evil.example"
)

$ErrorActionPreference = 'Stop'

function Probe($method, $path, $headers=@{}, $body=$null) {
  $url = if ($path.StartsWith('http')) { $path } else { "$ApiBase$path" }
  $h = @{}
  foreach ($k in $headers.Keys) { $h[$k] = $headers[$k] }

  try {
    if ($null -ne $body) {
      $resp = Invoke-WebRequest -Method $method -Uri $url -Headers $h -Body $body -TimeoutSec 20 -UseBasicParsing
    } else {
      $resp = Invoke-WebRequest -Method $method -Uri $url -Headers $h -TimeoutSec 20 -UseBasicParsing
    }
    return [pscustomobject]@{ ok=$true; method=$method; path=$path; status=[int]$resp.StatusCode; headers=$resp.Headers; body=$resp.Content }
  } catch {
    $ex = $_.Exception
    if ($ex.Response -and $ex.Response.StatusCode) {
      $status = [int]$ex.Response.StatusCode
      $sr = New-Object System.IO.StreamReader($ex.Response.GetResponseStream())
      $content = $sr.ReadToEnd()
      return [pscustomobject]@{ ok=$false; method=$method; path=$path; status=$status; headers=$ex.Response.Headers; body=$content }
    }
    return [pscustomobject]@{ ok=$false; method=$method; path=$path; status=$null; headers=$null; body=$ex.Message }
  }
}

$endpoints = @(
  "/posts?sort=new&limit=5",
  "/posts?sort=hot&limit=5",
  "/submolts",
  "/feed",
  "/search?q=test",
  "/agents/me",
  "/agents/status",
  "/agents/dm/check",
  "/agents/dm/requests",
  "/agents/dm/conversations",
  "/notifications",
  "/me",
  "/users/me",
  "/users",
  "/moderation",
  "/reports"
)

Write-Host "=== Moltbook security sweep (GET + OPTIONS only) ==="
Write-Host "ApiBase: $ApiBase"

$results = @()
foreach ($ep in $endpoints) {
  $r = Probe GET $ep @{}
  $results += $r
}

# CORS credential check: preflight with evil Origin
$preflightHeaders = @{
  "Origin" = $Origin
  "Access-Control-Request-Method" = "GET"
  "Access-Control-Request-Headers" = "Authorization, X-API-Key, Content-Type"
}
$preflightTargets = @("/agents/me","/feed","/posts")
foreach ($t in $preflightTargets) {
  $r = Probe OPTIONS $t $preflightHeaders
  $results += $r
}

$results | ForEach-Object {
  $aco = $null; $acc = $null; $ach = $null; $acm = $null
  if ($_.headers) {
    $aco = $_.headers["access-control-allow-origin"]
    $acc = $_.headers["access-control-allow-credentials"]
    $ach = $_.headers["access-control-allow-headers"]
    $acm = $_.headers["access-control-allow-methods"]
  }
  [pscustomobject]@{
    method=$_.method
    path=$_.path
    status=$_.status
    aco=$aco
    acc=$acc
    ach=$ach
    acm=$acm
    bodySnippet= if ($_.body) { ($_.body -replace "\s+"," ").Substring(0,[Math]::Min(160, ($_.body -replace "\s+"," ").Length)) } else { "" }
  }
} | Format-Table -AutoSize
