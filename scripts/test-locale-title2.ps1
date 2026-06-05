$ErrorActionPreference = 'Stop'
$engine = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\firefox.exe'
$profile = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles\kn9q3hkf.stealth'
Get-Process firefox -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

Write-Host 'Launch with intl.locale.requested=en-GB'
$p = Start-Process $engine -ArgumentList '-no-remote','-profile',"`"$profile`"",'-pref','intl.locale.requested=en-GB' -PassThru
Start-Sleep -Seconds 9
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probe-window-title.ps1')
$p | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process firefox -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

Write-Host 'Launch with intl.locale.requested=ru,en-GB (current)'
$p2 = Start-Process $engine -ArgumentList '-no-remote','-profile',"`"$profile`"",'-pref','intl.locale.requested=ru,en-GB' -PassThru
Start-Sleep -Seconds 9
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probe-window-title.ps1')
