#Requires -Version 5.1
<#
.SYNOPSIS
Full repair for taskbar hover showing "Mozilla Firefox".
Root cause: Windows uses the main window TITLE for preview header, not only AUMID.
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'Stealth-Update.ps1')
. (Join-Path $root 'Stealth-Engine.ps1')
. (Join-Path $root 'Stealth-Taskbar.ps1')

function Write-RepairLog($msg, $level = 'Info') {
    switch ($level) {
        'Step' { Write-Host ">> $msg" -ForegroundColor Cyan }
        'Ok' { Write-Host "   $msg" -ForegroundColor Green }
        'Warn' { Write-Host "   $msg" -ForegroundColor Yellow }
        default { Write-Host $msg }
    }
}
function Write-Step($msg) { Write-RepairLog $msg 'Step' }
function Write-SetupLog($msg, $level = 'Info') { Write-RepairLog $msg $level }
function Write-TextFileNoBom {
    param([string]$Path, [string]$Content)
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [IO.File]::WriteAllText($Path, $Content, $utf8)
}

$engineRoot = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine'
$engineExe = Join-Path $engineRoot 'firefox.exe'
$launcherExe = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Stealth.exe'
$profile = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles\kn9q3hkf.stealth'
$icon = if (Test-Path $launcherExe) { "$launcherExe,0" } else { "$engineExe,0" }

Write-RepairLog 'Stopping Stealth/Firefox...' 'Step'
Get-Process firefox -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

$stamp = Join-Path $engineRoot '.omni-branded'
if (Test-Path $stamp) { Remove-Item $stamp -Force }
$iconPath = Join-Path $env:LOCALAPPDATA 'LLG_Relicus\stealth-dark.ico'
if (-not (Test-Path $iconPath)) {
    $iconPath = Join-Path $root 'bundle\assets\stealth-dark.ico'
}
Set-StealthOmniBranding -EngineRoot $engineRoot -IconPath $iconPath
Clear-StealthProfileStartupCache -ProfilePath $profile

Register-StealthTaskbarIdentity `
    -StealthExe $engineExe `
    -LauncherPath $launcherExe `
    -IconPath $icon `
    -ProfilePath $profile

Write-RepairLog 'Launching Stealth for verification...' 'Step'
if (Test-Path $launcherExe) {
    Start-Process $launcherExe | Out-Null
}
else {
    Start-Process $engineExe -ArgumentList @('-no-remote', '-profile', "`"$profile`"") | Out-Null
}
Start-Sleep -Seconds 8
Write-RepairLog 'Diagnostics (window title + AUMID = what taskbar preview uses):' 'Step'
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probe-aumid-live.ps1')
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probe-window-title.ps1')
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'list-firefox-procs.ps1')
try { Start-Process ie4uinit.exe -ArgumentList '-show' -Wait -ErrorAction SilentlyContinue | Out-Null } catch {}

Write-RepairLog 'If preview still says Mozilla Firefox: unpin taskbar button, restart PC or run ie4uinit.exe -show' 'Warn'
