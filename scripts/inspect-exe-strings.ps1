$engine = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\firefox.exe'
$info = [Diagnostics.FileVersionInfo]::GetVersionInfo($engine)
Write-Host '=== FileVersionInfo ==='
Write-Host "FileDescription: $($info.FileDescription)"
Write-Host "ProductName: $($info.ProductName)"
Write-Host "InternalName: $($info.InternalName)"
Write-Host "OriginalFilename: $($info.OriginalFilename)"
Write-Host "LegalCopyright: $($info.LegalCopyright)"
Write-Host "CompanyName: $($info.CompanyName)"

Write-Host '=== Strings grep Mozilla ==='
$bytes = [IO.File]::ReadAllBytes($engine)
$enc = [Text.Encoding]::Unicode
$ascii = [Text.Encoding]::ASCII
$text = $enc.GetString($bytes)
foreach ($pat in @('Mozilla Firefox', 'Mozilla Corporation', 'Firefox')) {
    if ($text -match [regex]::Escape($pat)) { Write-Host "Found UTF16: $pat" }
}
$textA = $ascii.GetString($bytes)
if ($textA -match 'Mozilla Firefox') { Write-Host 'Found ASCII: Mozilla Firefox' }
