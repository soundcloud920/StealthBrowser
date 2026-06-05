Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = 'C:\Users\france\AppData\Local\StealthBrowser\Engine\browser\omni.ja'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
$zip.Entries |
    Where-Object { $_.FullName -match 'preferences.*\.(css|mjs|xhtml)$' } |
    ForEach-Object { $_.FullName }
$zip.Dispose()
