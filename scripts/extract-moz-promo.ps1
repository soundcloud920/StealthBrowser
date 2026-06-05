Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = 'C:\Users\france\AppData\Local\StealthBrowser\Engine\omni.ja'
$out = 'C:\Users\france\uuj-firefox-setup\scripts\_extract'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
foreach ($name in @(
    'chrome/toolkit/content/global/elements/moz-promo.css',
    'chrome/toolkit/content/global/elements/moz-promo.mjs'
)) {
    $e = $zip.GetEntry($name)
    if ($e) {
        $dest = Join-Path $out ($name -replace '/', '_')
        [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $dest, $true)
        Write-Host $dest
    }
}
$zip.Dispose()
