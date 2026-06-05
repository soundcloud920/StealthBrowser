Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($omni in @(
    'C:\Users\france\AppData\Local\StealthBrowser\Engine\browser\omni.ja',
    'C:\Users\france\AppData\Local\StealthBrowser\Engine\omni.ja'
)) {
    Write-Host "=== $omni ==="
    $zip = [IO.Compression.ZipFile]::OpenRead($omni)
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName -notmatch '\.(mjs|js)$') { continue }
        if ($entry.Length -gt 500000) { continue }
        $sr = New-Object IO.StreamReader($entry.Open())
        $text = $sr.ReadToEnd()
        $sr.Close()
        if ($text -match 'moz-page-nav-button') {
            Write-Host $entry.FullName
        }
    }
    $zip.Dispose()
}
