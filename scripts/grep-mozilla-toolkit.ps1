Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\omni.ja'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
foreach ($entry in $zip.Entries) {
    if ($entry.FullName -notmatch 'branding/brand\.(ftl|properties)$') { continue }
    Write-Host "=== $($entry.FullName) ==="
    $sr = New-Object IO.StreamReader($entry.Open())
    $t = $sr.ReadToEnd()
    $sr.Close()
    $t -split "`n" | Select-String 'brand|Mozilla|Firefox' | Select-Object -First 10
}
$zip.Dispose()
