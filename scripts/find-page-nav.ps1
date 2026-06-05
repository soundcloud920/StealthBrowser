Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($omni in @(
    'C:\Users\france\AppData\Local\StealthBrowser\Engine\browser\omni.ja',
    'C:\Users\france\AppData\Local\StealthBrowser\Engine\omni.ja'
)) {
    Write-Host "=== $omni ==="
    $zip = [IO.Compression.ZipFile]::OpenRead($omni)
    $zip.Entries | Where-Object { $_.FullName -match 'page-nav|moz-page-nav' } | ForEach-Object { $_.FullName }
    $zip.Dispose()
}
