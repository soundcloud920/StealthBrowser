#Requires -Version 5.1
<#
.SYNOPSIS
  Builds a single-file StealthBrowser setup .exe with embedded payload zip.
#>
param(
    [string]$SourceDir,
    [string]$PayloadZip,
    [string]$OutputPath,
    [string]$Version
)

$ErrorActionPreference = 'Stop'

if (-not $SourceDir) {
    $SourceDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}

$versionPath = Join-Path $SourceDir 'version.json'
if (-not $Version -and (Test-Path $versionPath)) {
    $Version = (Get-Content $versionPath -Raw | ConvertFrom-Json).setupVersion
}
if (-not $Version) { $Version = '1.0.0-beta' }

if (-not $PayloadZip) {
    $PayloadZip = Join-Path $SourceDir "dist\StealthBrowser-setup-payload-v$Version.zip"
}
if (-not (Test-Path $PayloadZip)) {
    throw "Payload zip not found: $PayloadZip (run build-release.ps1 first)"
}

$dist = Join-Path $SourceDir 'dist'
if (-not $OutputPath) {
    $OutputPath = Join-Path $dist "StealthBrowser-Setup-v$Version.exe"
}
New-Item -ItemType Directory -Force -Path (Split-Path $OutputPath -Parent) | Out-Null

$iconPath = Join-Path $SourceDir 'branding\stealth-dark.ico'
if (-not (Test-Path $iconPath)) {
    $iconPath = Join-Path $SourceDir 'bundle\assets\stealth-dark.ico'
}
if (-not (Test-Path $iconPath)) { throw "Missing icon: $iconPath" }

$src = Join-Path $SourceDir 'StealthSetup.cs'
if (-not (Test-Path $src)) { throw "Missing StealthSetup.cs" }

$csc = @(
    "${env:WINDIR}\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
    "${env:WINDIR}\Microsoft.NET\Framework\v4.0.30319\csc.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $csc) { throw 'csc.exe not found (.NET Framework 4.x required)' }

$psAutomation = [System.Reflection.Assembly]::LoadWithPartialName('System.Management.Automation').Location
if (-not $psAutomation -or -not (Test-Path $psAutomation)) {
    throw 'System.Management.Automation.dll not found'
}

$payloadForEmbed = Join-Path (Split-Path $OutputPath -Parent) '_setup-payload.zip'
Copy-Item $PayloadZip $payloadForEmbed -Force

try {
    & $csc /nologo /target:winexe /platform:anycpu `
        "/out:$OutputPath" "/win32icon:$iconPath" `
        /reference:System.Windows.Forms.dll `
        /reference:System.IO.Compression.dll `
        /reference:System.IO.Compression.FileSystem.dll `
        "/reference:$psAutomation" `
        "/resource:$payloadForEmbed,StealthBrowser.SetupPayload.zip" `
        $src

    if ($LASTEXITCODE -ne 0) { throw "csc failed with exit code $LASTEXITCODE" }
}
finally {
    Remove-Item $payloadForEmbed -Force -ErrorAction SilentlyContinue
}

$sizeMb = [math]::Round((Get-Item $OutputPath).Length / 1MB, 2)
Write-Host "Built single-file installer: $OutputPath ($sizeMb MB)"
