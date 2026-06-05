#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$script:InstallScriptDir = $repoRoot

. (Join-Path $repoRoot "Stealth-Update.ps1")
Install-StealthLauncherFiles -InstallScriptDir $repoRoot

powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "scripts\repair-default-browser.ps1")
