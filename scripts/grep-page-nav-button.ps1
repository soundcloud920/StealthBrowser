Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = 'C:\Users\france\AppData\Local\StealthBrowser\Engine\omni.ja'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
$zip.Entries | Where-Object { $_.FullName -match 'page-nav-button' } | ForEach-Object { $_.FullName }
$zip.Dispose()
