Start-Sleep -Seconds 3
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -match 'pin_rpa_boards_patch\.py' } | Select-Object ProcessId,Name,CommandLine | Format-List
