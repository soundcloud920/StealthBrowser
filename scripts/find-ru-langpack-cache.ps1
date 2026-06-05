$roots = @(
    (Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles\kn9q3hkf.stealth'),
    (Join-Path $env:LOCALAPPDATA 'Mozilla'),
    (Join-Path $env:LOCALAPPDATA 'StealthBrowser')
)
foreach ($root in $roots) {
    if (-not (Test-Path $root)) { continue }
    Get-ChildItem $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'langpack|locale-ru|ru\.xpi' } |
        Select-Object -First 20 FullName
}
