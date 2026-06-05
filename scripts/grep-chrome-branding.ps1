Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\browser\omni.ja'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
foreach ($entry in $zip.Entries) {
    if ($entry.FullName -notmatch 'chrome/.*/locale/branding/brand\.(ftl|properties)$') { continue }
    Write-Host "=== $($entry.FullName) ==="
    $sr = New-Object IO.StreamReader($entry.Open())
    Write-Host $sr.ReadToEnd()
    $sr.Close()
}
$zip.Dispose()
