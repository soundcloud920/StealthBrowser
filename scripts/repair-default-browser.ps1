#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$script:InstallScriptDir = $repoRoot
. (Join-Path $repoRoot 'Stealth-Engine.ps1')
. (Join-Path $repoRoot 'Stealth-Taskbar.ps1')

$stealthExe = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\firefox.exe'
if (-not (Test-Path -LiteralPath $stealthExe)) {
    throw "Stealth engine not found: $stealthExe"
}

$profilesIni = Join-Path $env:APPDATA 'Mozilla\Firefox\profiles.ini'
$profilePath = $null
if (Test-Path $profilesIni) {
    $ini = Get-Content $profilesIni -Raw
    if ($ini -match '(?ms)\[Profile\d+\][^\[]*?Name=stealth[^\[]*?Path=([^\r\n]+)') {
        $rel = $Matches[1].Trim()
        $profilePath = if ($rel -match '^Profiles/') {
            Join-Path (Split-Path $profilesIni -Parent) $rel.Replace('/', '\')
        } else {
            Join-Path (Split-Path $profilesIni -Parent) $rel
        }
    }
}
if (-not $profilePath) {
    $profilePath = Get-ChildItem (Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles') -Filter '*.stealth' -Directory |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $profilePath) {
    throw 'Stealth profile not found'
}

$launcherExe = Join-Path $repoRoot 'Stealth.exe'
if (-not (Test-Path $launcherExe)) {
    $launcherExe = $stealthExe
}

Write-Host "Engine:  $stealthExe"
Write-Host "Profile: $profilePath"
Register-StealthTaskbarIdentity `
    -StealthExe $stealthExe `
    -LauncherPath "`"$launcherExe`"" `
    -IconPath "$launcherExe,0" `
    -ProfilePath $profilePath `
    -SetAsDefaultBrowser
Write-Host 'Done. External links should open in Stealth.'
