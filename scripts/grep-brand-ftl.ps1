Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($omni in @(
    (Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\browser\omni.ja'),
    (Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\omni.ja')
)) {
    Write-Host "=== $omni ==="
    $zip = [IO.Compression.ZipFile]::OpenRead($omni)
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName -notmatch 'brand\.ftl$') { continue }
        $sr = New-Object IO.StreamReader($entry.Open())
        $t = $sr.ReadToEnd()
        $sr.Close()
        Write-Host "--- $($entry.FullName) ---"
        Write-Host $t
    }
    $zip.Dispose()
}
