$engine = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\firefox.exe'
$bytes = [IO.File]::ReadAllBytes($engine)
$ascii = [Text.Encoding]::ASCII.GetString($bytes)
$utf = [Text.Encoding]::Unicode.GetString($bytes)
if ($ascii -match '308046B0AF4A39CB') { Write-Host 'ASCII: found 308046B0AF4A39CB' }
if ($utf -match '308046B0AF4A39CB') { Write-Host 'UTF16: found 308046B0AF4A39CB' }
if ($ascii -match 'Mozilla Firefox') { Write-Host 'ASCII: found Mozilla Firefox' }
if ($utf -match 'Mozilla Firefox') { Write-Host 'UTF16: found Mozilla Firefox' }
