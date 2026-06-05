Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\browser\omni.ja'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
$zip.Entries | Where-Object { $_.FullName -match 'application\.ini$' } | ForEach-Object { $_.FullName }
$zip.Dispose()
