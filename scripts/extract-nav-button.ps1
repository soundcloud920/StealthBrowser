Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = 'C:\Users\france\AppData\Local\StealthBrowser\Engine\omni.ja'
$dest = 'C:\Users\france\uuj-firefox-setup\scripts\_extract\moz-page-nav-button.mjs'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
[IO.Compression.ZipFileExtensions]::ExtractToFile($zip.GetEntry('chrome/toolkit/content/global/elements/moz-page-nav-button.mjs'), $dest, $true)
$zip.Dispose()
