Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\browser\omni.ja'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
foreach ($entry in $zip.Entries) {
    if ($entry.FullName -notmatch 'branding/brand\.(ftl|properties)$') { continue }
    $sr = New-Object IO.StreamReader($entry.Open())
    $t = $sr.ReadToEnd()
    $sr.Close()
    if ($t -match 'Mozilla Firefox|brandFullName|brandShorterName') {
        Write-Host "=== $($entry.FullName) ==="
        $t -split "`n" | Select-String 'brand|Mozilla|Firefox' | Select-Object -First 8
    }
}
$zip.Dispose()
