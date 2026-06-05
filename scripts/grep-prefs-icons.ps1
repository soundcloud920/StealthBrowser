Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = 'C:\Users\france\AppData\Local\StealthBrowser\Engine\browser\omni.ja'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
$entries = @(
    'chrome/browser/content/browser/preferences/preferences.xhtml',
    'chrome/browser/content/browser/preferences/config/SettingPaneManager.mjs'
)
foreach ($name in $entries) {
    $e = $zip.GetEntry($name)
    if (-not $e) { Write-Host "missing $name"; continue }
    $sr = New-Object IO.StreamReader($e.Open())
    $text = $sr.ReadToEnd()
    $sr.Close()
    Write-Host "=== $name ==="
    $text -split "`n" | Select-String -Pattern 'iconsrc|iconSrc|category-|firefox-labs|mozilla' | Select-Object -First 30
}
$zip.Dispose()
