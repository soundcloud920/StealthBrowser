Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\omni.ja'
$dest = 'C:\Users\france\uuj-firefox-setup\scripts\_extract\toolbar.css'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
[IO.Compression.ZipFileExtensions]::ExtractToFile($zip.GetEntry('chrome/toolkit/skin/classic/global/toolbar.css'), $dest, $true)
$zip.Dispose()
