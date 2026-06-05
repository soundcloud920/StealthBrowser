# CityHash64 for Firefox install path - try reading from installs.ini / registry first
$engineDir = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine'
Write-Host "Engine dir: $engineDir"

foreach ($reg in @('HKCU:\Software\Mozilla\Firefox\TaskBarIDs', 'HKLM:\Software\Mozilla\Firefox\TaskBarIDs')) {
    if (Test-Path $reg) {
        $props = Get-ItemProperty $reg
        foreach ($name in $props.PSObject.Properties.Name) {
            if ($name -match '^PS') { continue }
            if ($name -eq $engineDir) { Write-Host "TaskBarIDs $reg => $($props.$name)" }
        }
    }
}

$installs = Join-Path $env:APPDATA 'Mozilla\Firefox\installs.ini'
if (Test-Path $installs) { Write-Host '=== installs.ini ==='; Get-Content $installs }
