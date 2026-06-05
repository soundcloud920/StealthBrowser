$engine = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\firefox.exe'
$bytes = [IO.File]::ReadAllBytes($engine)
$u = [Text.Encoding]::Unicode.GetString($bytes)
[regex]::Matches($u, 'Software\\Mozilla\\[A-Za-z]+\\TaskBarIDs') |
    ForEach-Object { $_.Value } | Select-Object -Unique
