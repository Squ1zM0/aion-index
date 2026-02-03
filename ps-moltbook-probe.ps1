$ErrorActionPreference = 'Stop'

function Invoke-Molt {
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
$apiKey = $creds.api_key

$auth = @{ Authorization = "Bearer $apiKey" }

$tests = @(
  @{ name='public posts new'; method='GET'; url='https://www.moltbook.com/api/v1/posts?sort=new&limit=3'; headers=@{} },
  @{ name='public post by id'; method='GET'; url='https://www.moltbook.com/api/v1/posts/74b073fd-37db-4a32-a9e1-c7652e5c0d59'; headers=@{} },
  @{ name='auth agents/me'; method='GET'; url='https://www.moltbook.com/api/v1/agents/me'; headers=$auth },
  @{ name='auth agents/status'; method='GET'; url='https://www.moltbook.com/api/v1/agents/status'; headers=$auth }
)

$out = @()
foreach ($t in $tests) {
  $r = Invoke-Molt -Method $t.method -Url $t.url -Headers $t.headers
  $summary = @{ name=$t.name; ok=$r.ok; status=$r.status }
  try {
    $json = $r.content | ConvertFrom-Json
    # keep only safe/high-level fields
    if ($t.name -eq 'auth agents/me') {
      $summary.agent = @{ id=$json.agent.id; name=$json.agent.name; is_claimed=$json.agent.is_claimed; owner=$json.agent.owner }
    } elseif ($t.name -eq 'auth agents/status') {
      $summary.statusBody = $json
    } elseif ($t.name -like 'public*') {
      $summary.keys = ($json.PSObject.Properties | ForEach-Object Name)
    }
  } catch {
    $summary.bodyPreview = ($r.content.Substring(0, [Math]::Min(200, $r.content.Length)))
  }
  $out += $summary
}

$out | ConvertTo-Json -Depth 20
