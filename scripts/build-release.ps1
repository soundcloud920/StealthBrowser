#Requires -Version 5.1
<#
.SYNOPSIS
  Full StealthBrowser release build: bundle, launcher, portable zip, single-file setup .exe.
#>
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$versionPath = Join-Path $root 'version.json'
$version = '1.0.0-beta'
if (Test-Path $versionPath) {
    $version = (Get-Content $versionPath -Raw | ConvertFrom-Json).setupVersion
}

function Get-StealthReleaseItems {
    return @(
        'Setup.cmd', 'Setup.ps1',
        'Install-Stealth.cmd', 'Install-Stealth.ps1',
        'Update-Profile.cmd',
        'Stealth.exe', 'StealthLauncher.cs', 'StealthSetup.cs',
        'Stealth-ApplyUpdate.ps1', 'Stealth-Update.ps1',
        'Stealth-Taskbar.ps1', 'Stealth-Engine.ps1',
        'bundle.zip', 'branding', 'README.md', 'version.json', 'LICENSE'
    )
}

function Copy-StealthReleaseStage {
    param(
        [string]$StageDir,
        [string]$RootDir
    )

    foreach ($item in (Get-StealthReleaseItems)) {
        $src = Join-Path $RootDir $item
        if (-not (Test-Path $src)) { throw "Missing release file: $item" }
        Copy-Item $src (Join-Path $StageDir $item) -Recurse -Force
    }

    $fontsDir = Join-Path $StageDir 'fonts'
    New-Item -ItemType Directory -Force -Path $fontsDir | Out-Null
    foreach ($font in @('LLG_Relicus-Regular.ttf', 'LLG_Relicus-Bold.ttf')) {
        $fontSrc = Join-Path $RootDir "bundle\$font"
        if (Test-Path $fontSrc) {
            Copy-Item $fontSrc (Join-Path $fontsDir $font) -Force
        }
    }

    $toolsSrc = Join-Path $RootDir 'tools'
    $zoomExe = Join-Path $toolsSrc 'SetProfileZoom.exe'
    if (-not (Test-Path $zoomExe)) {
        throw 'Missing tools\SetProfileZoom.exe (run build-set-profile-zoom.ps1)'
    }
    $searchExe = Join-Path $toolsSrc 'SetProfileSearch.exe'
    if (-not (Test-Path $searchExe)) {
        throw 'Missing tools\SetProfileSearch.exe (run build-set-profile-search.ps1)'
    }
    $toolsDir = Join-Path $StageDir 'tools'
    New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
    Copy-Item $zoomExe (Join-Path $toolsDir 'SetProfileZoom.exe') -Force
    Copy-Item $searchExe (Join-Path $toolsDir 'SetProfileSearch.exe') -Force
    $nativeSqlite = Join-Path $toolsSrc 'e_sqlite3.dll'
    if (Test-Path $nativeSqlite) {
        Copy-Item $nativeSqlite (Join-Path $toolsDir 'e_sqlite3.dll') -Force
    }
}

function Ensure-Utf8Bom {
    param([string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return
    }

    $utf8 = New-Object System.Text.UTF8Encoding $false
    $text = $utf8.GetString($bytes)
    $utf8Bom = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText($Path, $text, $utf8Bom)
}

function Ensure-StealthReleaseScriptEncoding {
    param([string]$RootDir)

    foreach ($name in @(
            'Setup.ps1', 'Install-Stealth.ps1', 'Stealth-Engine.ps1', 'Stealth-Update.ps1',
            'Stealth-Taskbar.ps1', 'Stealth-ApplyUpdate.ps1'
        )) {
        $path = Join-Path $RootDir $name
        if (Test-Path $path) {
            Ensure-Utf8Bom -Path $path
        }
    }
}

Write-Host ">> StealthBrowser release v$version" -ForegroundColor Cyan

Ensure-StealthReleaseScriptEncoding -RootDir $root

& (Join-Path $root 'scripts\build-set-profile-zoom.ps1')
& (Join-Path $root 'scripts\build-set-profile-search.ps1')
& (Join-Path $root 'scripts\build-bundle.ps1')
& (Join-Path $root 'scripts\compile-stealth-launcher.ps1') `
    -SourceDir $root `
    -OutputPath (Join-Path $root 'Stealth.exe')

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null

$zipOut = Join-Path $dist "StealthBrowser-setup-v$version.zip"
$payloadZip = Join-Path $dist "StealthBrowser-setup-payload-v$version.zip"
$setupExe = Join-Path $dist "StealthBrowser-Setup-v$version.exe"

foreach ($path in @($zipOut, $payloadZip, $setupExe)) {
    if (Test-Path $path) { Remove-Item $path -Force }
}

$stage = Join-Path $env:TEMP ('stealth-setup-release-' + [guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Force -Path $stage | Out-Null
try {
    Copy-StealthReleaseStage -StageDir $stage -RootDir $root
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zipOut -Force
    Write-Host "Created portable zip: $zipOut" -ForegroundColor Green

    Copy-StealthReleaseStage -StageDir $stage -RootDir $root
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $payloadZip -Force
}
finally {
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
}

& (Join-Path $root 'scripts\build-setup-exe.ps1') `
    -SourceDir $root `
    -PayloadZip $payloadZip `
    -OutputPath $setupExe `
    -Version $version

if (Test-Path $payloadZip) { Remove-Item $payloadZip -Force }

Write-Host ''
Write-Host 'Release artifacts:' -ForegroundColor Cyan
Write-Host "  ZIP (source/portable): $zipOut"
Write-Host "  EXE (single-file):     $setupExe"
