Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = 'C:\Users\france\AppData\Local\StealthBrowser\Engine\browser\omni.ja'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
$zip.Entries | Where-Object { $_.FullName -match 'ru.*/branding/' } | ForEach-Object { $_.FullName }
$zip.Dispose()

$paths = @(
    'C:\Program Files\Mozilla Firefox\browser\features',
    'C:\Program Files\Mozilla Firefox\distribution\extensions',
    "$env:APPDATA\Mozilla\Firefox\Profiles\kn9q3hkf.stealth"
)
foreach ($p in $paths) {
    if (-not (Test-Path $p)) { continue }
    Get-ChildItem $p -Recurse -Filter '*ru*' -ErrorAction SilentlyContinue | Select-Object -First 10 FullName
}
