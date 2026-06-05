$exe = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\firefox.exe'
$bytes = [IO.File]::ReadAllBytes($exe)
$utf = [Text.Encoding]::Unicode.GetString($bytes)
$idx = 0
while (($idx = $utf.IndexOf('Mozilla Firefox', $idx)) -ge 0) {
    Write-Host "UTF16 offset $idx"
    $idx++
}
$ascii = [Text.Encoding]::ASCII.GetString($bytes)
$idx = 0
while (($idx = $ascii.IndexOf('Mozilla Firefox', $idx)) -ge 0) {
    Write-Host "ASCII offset $idx"
    $idx++
}
