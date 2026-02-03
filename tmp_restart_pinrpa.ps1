$ErrorActionPreference='Continue'

# Identify pin_rpa debug stack
$targets = Get-CimInstance Win32_Process | Where-Object {
  $_.CommandLine -and ($_.CommandLine -match 'pin_rpa_boards_patch\.py' -or $_.CommandLine -match 'run_debug\.ps1' -or $_.CommandLine -match 'run_debug\.bat')
} | Select-Object ProcessId,Name,CommandLine

$targets | Format-List

# Stop python first, then powershell/cmd wrappers
$stopOrder = @('python.exe','powershell.exe','cmd.exe')
foreach ($n in $stopOrder) {
  foreach ($p in ($targets | Where-Object { $_.Name -ieq $n })) {
    Write-Host "Stopping $($p.Name) PID=$($p.ProcessId)" -ForegroundColor Yellow
    try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop } catch { }
  }
}

Start-Sleep -Seconds 2

# Relaunch
$wd = 'C:\Users\lkjhg\Desktop\pin_rpa'
Write-Host "Starting run_debug.bat in $wd" -ForegroundColor Green
Start-Process -FilePath (Join-Path $wd 'run_debug.bat') -WorkingDirectory $wd
