Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\browser\omni.ja'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
$names = $zip.Entries | Where-Object { $_.FullName -match 'appmenu|panelUI' } | ForEach-Object { $_.FullName }
$names | Select-Object -First 20
foreach ($entry in $zip.Entries) {
    if ($entry.FullName -notmatch 'appmenu-viewcache') { continue }
    $sr = New-Object IO.StreamReader($entry.Open())
    $text = $sr.ReadToEnd()
    $sr.Close()
    $text -split "`n" | Select-String 'proton-zap|profiles|separator' | Select-Object -First 25
}
$zip.Dispose()
