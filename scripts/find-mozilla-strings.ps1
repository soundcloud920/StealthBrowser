Add-Type -AssemblyName System.IO.Compression.FileSystem
$engine = 'C:\Users\france\AppData\Local\StealthBrowser\Engine'
$files = @(
    (Join-Path $engine 'browser\omni.ja'),
    (Join-Path $engine 'omni.ja')
) | Where-Object { Test-Path $_ }

foreach ($path in $files) {
    Write-Host "=== $path ==="
    $zip = [IO.Compression.ZipFile]::OpenRead($path)
    foreach ($e in $zip.Entries) {
        if ($e.Length -gt 500000) { continue }
        if ($e.FullName -notmatch '\.(ftl|properties|dtd|json|xml|js|html|xhtml)$') { continue }
        $sr = New-Object IO.StreamReader($e.Open())
        $t = $sr.ReadToEnd()
        $sr.Close()
        if ($t -match 'Mozilla Firefox') {
            Write-Host $e.FullName
        }
    }
    $zip.Dispose()
}

Get-ChildItem (Join-Path $engine 'browser\features') -Filter '*.xpi' -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "=== xpi $($_.Name) ==="
    $zip = [IO.Compression.ZipFile]::OpenRead($_.FullName)
    foreach ($e in $zip.Entries) {
        if ($e.FullName -notmatch 'brand') { continue }
        $sr = New-Object IO.StreamReader($e.Open())
        $t = $sr.ReadToEnd()
        $sr.Close()
        Write-Host $e.FullName
        ($t -split "`n" | Where-Object { $_ -match 'brand|Mozilla' }) | ForEach-Object { Write-Host "  $($_.Trim())" }
    }
    $zip.Dispose()
}
