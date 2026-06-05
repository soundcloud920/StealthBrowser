Get-CimInstance Win32_Process -Filter "Name='firefox.exe'" |
    ForEach-Object {
        Write-Host "PID=$($_.ProcessId)"
        Write-Host "  Path=$($_.ExecutablePath)"
        Write-Host "  Cmd=$($_.CommandLine)"
    }
