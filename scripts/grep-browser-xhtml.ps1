Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\browser\omni.ja'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
foreach ($entry in $zip.Entries) {
    if ($entry.FullName -notmatch 'browser\.xhtml$') { continue }
    $sr = New-Object IO.StreamReader($entry.Open())
    $t = $sr.ReadToEnd()
    $sr.Close()
    $t -split "`n" | Select-String 'title|brand|Mozilla' | Select-Object -First 20
}
$zip.Dispose()
