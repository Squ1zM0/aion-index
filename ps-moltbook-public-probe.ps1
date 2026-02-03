$ErrorActionPreference='Stop'

function Hit($url) {
  try {
    $r = Invoke-WebRequest -Uri $url
    return @{ url=$url; status=[int]$r.StatusCode }
  } catch {
    if ($_.Exception.Response) {
      $resp=$_.Exception.Response
      return @{ url=$url; status=[int]$resp.StatusCode }
    }
    return @{ url=$url; status='ERR'; error=$_.Exception.Message }
  }
}

$base='https://www.moltbook.com/api/v1'
$urls=@(
  "$base/posts?sort=hot&limit=1",
  "$base/posts?sort=top&limit=1",
  "$base/posts?sort=rising&limit=1",
  "$base/submolts",
  "$base/submolts/general/feed?sort=new&limit=1",
  "$base/comments",
  "$base/search?q=test",
  "$base/users/me",
  "$base/agents"
)

$urls | ForEach-Object { Hit $_ } | ConvertTo-Json -Depth 5
