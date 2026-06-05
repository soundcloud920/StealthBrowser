$dirs = @(
    'C:\Users\france\AppData\Local\StealthBrowser\Engine\browser\omni.ja',
    'C:\Users\france\AppData\Local\StealthBrowser\Engine\omni.ja'
)
Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($omni in $dirs) {
    if (-not (Test-Path $omni)) { continue }
    Write-Host "=== $omni ==="
    $zip = [IO.Compression.ZipFile]::OpenRead($omni)
    $zip.Entries |
        Where-Object { $_.FullName -match 'kit-happy|moz-promo|illustrations' } |
        ForEach-Object { $_.FullName }
    $zip.Dispose()
}
