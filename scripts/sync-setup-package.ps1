#Requires -Version 5.1
# Copy setup scripts to %LOCALAPPDATA%\StealthBrowser\SetupPackage with UTF-8 BOM (PS 5.1).
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$dest = Join-Path $env:LOCALAPPDATA 'StealthBrowser\SetupPackage'
if (-not (Test-Path $dest)) {
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
}

$utf8Bom = New-Object System.Text.UTF8Encoding $true
foreach ($name in @('Setup.ps1', 'Install-Stealth.ps1', 'version.json')) {
    $src = Join-Path $root $name
    if (-not (Test-Path $src)) { throw "Missing: $src" }
    $text = [IO.File]::ReadAllText($src)
    [IO.File]::WriteAllText((Join-Path $dest $name), $text, $utf8Bom)
    Write-Host "Synced: $name"
}

$errors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $dest 'Install-Stealth.ps1'), [ref]$null, [ref]$errors)
if ($errors) {
    $errors | ForEach-Object { Write-Host $_.ToString() }
    throw 'Install-Stealth.ps1 has parse errors'
}
Write-Host 'Parse OK'
