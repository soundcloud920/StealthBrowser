Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\browser\omni.ja'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
foreach ($entry in $zip.Entries) {
    if ($entry.FullName -notmatch 'browser\.ftl$') { continue }
    $sr = New-Object IO.StreamReader($entry.Open())
    $t = $sr.ReadToEnd()
    $sr.Close()
    if ($t -match 'Mozilla Firefox') {
        Write-Host "=== $($entry.FullName) HAS Mozilla Firefox ==="
    }
    if ($t -match 'browser-main-window') {
        Write-Host "--- $($entry.FullName) ---"
        $t -split "`n" | Select-String 'browser-main-window|brand-full' | Select-Object -First 8
    }
}
$zip.Dispose()
