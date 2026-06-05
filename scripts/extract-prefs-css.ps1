Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = 'C:\Users\france\AppData\Local\StealthBrowser\Engine\browser\omni.ja'
$out = 'C:\Users\france\uuj-firefox-setup\scripts\_extract\preferences.css'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
$e = $zip.GetEntry('chrome/browser/skin/classic/browser/preferences/preferences.css')
[IO.Compression.ZipFileExtensions]::ExtractToFile($e, $out, $true)
$zip.Dispose()
