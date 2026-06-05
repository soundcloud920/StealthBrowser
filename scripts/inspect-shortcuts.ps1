$paths = @(
    (Join-Path $env:USERPROFILE 'Desktop\Stealth.lnk'),
    (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Stealth.lnk'),
    (Join-Path $env:USERPROFILE 'Desktop\firefox.lnk'),
    (Join-Path $env:USERPROFILE 'Desktop\Mozilla Firefox.lnk')
)
$shell = New-Object -ComObject WScript.Shell
foreach ($p in $paths) {
    if (-not (Test-Path $p)) { Write-Host "MISSING $p"; continue }
    $sc = $shell.CreateShortcut($p)
    Write-Host "=== $p ==="
    Write-Host "Target: $($sc.TargetPath)"
    Write-Host "Args: $($sc.Arguments)"
    Write-Host "Icon: $($sc.IconLocation)"
    Write-Host "Desc: $($sc.Description)"
}
