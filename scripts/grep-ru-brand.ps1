Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\browser\omni.ja'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
foreach ($entry in $zip.Entries) {
    if ($entry.FullName -notmatch '^localization/ru/') { continue }
    if ($entry.FullName -notmatch 'brand\.(ftl|properties)|browser\.ftl$') { continue }
    Write-Host "=== $($entry.FullName) ==="
    $sr = New-Object IO.StreamReader($entry.Open())
    $t = $sr.ReadToEnd()
    $sr.Close()
    $t -split "`n" | Select-String 'brand|Mozilla|Firefox|Stealth|browser-main-window' | Select-Object -First 15
}
$zip.Dispose()
