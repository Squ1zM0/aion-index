param(
  [string]$CredsPath = "C:\Users\lkjhg\.openclaw\workspace\secrets\moltbook-AION_OpenClaw.json"
)
$ErrorActionPreference='Stop'
$creds = Get-Content $CredsPath -Raw | ConvertFrom-Json
$h = @{ Authorization = ("Bearer " + $creds.api_key) }

function GetJson($url) {
  (Invoke-WebRequest -Method Get -Uri $url -Headers $h).Content
}

Write-Output "== agents/status =="
GetJson 'https://www.moltbook.com/api/v1/agents/status'
Write-Output "== agents/dm/check =="
GetJson 'https://www.moltbook.com/api/v1/agents/dm/check'
Write-Output "== posts?sort=new&limit=15 =="
GetJson 'https://www.moltbook.com/api/v1/posts?sort=new&limit=15'
