$ErrorActionPreference='SilentlyContinue'

# Try exact process name first
$p = Get-Process -Name 'pin_rpa' -ErrorAction SilentlyContinue
if ($p) {
  $p | Select-Object Id,ProcessName,StartTime,CPU,WS | Format-Table -AutoSize
  exit 0
}

# Search by command line via CIM (covers python/node wrappers)
Get-CimInstance Win32_Process |
  Where-Object { $_.Name -match 'pin|rpa' -or ($_.CommandLine -and $_.CommandLine -match 'pin_rpa|pin-rpa|rpa') } |
  Select-Object ProcessId,Name,CommandLine |
  Format-List
