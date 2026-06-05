$ids = @('StealthBrowser.Stealth', '308046B0AF4A39CB', 'Firefox-308046B0AF4A39CB', '7FDD1D39F7222CD')
foreach ($id in $ids) {
    $path = "HKCU:\Software\Classes\AppUserModelId\$id"
    Write-Host "=== $id ==="
    if (-not (Test-Path $path)) { Write-Host '  (missing)'; continue }
    Get-ItemProperty $path | Get-Member -MemberType NoteProperty |
        Where-Object { $_.Name -notmatch '^PS' } |
        ForEach-Object {
            $n = $_.Name
            Write-Host "  $n = $((Get-ItemProperty $path).$n)"
        }
}

Write-Host '=== Mozilla Stealth TaskBarIDs ==='
$stealthKey = 'HKCU:\Software\Mozilla\Stealth\TaskBarIDs'
if (Test-Path $stealthKey) { Get-ItemProperty $stealthKey } else { Write-Host 'missing' }

Write-Host '=== Engine policies.json ==='
$pol = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\distribution\policies.json'
if (Test-Path $pol) { Get-Content $pol -Raw } else { Write-Host 'missing' }
