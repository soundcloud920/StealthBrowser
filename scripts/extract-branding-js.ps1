Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($item in @(
    @{ Omni = 'browser\omni.ja'; Entry = 'defaults/preferences/firefox-branding.js' },
    @{ Omni = 'omni.ja'; Entry = 'localization/en-US/toolkit/branding/brandings.ftl' },
    @{ Omni = 'omni.ja'; Entry = 'localization/en-GB/toolkit/branding/brandings.ftl' }
)) {
    $path = Join-Path $env:LOCALAPPDATA "StealthBrowser\Engine\$($item.Omni)"
    $zip = [IO.Compression.ZipFile]::OpenRead($path)
    $e = $zip.GetEntry($item.Entry)
    Write-Host "=== $($item.Entry) ==="
    $sr = New-Object IO.StreamReader($e.Open())
    Write-Host $sr.ReadToEnd()
    $sr.Close()
    $zip.Dispose()
}
