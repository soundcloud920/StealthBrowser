Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\browser\omni.ja'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
foreach ($name in @('localization/en-US/branding/brand.ftl','localization/en-GB/branding/brand.ftl')) {
    $e = $zip.GetEntry($name)
    Write-Host "=== $name ==="
    $sr = New-Object IO.StreamReader($e.Open())
    Write-Host $sr.ReadToEnd()
    $sr.Close()
}
$zip.Dispose()
