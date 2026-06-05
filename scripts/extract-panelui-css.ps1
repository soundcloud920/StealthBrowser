Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\browser\omni.ja'
$out = 'C:\Users\france\uuj-firefox-setup\scripts\_extract'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
foreach ($name in @(
    'chrome/browser/skin/classic/browser/customizableui/panelUI-shared.css',
    'chrome/browser/skin/classic/browser/customizableui/panelUI.css'
)) {
    $dest = Join-Path $out ($name -replace '/', '_')
    [IO.Compression.ZipFileExtensions]::ExtractToFile($zip.GetEntry($name), $dest, $true)
    Write-Host $dest
}
$zip.Dispose()
