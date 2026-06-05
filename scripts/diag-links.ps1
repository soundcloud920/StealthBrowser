$ErrorActionPreference = 'Continue'

$cfg = Join-Path $env:LOCALAPPDATA 'StealthBrowser\config.json'
Write-Host '=== config.json ==='
if (Test-Path $cfg) {
    Get-Content $cfg -Raw
}
else {
    Write-Host 'MISSING'
}

Write-Host ''
Write-Host '=== Stealth.exe launcher ==='
$launcher = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Stealth.exe'
Write-Host "Path: $launcher  Exists: $(Test-Path $launcher)"

Write-Host ''
Write-Host '=== engine ==='
$engine = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\firefox.exe'
Write-Host "Path: $engine  Exists: $(Test-Path $engine)"

Write-Host ''
Write-Host '=== running firefox processes ==='
Get-CimInstance Win32_Process -Filter "Name='firefox.exe'" -ErrorAction SilentlyContinue |
    Select-Object ProcessId, CommandLine | Format-List

Write-Host '=== UserChoice http/https ==='
foreach ($scheme in @('http', 'https')) {
    $p = "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\$scheme\UserChoice"
    $progId = (Get-ItemProperty $p -ErrorAction SilentlyContinue).ProgId
    Write-Host "$scheme => $progId"
}
