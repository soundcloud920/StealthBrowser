Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead('C:\Users\france\AppData\Local\StealthBrowser\Engine\browser\omni.ja')
$zip.Entries | Where-Object { $_.FullName -match '/ru/' } | Select-Object -First 30 FullName
$zip.Dispose()
