$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'Install-Stealth.ps1')
Invoke-StealthSetup -ProfileOnly
