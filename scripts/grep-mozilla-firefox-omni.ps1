Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\browser\omni.ja'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
$count = 0
foreach ($entry in $zip.Entries) {
    if ($entry.Length -gt 200000) { continue }
    $sr = New-Object IO.StreamReader($entry.Open())
    $t = $sr.ReadToEnd()
    $sr.Close()
    if ($t -match 'Mozilla Firefox') {
        Write-Host $entry.FullName
        $count++
        if ($count -ge 40) { Write-Host '...truncated'; break }
    }
}
Write-Host "Total with Mozilla Firefox: $count"
$zip.Dispose()
