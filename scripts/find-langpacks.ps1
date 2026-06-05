$paths = @(
    (Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles\kn9q3hkf.stealth\langpacks'),
    (Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\browser\localization'),
    (Join-Path ${env:ProgramFiles} 'Mozilla Firefox\browser\features'),
    (Join-Path ${env:ProgramFiles} 'Mozilla Firefox\distribution\extensions')
)
foreach ($p in $paths) {
    Write-Host "=== $p ==="
    if (Test-Path $p) { Get-ChildItem $p -Recurse -ErrorAction SilentlyContinue | Select-Object -First 15 FullName }
    else { Write-Host '(missing)' }
}

# Check if ru langpack in omni localization folder listing
Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\browser\omni.ja'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
$ru = $zip.Entries | Where-Object { $_.FullName -match '^localization/ru/' } | Select-Object -First 10 FullName
Write-Host '=== ru entries in omni ==='
$ru
$zip.Dispose()
