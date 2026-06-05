#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'Stealth-Update.ps1')
. (Join-Path $root 'Stealth-Taskbar.ps1')

function Write-SetupLog {
    param([string]$Message, [string]$Level = 'Info')
    switch ($Level) {
        'Step' { Write-Host ">> $Message" -ForegroundColor Cyan; break }
        'Ok' { Write-Host "   $Message" -ForegroundColor Green; break }
        'Warn' { Write-Host "   $Message" -ForegroundColor Yellow; break }
        default { Write-Host $Message }
    }
}

$engineExe = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\firefox.exe'
$launcherExe = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Stealth.exe'
$profile = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles\kn9q3hkf.stealth'
$icon = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Stealth.exe'

if (-not (Test-Path $engineExe)) { throw "Engine not found: $engineExe" }
if (-not (Test-Path $launcherExe)) { $launcherExe = $engineExe }

Write-SetupLog 'Registering Stealth taskbar identity...' 'Step'
Register-StealthTaskbarIdentity `
    -StealthExe $engineExe `
    -LauncherPath $launcherExe `
    -IconPath "$icon,0" `
    -ProfilePath $profile

$iniPath = Join-Path (Split-Path $engineExe -Parent) 'application.ini'
if (Test-Path $iniPath) {
    $ini = Get-Content $iniPath -Raw
    $ini = $ini -replace '(?m)^Name=.*$', 'Name=Firefox'
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [IO.File]::WriteAllText($iniPath, $ini, $utf8)
    Write-SetupLog 'application.ini Name=Firefox' 'Ok'
}

Write-SetupLog 'Done. Fully close Stealth, unpin old taskbar button, launch via Stealth shortcut, pin again.' 'Ok'
