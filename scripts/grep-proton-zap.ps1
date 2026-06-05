Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\browser\omni.ja'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
foreach ($entry in $zip.Entries) {
    if ($entry.Length -gt 800000) { continue }
    if ($entry.FullName -notmatch '\.(css|xhtml|inc\.xhtml)$') { continue }
    $sr = New-Object IO.StreamReader($entry.Open())
    $text = $sr.ReadToEnd()
    $sr.Close()
    if ($text -match 'proton-zap') {
        Write-Host $entry.FullName
        $text -split "`n" | Select-String 'proton-zap' | Select-Object -First 5
    }
}
$zip.Dispose()
