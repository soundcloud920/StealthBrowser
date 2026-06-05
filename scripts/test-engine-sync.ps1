$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'Install-Stealth.ps1')
$exe = Sync-StealthEngine -Version '151.0.3'
$info = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($exe)
Write-Host "Engine: $exe"
Write-Host "FileDescription: $($info.FileDescription)"
Write-Host "ProductName: $($info.ProductName)"
