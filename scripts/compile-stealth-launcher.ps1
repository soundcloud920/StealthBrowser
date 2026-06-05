#Requires -Version 5.1
param(
    [string]$SourceDir,
    [string]$IconPath,
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

if (-not $SourceDir) {
    $SourceDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}
if (-not $IconPath) {
    $IconPath = Join-Path $SourceDir "branding\stealth-dark.ico"
    if (-not (Test-Path $IconPath)) {
        $IconPath = Join-Path $SourceDir "bundle\assets\stealth-dark.ico"
    }
}
if (-not $OutputPath) {
    $OutputPath = Join-Path $SourceDir "Stealth.exe"
}

$src = Join-Path $SourceDir "StealthLauncher.cs"
if (-not (Test-Path $src)) { throw "Missing StealthLauncher.cs" }
if (-not (Test-Path $IconPath)) { throw "Missing icon: $IconPath" }

$csc = @(
    "${env:WINDIR}\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
    "${env:WINDIR}\Microsoft.NET\Framework\v4.0.30319\csc.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $csc) { throw "csc.exe not found (.NET Framework required)" }

$outDir = Split-Path $OutputPath -Parent
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

& $csc /nologo /target:winexe /platform:anycpu `
    "/out:$OutputPath" "/win32icon:$IconPath" `
    /reference:System.Windows.Forms.dll `
    $src

if ($LASTEXITCODE -ne 0) { throw "csc failed with exit code $LASTEXITCODE" }
Write-Host "Built: $OutputPath"
