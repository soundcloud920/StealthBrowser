#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$bundleDir = Join-Path $root "bundle"
$out = Join-Path $root "bundle.zip"

if (-not (Test-Path (Join-Path $bundleDir "templates\user.js"))) {
    throw "Missing bundle/templates/user.js"
}

if (Test-Path $out) { Remove-Item $out -Force }
Compress-Archive -Path (Join-Path $bundleDir "*") -DestinationPath $out -Force
Write-Host "Created: $out"
