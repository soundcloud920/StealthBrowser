#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$launcherRoot = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { $PSScriptRoot }
. (Join-Path $launcherRoot "Install-Stealth.ps1")

$launcherExe = Get-StealthLauncherExe
if (Test-Path $launcherExe) {
    Start-Process -FilePath $launcherExe | Out-Null
    exit 0
}

$config = Get-StealthLaunchConfig
if (-not $config -or -not (Test-Path $config.StealthExe) -or -not (Test-Path $config.ProfilePath)) {
    Add-Type -AssemblyName System.Windows.Forms
    [void][System.Windows.Forms.MessageBox]::Show(
        "Stealth ne nastroen. Zapustite Setup.cmd.",
        "StealthBrowser",
        "OK",
        "Error"
    )
    exit 1
}

Start-Process -FilePath $config.StealthExe -ArgumentList @(
    "-no-remote", "--allow-downgrade", "-profile", $config.ProfilePath
) | Out-Null
