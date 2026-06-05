Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($omni in @(
    (Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\browser\omni.ja'),
    (Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\omni.ja')
)) {
    $zip = [IO.Compression.ZipFile]::OpenRead($omni)
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName -notmatch 'toolbar\.css|toolbarbuttons\.css') { continue }
        $sr = New-Object IO.StreamReader($entry.Open())
        $text = $sr.ReadToEnd()
        $sr.Close()
        Write-Host "=== $($entry.FullName) ==="
        $text -split "`n" | Select-String 'toolbarseparator' | Select-Object -First 20
    }
    $zip.Dispose()
}
