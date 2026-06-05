Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($omni in @(
    (Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\browser\omni.ja'),
    (Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\omni.ja')
)) {
    Write-Host "=== $omni ==="
    $zip = [IO.Compression.ZipFile]::OpenRead($omni)
    $zip.Entries |
        Where-Object { $_.FullName -match 'branding' } |
        ForEach-Object { $_.FullName }
    $zip.Dispose()
}
