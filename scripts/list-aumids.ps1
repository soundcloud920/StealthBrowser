Get-ChildItem 'HKCU:\Software\Classes\AppUserModelId' |
    ForEach-Object {
        $id = $_.PSChildName
        $p = Get-ItemProperty $_.PSPath
        Write-Host "$id => $($p.'(default)') icon=$($p.IconResource)"
    }
