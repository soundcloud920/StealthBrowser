$engine = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\firefox.exe'
$bytes = [IO.File]::ReadAllBytes($engine)
$text = [Text.Encoding]::Unicode.GetString($bytes)
foreach ($pat in @('application.userModel', 'appUserModelId', '308046B0AF4A39CB', 'StealthBrowser', 'Mozilla Firefox')) {
    if ($text -match [regex]::Escape($pat)) { Write-Host "UTF16 hit: $pat" }
}
$ascii = [Text.Encoding]::ASCII.GetString($bytes)
foreach ($pat in @('application.userModel', '308046B0AF4A39CB', 'Mozilla Firefox')) {
    if ($ascii -match [regex]::Escape($pat)) { Write-Host "ASCII hit: $pat" }
}
