$engineDir = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine'
Write-Host "Looking for registry entries for: $engineDir"
foreach ($root in @('HKCU', 'HKLM')) {
    foreach ($sub in @(
        'Software\Mozilla\Firefox\TaskBarIDs',
        'Software\Mozilla\Firefox\InstallHashes',
        'Software\Mozilla\Mozilla Firefox\TaskBarIDs'
    )) {
        $path = "$root`:\$sub"
        if (-not (Test-Path $path)) { continue }
        Write-Host "=== $path ==="
        $props = Get-ItemProperty $path
        foreach ($name in $props.PSObject.Properties.Name) {
            if ($name -match '^PS') { continue }
            if ($name -like '*StealthBrowser*' -or $name -like '*Engine*' -or $props.$name -like '*Stealth*') {
                Write-Host "  [$name] = $($props.$name)"
            }
        }
    }
}
