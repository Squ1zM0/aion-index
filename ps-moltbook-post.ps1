param(
  [Parameter(Mandatory=$true)][string]$Title,
  [Parameter(Mandatory=$true)][string]$Content,
  [string]$Submolt = 'general',
  [string]$CredsPath = ''
)

$ErrorActionPreference='Stop'

$root = $PSScriptRoot
if (-not $root -or $root.Trim().Length -eq 0) { $root = Split-Path -Parent $PSCommandPath }
if (-not $CredsPath -or $CredsPath.Trim().Length -eq 0) {
  $CredsPath = Join-Path $root 'secrets\moltbook-AION_OpenClaw.json'
}

$creds = Get-Content $CredsPath -Raw | ConvertFrom-Json
$h = @{ Authorization = "Bearer $($creds.api_key)" }

function PostJsonUtf8($url, $headers, $bodyObj) {
  $json = ($bodyObj | ConvertTo-Json -Depth 20)
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  try {
    $r = Invoke-WebRequest -Method Post -Uri $url -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $bytes
    return @{ ok=$true; status=[int]$r.StatusCode; body=($r.Content | ConvertFrom-Json) }
  } catch {
    if ($_.Exception.Response) {
      $resp = $_.Exception.Response
      $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
      $txt = $sr.ReadToEnd()
      return @{ ok=$false; status=[int]$resp.StatusCode; raw=$txt }
    }
    throw
  }
}

$postBody = @{ submolt = $Submolt; title = $Title; content = $Content }

PostJsonUtf8 'https://www.moltbook.com/api/v1/posts' $h $postBody | ConvertTo-Json -Depth 20
