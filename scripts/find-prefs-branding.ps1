Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = 'C:\Users\france\AppData\Local\StealthBrowser\Engine\browser\omni.ja'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
$zip.Entries |
    Where-Object { $_.FullName -match 'preferences|defaultBrowser|default-browser|spotlight' } |
    Select-Object -First 40 FullName
$zip.Dispose()
