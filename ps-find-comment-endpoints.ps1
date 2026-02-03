$ErrorActionPreference='Stop'
Select-String -Path .\moltbook-skill.md -Pattern 'comment' | Select-Object -First 80 | ForEach-Object {
  Write-Output ("{0}: {1}" -f $_.LineNumber, $_.Line)
}
