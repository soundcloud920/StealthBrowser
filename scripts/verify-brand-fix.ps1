Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead('C:\Users\france\AppData\Local\StealthBrowser\Engine\browser\omni.ja')
$e = $zip.GetEntry('chrome/en-GB/locale/branding/brand.properties')
$sr = New-Object IO.StreamReader($e.Open())
Write-Host $sr.ReadToEnd()
$sr.Close()
$zip.Dispose()

$engine = 'C:\Users\france\AppData\Local\StealthBrowser\Engine'
foreach ($name in @('firefox.exe', 'plugin-container.exe')) {
    $v = [Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $engine $name))
    Write-Host "$name => $($v.FileDescription)"
}
