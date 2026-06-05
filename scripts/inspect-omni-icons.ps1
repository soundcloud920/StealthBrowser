Add-Type -AssemblyName System.IO.Compression.FileSystem
$engine = 'C:\Users\france\AppData\Local\StealthBrowser\Engine\browser\omni.ja'
$source = 'C:\Program Files\Mozilla Firefox\browser\omni.ja'
foreach ($path in @($engine, $source)) {
    if (-not (Test-Path $path)) { Write-Host "MISSING $path"; continue }
    Write-Host "=== $path ==="
    $zip = [IO.Compression.ZipFile]::OpenRead($path)
    foreach ($name in @('chrome/browser/content/branding/icon16.png', 'chrome/browser/content/branding/icon32.png')) {
        $e = $zip.GetEntry($name)
        if ($e) { Write-Host "$name length=$($e.Length)" }
    }
    $zip.Dispose()
}
