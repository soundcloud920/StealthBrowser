Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = 'C:\Users\france\AppData\Local\StealthBrowser\Engine\omni.ja'
$dest = 'C:\Users\france\uuj-firefox-setup\scripts\_extract\kit-happy.svg'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
$e = $zip.GetEntry('chrome/toolkit/skin/classic/global/illustrations/kit-happy.svg')
[IO.Compression.ZipFileExtensions]::ExtractToFile($e, $dest, $true)
$zip.Dispose()
Get-Content $dest -Raw
