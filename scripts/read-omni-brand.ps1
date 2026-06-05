Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead('C:\Users\france\AppData\Local\StealthBrowser\Engine\browser\omni.ja')
foreach ($name in @(
        'localization/en-US/branding/brand.ftl',
        'localization/ru/branding/brand.ftl',
        'chrome/ru/locale/branding/brand.properties',
        'defaults/preferences/firefox-branding.js'
    )) {
    $entry = $zip.GetEntry($name)
    if (-not $entry) { Write-Host "MISSING $name"; continue }
    $sr = New-Object IO.StreamReader($entry.Open())
    Write-Host "=== $name ==="
    Write-Host $sr.ReadToEnd()
    $sr.Close()
}
$zip.Dispose()
