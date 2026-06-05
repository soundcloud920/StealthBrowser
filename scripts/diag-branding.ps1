$ErrorActionPreference = 'Continue'
$engine = 'C:\Users\france\AppData\Local\StealthBrowser\Engine'

Write-Host '=== Running firefox processes ==='
Get-CimInstance Win32_Process -Filter "Name='firefox.exe'" |
    Select-Object ProcessId, ExecutablePath, CommandLine |
    Format-List

Write-Host '=== Engine stamps ==='
@('.engine-version', '.omni-branded') | ForEach-Object {
    $p = Join-Path $engine $_
    if (Test-Path $p) { Write-Host "$_ = $((Get-Content $p -Raw).Trim())" } else { Write-Host "$_ MISSING" }
}

Write-Host '=== firefox.exe version info ==='
$i = [Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $engine 'firefox.exe'))
Write-Host "FileDescription=$($i.FileDescription) ProductName=$($i.ProductName)"

Write-Host '=== VisualElements manifest ==='
Get-Content (Join-Path $engine 'firefox.VisualElementsManifest.xml') -ErrorAction SilentlyContinue

Write-Host '=== Profile prefs (brand related) ==='
$prof = 'C:\Users\france\AppData\Roaming\Mozilla\Firefox\Profiles\kn9q3hkf.stealth'
Select-String -Path (Join-Path $prof 'prefs.js') -Pattern 'blankWindow|taskbar|locale|intl' -ErrorAction SilentlyContinue |
    Select-Object -First 15 Line

Write-Host '=== user.js taskbar prefs ==='
Select-String -Path (Join-Path $prof 'user.js') -Pattern 'blankWindow|taskbar' -ErrorAction SilentlyContinue

Write-Host '=== Langpacks in engine ==='
Get-ChildItem (Join-Path $engine 'browser\features') -Filter '*.xpi' -ErrorAction SilentlyContinue | Select-Object Name

Write-Host '=== Search Mozilla Firefox in engine omni + jars ==='
Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = Join-Path $engine 'browser\omni.ja'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
$hits = $zip.Entries | Where-Object { $_.FullName -match 'brand\.(ftl|properties)$' }
foreach ($e in $hits) {
    $sr = New-Object IO.StreamReader($e.Open())
    $t = $sr.ReadToEnd()
    $sr.Close()
    if ($t -match 'Mozilla Firefox|brand-full-name') {
        Write-Host "--- $($e.FullName) ---"
        ($t -split "`n" | Where-Object { $_ -match 'brand-' -or $_ -match 'brandFull' }) | ForEach-Object { Write-Host $_.Trim() }
    }
}
$zip.Dispose()
