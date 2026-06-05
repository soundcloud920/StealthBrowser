$profile = 'C:\Users\france\AppData\Roaming\Mozilla\Firefox\Profiles\kn9q3hkf.stealth'
$engine = 'C:\Users\france\AppData\Local\StealthBrowser\Engine'

Write-Host '=== TaskBarIDs ==='
foreach ($reg in @('HKCU:\Software\Mozilla\Firefox\TaskBarIDs', 'HKLM:\Software\Mozilla\Firefox\TaskBarIDs')) {
    if (-not (Test-Path $reg)) { continue }
    Get-ItemProperty $reg | Get-Member -MemberType NoteProperty |
        Where-Object { $_.Name -notmatch '^PS' } |
        ForEach-Object {
            $name = $_.Name
            $val = (Get-ItemProperty $reg).$name
            Write-Host "[$reg] $name => $val"
        }
}

Write-Host '=== AppUserModelId names (firefox/stealth) ==='
Get-ChildItem 'HKCU:\Software\Classes\AppUserModelId' -ErrorAction SilentlyContinue |
    ForEach-Object {
        $id = $_.PSChildName
        if ($id -notmatch '308046|7FDD|Firefox|Stealth|Mozilla') { return }
        $v = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).'(default)'
        Write-Host "$id => $v"
    }

Write-Host '=== StartMenuInternet ==='
Get-ChildItem 'HKLM:\Software\Clients\StartMenuInternet' -ErrorAction SilentlyContinue |
    Where-Object { $_.PSChildName -match 'Firefox|308046|7FDD' } |
    ForEach-Object {
        $cap = Join-Path $_.PSPath 'Capabilities'
        $name = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).'(default)'
        $app = if (Test-Path $cap) { (Get-ItemProperty $cap -ErrorAction SilentlyContinue).ApplicationName } else { '' }
        Write-Host "$($_.PSChildName): default=$name ApplicationName=$app"
    }

Write-Host '=== Running firefox ==='
Get-CimInstance Win32_Process -Filter "Name='firefox.exe'" -ErrorAction SilentlyContinue |
    Select-Object ProcessId, ExecutablePath | Format-Table -AutoSize

Write-Host '=== Profile locale ==='
Select-String -Path (Join-Path $profile 'user.js') -Pattern 'intl.locale' -ErrorAction SilentlyContinue

Write-Host '=== omni en-GB brand ==='
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead((Join-Path $engine 'browser\omni.ja'))
$e = $zip.GetEntry('chrome/en-GB/locale/branding/brand.properties')
$sr = New-Object IO.StreamReader($e.Open())
Write-Host $sr.ReadToEnd()
$sr.Close()
$zip.Dispose()
