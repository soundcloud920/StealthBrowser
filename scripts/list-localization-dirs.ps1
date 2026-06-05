Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\browser\omni.ja'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
$zip.Entries |
    Where-Object { $_.FullName -match '^localization/[^/]+/$' } |
    ForEach-Object { $_.FullName } |
    Sort-Object -Unique
# list top-level locale dirs
$locales = $zip.Entries | ForEach-Object {
    if ($_.FullName -match '^localization/([^/]+)/') { $Matches[1] }
} | Sort-Object -Unique
Write-Host 'Locales:' ($locales -join ', ')
$zip.Dispose()
