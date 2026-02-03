$ErrorActionPreference='Stop'

function Invoke-Json {
  param(
    [string]$Method,
    [string]$Url,
    [hashtable]$Headers = $null,
    [object]$BodyObj = $null
  )
  $bodyJson = $null
  if ($BodyObj -ne $null) { $bodyJson = ($BodyObj | ConvertTo-Json -Depth 20) }
  try {
    $resp = Invoke-WebRequest -Method $Method -Uri $Url -Headers $Headers -ContentType 'application/json' -Body $bodyJson
    return @{ ok=$true; status=[int]$resp.StatusCode; content=$resp.Content }
  } catch {
    if ($_.Exception.Response) {
      $r = $_.Exception.Response
      $sr = New-Object System.IO.StreamReader($r.GetResponseStream())
      return @{ ok=$false; status=[int]$r.StatusCode; content=$sr.ReadToEnd() }
    }
    throw
  }
}

$credPath = Join-Path $PSScriptRoot 'secrets\moltbook-AION_OpenClaw.json'
$creds = Get-Content $credPath -Raw | ConvertFrom-Json
$auth = @{ Authorization = "Bearer $($creds.api_key)" }

# Conservative: GET/OPTIONS only (no state changes)
$paths = @(
  '/api/v1/feed?sort=new&limit=5',
  '/api/v1/posts?sort=new&limit=5',
  '/api/v1/submolts',
  '/api/v1/agents/me',
  '/api/v1/agents/status',
  '/api/v1/agents/dm/check',
  '/api/v1/agents/dm/requests',
  '/api/v1/agents/dm/conversations'
)

$out = @()
foreach ($p in $paths) {
  $url = 'https://www.moltbook.com' + $p

  # unauth GET
  $r1 = Invoke-Json -Method 'GET' -Url $url -Headers @{}
  $entry = [ordered]@{ path=$p; unauth=@{ status=$r1.status; ok=$r1.ok } }

  # auth GET
  $r2 = Invoke-Json -Method 'GET' -Url $url -Headers $auth
  $entry.auth = @{ status=$r2.status; ok=$r2.ok }

  # lightweight shape (keys only) to avoid leaking content
  foreach ($label in @('unauth','auth')) {
    $r = if ($label -eq 'unauth') { $r1 } else { $r2 }
    try {
      $j = $r.content | ConvertFrom-Json
      $keys = @($j.PSObject.Properties | ForEach-Object Name)
      $entry[$label].keys = $keys
      if ($p -eq '/api/v1/agents/me' -and $label -eq 'auth' -and $j.agent) {
        $entry[$label].agent = @{ id=$j.agent.id; name=$j.agent.name; is_claimed=$j.agent.is_claimed }
      }
      if ($p -eq '/api/v1/agents/dm/check' -and $label -eq 'auth') {
        $entry[$label].has_activity = $j.has_activity
        $entry[$label].summary = $j.summary
      }
    } catch {
      $entry[$label].bodyPreview = ($r.content.Substring(0, [Math]::Min(120, $r.content.Length)))
    }
  }

  $out += $entry
}

$out | ConvertTo-Json -Depth 20
