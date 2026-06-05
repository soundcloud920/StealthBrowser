Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\omni.ja'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
foreach ($name in @(
    'chrome/toolkit/content/global/elements/moz-promo.css',
    'chrome/toolkit/content/global/elements/moz-page-nav-button.css',
    'chrome/toolkit/content/global/elements/moz-page-nav.css'
)) {
    $sr = New-Object IO.StreamReader($zip.GetEntry($name).Open())
    $text = $sr.ReadToEnd()
    $sr.Close()
    $has = $text -match 'Stealth: monochrome'
    Write-Host "$name : $has"
}
$zip.Dispose()
