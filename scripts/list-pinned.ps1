$pinnedDir = Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar'
if (-not (Test-Path $pinnedDir)) { Write-Host 'No pinned dir'; exit }
$shell = New-Object -ComObject WScript.Shell
Get-ChildItem $pinnedDir -Filter '*.lnk' | ForEach-Object {
    $sc = $shell.CreateShortcut($_.FullName)
    Write-Host "=== $($_.Name) ==="
    Write-Host "Target: $($sc.TargetPath)"
    Write-Host "Args: $($sc.Arguments)"
    Write-Host "Icon: $($sc.IconLocation)"
}
