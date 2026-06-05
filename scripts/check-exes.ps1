$engine = 'C:\Users\france\AppData\Local\StealthBrowser\Engine'
Get-ChildItem $engine -Filter '*.exe' | ForEach-Object {
    $v = [Diagnostics.FileVersionInfo]::GetVersionInfo($_.FullName)
    Write-Host "$($_.Name): $($v.FileDescription)"
}
Get-ChildItem (Join-Path $engine 'browser\VisualElements') -ErrorAction SilentlyContinue | Format-Table Name, Length
