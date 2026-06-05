$engine = 'C:\Users\france\AppData\Local\StealthBrowser\Engine\firefox.exe'
$pf = 'C:\Program Files\Mozilla Firefox\firefox.exe'

foreach ($path in @($engine, $pf)) {
    if (-not (Test-Path $path)) { Write-Host "MISSING $path"; continue }
    $i = [Diagnostics.FileVersionInfo]::GetVersionInfo($path)
    Write-Host "--- $path"
    Write-Host "FileDescription: $($i.FileDescription)"
    Write-Host "ProductName: $($i.ProductName)"
}

Write-Host '--- running firefox processes'
Get-Process firefox -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "$($_.Id): $($_.Path)"
}

foreach ($reg in @(
        'HKCU:\Software\Mozilla\Firefox\TaskBarIDs',
        'HKLM:\Software\Mozilla\Firefox\TaskBarIDs'
    )) {
    if (-not (Test-Path $reg)) { continue }
    Write-Host "--- $reg"
    Get-ItemProperty $reg | Format-List *
}

Get-ChildItem 'HKCU:\Software\Classes\AppUserModelId' -ErrorAction SilentlyContinue |
    Where-Object { $_.PSChildName -match 'Firefox|Stealth|Mozilla' } |
    ForEach-Object {
        $name = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).'(default)'
        Write-Host "AUMID $($_.PSChildName) => $name"
    }
