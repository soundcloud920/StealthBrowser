Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead('C:\Users\france\AppData\Local\StealthBrowser\Engine\browser\omni.ja')
$zip.Entries | Where-Object { $_.FullName -match 'branding/brand\.(ftl|properties)$' } | ForEach-Object { $_.FullName }
$zip.Dispose()
