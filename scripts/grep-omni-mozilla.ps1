Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\browser\omni.ja'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
foreach ($entry in $zip.Entries) {
    if ($entry.Length -gt 400000) { continue }
    $sr = New-Object IO.StreamReader($entry.Open())
    $t = $sr.ReadToEnd()
    $sr.Close()
    if ($t -match 'Mozilla Firefox') {
        Write-Host $entry.FullName
        $t -split "`n" | Select-String 'Mozilla Firefox' | Select-Object -First 3
    }
}
$zip.Dispose()
