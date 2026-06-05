#Requires -Version 5.1
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here "Install-Stealth.ps1")
$root = Initialize-BundleRoot
$exe = (Get-InstalledStealth).Path
if (-not $exe) {
    throw "Stealth engine not found. Run Setup.cmd first."
}
$profile = Get-StealthProfilePath
if (-not $profile) {
    throw "Stealth profile not found. Run Setup.cmd first."
}
Install-StealthLauncherFiles -InstallScriptDir $here
Install-StealthShortcut -Root $root -StealthExe $exe -ProfilePath $profile
$lnk = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $env:USERPROFILE "Desktop\Stealth.lnk"))
Write-Host "Shortcut created: $($lnk.FullName)"
Write-Host "Target: $($lnk.TargetPath)"
Write-Host "Icon: $($lnk.IconLocation)"
