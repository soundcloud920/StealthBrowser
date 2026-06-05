$ids = @('308046B0AF4A39CB', 'StealthBrowser.Stealth', 'Firefox-308046B0AF4A39CB')
foreach ($root in @('HKCU', 'HKLM')) {
    foreach ($id in $ids) {
        $path = "$root`:\Software\Classes\AppUserModelId\$id"
        if (Test-Path $path) {
            $v = (Get-ItemProperty $path -ErrorAction SilentlyContinue).'(default)'
            $icon = (Get-ItemProperty $path -ErrorAction SilentlyContinue).IconResource
            Write-Host "$path => name=$v icon=$icon"
        }
    }
}

Write-Host '=== ProgId Firefox ==='
Get-ItemProperty 'HKLM:\Software\Classes\FirefoxURL' -ErrorAction SilentlyContinue | Select-Object '(default)', FriendlyTypeName
Get-ItemProperty 'HKCU:\Software\Classes\FirefoxURL' -ErrorAction SilentlyContinue | Select-Object '(default)', FriendlyTypeName
