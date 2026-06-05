#Requires -Version 5.1
param(
    [switch]$ProfileOnly
)

$ErrorActionPreference = "Stop"

$script:StealthProfileName = "stealth"
$script:StealthMarkerFile = "stealth-setup.json"
$script:StealthDefaultZoom = 0.95
$script:StealthShortcutName = "Stealth"
$script:StealthIconFile = "stealth-dark.ico"
$script:StealthProcessNames = @("firefox", "plugin-container")
$script:InstallScriptDir = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { $PSScriptRoot }
$script:MaxSafePrefsJsBytes = 64MB
$script:SetupLogAction = $null
$script:SetupLogQueue = $null
$script:SetupStatusQueue = $null
$script:SetupProgressQueue = $null

. (Join-Path $script:InstallScriptDir "Stealth-Update.ps1")
. (Join-Path $script:InstallScriptDir "Stealth-Taskbar.ps1")
. (Join-Path $script:InstallScriptDir "Stealth-Engine.ps1")

function Write-SetupLog {
    param(
        [string]$Message,
        [ValidateSet("Info", "Step", "Ok", "Warn", "Error", "Detail")]
        [string]$Level = "Info"
    )

    if ($script:SetupLogQueue) {
        $line = switch ($Level) {
            "Step"  { ">> $Message" }
            "Ok"    { "[ok] $Message" }
            "Warn"  { "[!] $Message" }
            "Error" { "[x] $Message" }
            "Detail"{ "    $Message" }
            default { $Message }
        }
        [void]$script:SetupLogQueue.Enqueue($line)
        if ($Level -eq "Step" -and $script:SetupStatusQueue) {
            [void]$script:SetupStatusQueue.Enqueue($Message)
        }
        return
    }

    if ($script:SetupLogAction) {
        & $script:SetupLogAction $Message $Level
        return
    }

    switch ($Level) {
        "Step"  { Write-Host ">> $Message" -ForegroundColor Cyan; break }
        "Ok"    { Write-Host "   $Message" -ForegroundColor Green; break }
        "Warn"  { Write-Host "   $Message" -ForegroundColor Yellow; break }
        "Error" { Write-Host "   $Message" -ForegroundColor Red; break }
        "Detail"{ Write-Host "   $Message" -ForegroundColor DarkYellow; break }
        default { Write-Host $Message }
    }
}

function Write-SetupProgress {
    param(
        [int]$Percent = -1,
        [string]$Message
    )

    if ($script:SetupProgressQueue) {
        [void]$script:SetupProgressQueue.Enqueue([pscustomobject]@{
            Percent = $Percent
            Message = $Message
        })
    }
    if ($Message -and $script:SetupStatusQueue) {
        [void]$script:SetupStatusQueue.Enqueue($Message)
    }
}

function Write-Step($msg) { Write-SetupLog $msg "Step" }

function Save-StealthEngineInstaller {
    param(
        [string]$Url,
        [string]$OutFile
    )

    Write-SetupProgress -Percent 8 -Message 'Скачивание движка Mozilla (1-3 мин)...'
    Write-SetupLog "Download: $Url" "Detail"

    $request = [System.Net.HttpWebRequest]::Create($Url)
    $request.UserAgent = "StealthBrowser-Setup"
    $request.AllowAutoRedirect = $true
    $response = $request.GetResponse()
    $total = [int64]$response.ContentLength
    $stream = $response.GetResponseStream()
    $fileStream = [System.IO.File]::Open($OutFile, [System.IO.FileMode]::Create)
    $buffer = New-Object byte[] 262144
    $received = [int64]0
    $lastPct = -1

    try {
        while ($true) {
            $read = $stream.Read($buffer, 0, $buffer.Length)
            if ($read -le 0) { break }
            $fileStream.Write($buffer, 0, $read)
            $received += $read

            if ($total -gt 0) {
                $pct = [int](12 + (($received / $total) * 38))
                if ($pct -ne $lastPct) {
                    $lastPct = $pct
                    $gotMb = [math]::Round($received / 1MB, 1)
                    $totalMb = [math]::Round($total / 1MB, 1)
                    $dlMsg = 'Скачивание: {0} / {1} MB ({2}%)' -f $gotMb, $totalMb, $pct
                    Write-SetupProgress -Percent $pct -Message $dlMsg
                }
            }
            elseif ($received % 4194304 -lt $read) {
                $gotMb = [math]::Round($received / 1MB, 1)
                $dlMsg = 'Скачивание: {0} MB...' -f $gotMb
                Write-SetupProgress -Percent -1 -Message $dlMsg
            }
        }
    }
    finally {
        $fileStream.Dispose()
        $stream.Dispose()
        $response.Dispose()
    }

    Write-SetupProgress -Percent 52 -Message "Движок скачан, установка..."
    Write-SetupLog "Saved: $OutFile" "Detail"
}

function Get-SetupVersion {
    $scriptDir = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { $PSScriptRoot }
    $path = Join-Path $scriptDir "version.json"
    if (-not (Test-Path $path)) {
        return [PSCustomObject]@{
            ProductName  = "StealthBrowser"
            GitHubRepo   = "soundcloud920/StealthBrowser"
            SetupVersion = "1.0.0-beta"
            EngineVersion = "151.0.3"
            EngineLang   = "ru"
        }
    }
    $obj = Get-Content $path -Raw | ConvertFrom-Json
    $engineVersion = if ($obj.PSObject.Properties.Name -contains "engineVersion") { $obj.engineVersion } else { $obj.firefoxVersion }
    $engineLang = if ($obj.PSObject.Properties.Name -contains "engineLang") { $obj.engineLang } else { $obj.firefoxLang }
    $productName = if ($obj.PSObject.Properties.Name -contains "productName") { $obj.productName } else { "StealthBrowser" }
    $githubRepo = if ($obj.PSObject.Properties.Name -contains "githubRepo") { $obj.githubRepo } else { "soundcloud920/StealthBrowser" }
    return [PSCustomObject]@{
        ProductName   = [string]$productName
        GitHubRepo    = [string]$githubRepo
        SetupVersion  = [string]$obj.setupVersion
        EngineVersion = [string]$engineVersion
        EngineLang    = [string]$engineLang
    }
}

function Initialize-BundleRoot {
    $scriptDir = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { $PSScriptRoot }
    $bundleDir = Join-Path $scriptDir "bundle"
    $stamp = Join-Path $bundleDir "templates\user.js"
    if (Test-Path $stamp) { return $bundleDir }

    $dest = Join-Path $scriptDir "_bundle"
    $stamp = Join-Path $dest "templates\user.js"
    $sidecarZip = Join-Path $scriptDir "bundle.zip"

    if (-not (Test-Path $sidecarZip)) {
        throw "Missing bundle/ or bundle.zip in the same folder as this script."
    }

    $needsExtract = -not (Test-Path $stamp)
    if (-not $needsExtract) {
        $needsExtract = (Get-Item $sidecarZip).LastWriteTimeUtc -gt (Get-Item $stamp).LastWriteTimeUtc
    }
    if ($needsExtract) {
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        Expand-StealthArchive -Path $sidecarZip -DestinationPath $dest
    }
    return $dest
}

function Test-StealthRunning {
    foreach ($name in $script:StealthProcessNames) {
        if (Get-Process -Name $name -ErrorAction SilentlyContinue) { return $true }
    }
    return $false
}

function Write-TextFileNoBom {
    param(
        [string]$Path,
        [string]$Content
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Repair-OversizedPrefsFile {
    param([string]$ProfilePath)

    $prefsPath = Join-Path $ProfilePath "prefs.js"
    if (-not (Test-Path $prefsPath)) { return }

    $info = Get-Item $prefsPath
    if ($info.Length -le $script:MaxSafePrefsJsBytes) { return }

    $backup = Join-Path $ProfilePath ("prefs.js.oversized-{0}.bak" -f (Get-Date -Format "yyyyMMddHHmmss"))
    Move-Item -Path $prefsPath -Destination $backup -Force

    $sizeMb = [math]::Round($info.Length / 1MB, 2)
    Write-SetupLog "prefs.js is oversized (${sizeMb} MB). Resetting file; backup: $backup" "Warn"

    $seed = @(
        "// Recreated by Stealth setup due oversized prefs.js",
        "user_pref(`"browser.shell.checkDefaultBrowser`", false);"
    ) -join "`n"
    Write-TextFileNoBom -Path $prefsPath -Content ($seed + "`n")
}

function Set-ProfilePref {
    param(
        [string]$ProfilePath,
        [string]$Name,
        [string]$Value,
        [switch]$AsInt,
        [switch]$AsBool
    )

    $prefsPath = Join-Path $ProfilePath "prefs.js"
    if (-not (Test-Path $prefsPath)) { return }

    $escapedName = [regex]::Escape($Name)
    if ($AsBool) {
        $line = "user_pref(`"$Name`", $Value);"
    }
    elseif ($AsInt) {
        $line = "user_pref(`"$Name`", $Value);"
    }
    else {
        $line = "user_pref(`"$Name`", `"$Value`");"
    }
    Repair-OversizedPrefsFile -ProfilePath $ProfilePath

    $tmpPath = Join-Path $ProfilePath ("prefs.{0}.tmp" -f [guid]::NewGuid().ToString("n"))
    $pattern = "^\s*user_pref\(`"$escapedName`","
    $found = $false

    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    $reader = $null
    $writer = $null
    try {
        $reader = New-Object System.IO.StreamReader($prefsPath)
        $writer = New-Object System.IO.StreamWriter($tmpPath, $false, $utf8NoBom)
        while (($current = $reader.ReadLine()) -ne $null) {
            if (-not $found -and $current -match $pattern) {
                $writer.WriteLine($line)
                $found = $true
            }
            else {
                $writer.WriteLine($current)
            }
        }
        if (-not $found) {
            $writer.WriteLine($line)
        }
    }
    finally {
        if ($reader) { $reader.Dispose() }
        if ($writer) { $writer.Dispose() }
    }

    Move-Item -Path $tmpPath -Destination $prefsPath -Force
}

function Set-ProfileDefaultSearch {
    param([string]$ProfilePath)

    $searchTool = Join-Path $script:InstallScriptDir "tools\SetProfileSearch.exe"
    if (-not (Test-Path $searchTool)) {
        Write-SetupLog "SetProfileSearch.exe missing, default search left unchanged" "Warn"
        return
    }

    try {
        & $searchTool $ProfilePath
        if ($LASTEXITCODE -ne 0) {
            throw "SetProfileSearch.exe exited with code $LASTEXITCODE"
        }
        Write-SetupLog "Profile search default: SearXNG (searx.tiekoetter.com)" "Ok"
    }
    catch {
        Write-SetupLog "Could not patch profile search engines: $($_.Exception.Message)" "Warn"
    }
}

function Set-ProfileDefaultZoom {
    param(
        [string]$ProfilePath,
        [double]$Zoom = $script:StealthDefaultZoom
    )

    $chromeDir = Join-Path $ProfilePath "chrome"
    New-Item -ItemType Directory -Force -Path $chromeDir | Out-Null

    $pendingPath = Join-Path $chromeDir "stealth-pending-zoom"
    Write-TextFileNoBom -Path $pendingPath -Content ("{0}`n" -f $Zoom)

    $dbPath = Join-Path $ProfilePath "content-prefs.sqlite"
    if (-not (Test-Path $dbPath)) {
        Write-SetupLog "Default zoom $([int]($Zoom * 100))% will apply on next Stealth start" "Detail"
        return
    }

    $zoomTool = Join-Path $script:InstallScriptDir "tools\SetProfileZoom.exe"
    if (-not (Test-Path $zoomTool)) {
        Write-SetupLog "Default zoom $([int]($Zoom * 100))% will apply on next Stealth start" "Detail"
        return
    }

    try {
        & $zoomTool $dbPath $Zoom
        if ($LASTEXITCODE -ne 0) {
            throw "SetProfileZoom.exe exited with code $LASTEXITCODE"
        }
        Remove-Item $pendingPath -Force -ErrorAction SilentlyContinue
        Write-SetupLog "Default zoom set to $([int]($Zoom * 100))%" "Detail"
    }
    catch {
        Write-SetupLog "Default zoom $([int]($Zoom * 100))% will apply on next Stealth start" "Detail"
    }
}

function Test-StealthIsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-StealthElevatedSilently {
    param([string]$Script)

    if (Test-StealthIsAdministrator) {
        Invoke-Expression $Script
        return 0
    }

    $tempFile = Join-Path $env:TEMP ("stealth-elev-{0}.ps1" -f [guid]::NewGuid().ToString('n'))
    try {
        $utf8Bom = New-Object System.Text.UTF8Encoding $true
        [System.IO.File]::WriteAllText($tempFile, $Script, $utf8Bom)
        $proc = Start-Process -FilePath 'powershell.exe' `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$tempFile`"" `
            -Wait -PassThru -Verb RunAs -WindowStyle Hidden
        if ($proc) { return $proc.ExitCode }
        return 1
    }
    finally {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}

function Get-StealthFirefoxShortcutRemovalScript {
    @'
$names = @('Firefox.lnk', 'Mozilla Firefox.lnk')
$dirs = @(
    [Environment]::GetFolderPath('Desktop'),
    (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'),
    (Join-Path ${env:ProgramData} 'Microsoft\Windows\Start Menu\Programs')
)
foreach ($dir in $dirs) {
    if (-not $dir -or -not (Test-Path $dir)) { continue }
    foreach ($name in $names) {
        Remove-Item (Join-Path $dir $name) -Force -ErrorAction SilentlyContinue
    }
    $firefoxFolder = Join-Path $dir 'Firefox'
    if (Test-Path $firefoxFolder) {
        Remove-Item $firefoxFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
}
'@
}

function Remove-MozillaFirefoxShortcuts {
    Write-SetupLog "Removing default Mozilla Firefox shortcuts..." "Detail"
    Invoke-Expression (Get-StealthFirefoxShortcutRemovalScript)

    $pinDir = Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar'
    if (-not (Test-Path $pinDir)) { return }

    $shell = New-Object -ComObject WScript.Shell
    Get-ChildItem $pinDir -Filter '*.lnk' -ErrorAction SilentlyContinue | ForEach-Object {
        $shortcut = $shell.CreateShortcut($_.FullName)
        $target = [string]$shortcut.TargetPath
        if ($target -match '\\Mozilla Firefox\\firefox\.exe$' -or ($target -match 'firefox\.exe$' -and $target -notmatch 'StealthBrowser\\Engine\\')) {
            Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
            Write-SetupLog "Unpinned Mozilla Firefox from taskbar" "Detail"
        }
    }
}

function Test-MozillaFirefoxSetupRunning {
    foreach ($proc in @(Get-Process -ErrorAction SilentlyContinue)) {
        $path = ''
        try { $path = [string]$proc.Path } catch { }

        if ($path -match '\\Firefox Setup [^\\]+\.exe$') { return $true }
        if ($path -match '\\firefox-[\d.]+\.exe$' -and $path -notmatch '\\Mozilla Firefox\\firefox\.exe$') { return $true }
        if ($proc.ProcessName -eq 'setup' -and $path -match '\\Temp\\') { return $true }
    }
    return $false
}

function Get-MozillaFirefoxInstallerUrl {
    param(
        [string]$Version,
        [string]$Lang = 'ru'
    )

    $langKey = $Lang.ToLowerInvariant()
    $segment = switch ($langKey) {
        'en'    { 'en-US' }
        'en-us' { 'en-US' }
        default { $Lang }
    }
    return "https://download-installer.cdn.mozilla.net/pub/firefox/releases/$Version/win64/$segment/Firefox%20Setup%20$Version.exe"
}

function Wait-MozillaFirefoxInstalled {
    param([int]$MaxWaitSeconds = 300)

    Write-SetupLog "Waiting for Firefox installation to finish..." "Detail"
    $deadline = (Get-Date).AddSeconds($MaxWaitSeconds)
    $lastMsg = $null
    while ((Get-Date) -lt $deadline) {
        $source = Get-MozillaFirefoxSource
        if ($source) {
            Write-SetupLog "Mozilla Firefox $($source.Version) ready" "Ok"
            return $source
        }

        $remaining = [Math]::Max(0, [int]($deadline - (Get-Date)).TotalSeconds)
        $msg = if (Test-MozillaFirefoxSetupRunning) {
            "Установка Firefox... (до $remaining с)"
        }
        else {
            "Ожидание Firefox... (до $remaining с)"
        }
        if ($msg -ne $lastMsg) {
            Write-SetupProgress -Percent 56 -Message $msg
            $lastMsg = $msg
        }
        Start-Sleep -Seconds 2
    }
    return $null
}

function Get-StealthMaintenanceRemovalScript {
    @'
$ErrorActionPreference = 'SilentlyContinue'
$svc = Get-Service -Name MozillaMaintenance -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -ne 'Stopped') {
    Stop-Service -Name MozillaMaintenance -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}
$uninstaller = $null
foreach ($key in @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\MozillaMaintenanceService',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\MozillaMaintenanceService'
    )) {
    if (-not (Test-Path $key)) { continue }
    $path = (Get-ItemProperty $key -ErrorAction SilentlyContinue).UninstallString
    if ($path) {
        $uninstaller = $path.Trim().Trim('"')
        if (Test-Path $uninstaller) { break }
        $uninstaller = $null
    }
}
if (-not $uninstaller) {
    foreach ($dir in @(
            (Join-Path ${env:ProgramFiles(x86)} 'Mozilla Maintenance Service'),
            (Join-Path $env:ProgramFiles 'Mozilla Maintenance Service')
        )) {
        foreach ($name in @('Uninstall.exe', 'uninstall.exe')) {
            $candidate = Join-Path $dir $name
            if (Test-Path $candidate) { $uninstaller = $candidate; break }
        }
        if ($uninstaller) { break }
    }
}
if ($uninstaller) {
    $proc = Start-Process -FilePath $uninstaller -ArgumentList '/S' -Wait -PassThru -WindowStyle Hidden
    if ($proc -and $proc.ExitCode -ne 0) { exit $proc.ExitCode }
}
foreach ($dir in @(
        (Join-Path ${env:ProgramFiles(x86)} 'Mozilla Maintenance Service'),
        (Join-Path $env:ProgramFiles 'Mozilla Maintenance Service')
    )) {
    $svcExe = Join-Path $dir 'maintenanceservice.exe'
    if (Test-Path $svcExe) {
        Start-Process -FilePath $svcExe -ArgumentList 'uninstall' -Wait -WindowStyle Hidden | Out-Null
    }
}
exit 0
'@
}

function Get-MozillaMaintenanceUninstaller {
    foreach ($key in @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\MozillaMaintenanceService',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\MozillaMaintenanceService'
        )) {
        if (-not (Test-Path $key)) { continue }
        $props = Get-ItemProperty $key -ErrorAction SilentlyContinue
        if ($props.UninstallString) {
            $path = $props.UninstallString.Trim().Trim('"')
            if (Test-Path $path) { return $path }
        }
    }

    foreach ($dir in @(
            (Join-Path ${env:ProgramFiles(x86)} 'Mozilla Maintenance Service'),
            (Join-Path ${env:ProgramFiles} 'Mozilla Maintenance Service')
        )) {
        foreach ($name in @('Uninstall.exe', 'uninstall.exe')) {
            $path = Join-Path $dir $name
            if (Test-Path $path) { return $path }
        }
    }

    return $null
}

function Remove-MozillaMaintenanceService {
    $uninstaller = Get-MozillaMaintenanceUninstaller
    $service = Get-Service -Name MozillaMaintenance -ErrorAction SilentlyContinue
    if (-not $uninstaller -and -not $service) {
        Write-SetupLog "Mozilla Maintenance Service: not installed" "Detail"
        return
    }

    Write-Step "Removing Mozilla Maintenance Service..."
    Write-SetupLog "Silent removal (/S, no uninstall window)..." "Detail"

    $exitCode = Invoke-StealthElevatedSilently -Script (Get-StealthMaintenanceRemovalScript)
    if ($exitCode -ne 0) {
        Write-SetupLog "Maintenance Service removal exit code: $exitCode" "Warn"
    }

    if (-not (Get-MozillaMaintenanceUninstaller) -and -not (Get-Service -Name MozillaMaintenance -ErrorAction SilentlyContinue)) {
        Write-SetupLog "Mozilla Maintenance Service removed" "Ok"
    }
    elseif (Test-StealthIsAdministrator) {
        Write-SetupLog "Mozilla Maintenance Service may still be present (harmless for Stealth)" "Warn"
    }
    else {
        Write-SetupLog "Maintenance Service removal was skipped or needs one UAC approval" "Warn"
    }
}

function Stop-StealthProcess {
    param([int]$MaxWaitSeconds = 20)

    $stoppedAny = $false
    foreach ($name in $script:StealthProcessNames) {
        $procs = @(Get-Process -Name $name -ErrorAction SilentlyContinue)
        if ($procs.Count -eq 0) { continue }

        $stoppedAny = $true
        Write-SetupLog "Closing $name ($($procs.Count))..." "Detail"
        foreach ($proc in $procs) {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not $stoppedAny) { return }

    $deadline = [datetime]::UtcNow.AddSeconds($MaxWaitSeconds)
    while ([datetime]::UtcNow -lt $deadline) {
        if (-not (Test-StealthRunning)) {
            Write-SetupLog "Browser closed" "Ok"
            return
        }
        Start-Sleep -Milliseconds 400
    }
}

function Install-StealthIfNeeded {
    param(
        [string]$Version = "151.0.3",
        [string]$Lang = "ru"
    )

    $source = Get-MozillaFirefoxSource
    if ($source -and (Test-StealthEngineVersionCompatible -Installed $source.Version -Wanted $Version)) {
        Write-SetupProgress -Percent 58 -Message "Движок найден, патч брендинга Stealth..."
        return Sync-StealthEngine -Version $Version
    }

    if ($source) {
        Write-SetupLog "Mozilla $($source.Version) -> installing $Version..." "Detail"
    }
    else {
        Write-SetupLog "Mozilla Firefox not found, installing $Version..." "Detail"
    }

    Write-Step "Downloading Stealth $Version..."
    $installer = Join-Path $env:TEMP ("StealthSetup-{0}.exe" -f $Version)
    $url = Get-MozillaFirefoxInstallerUrl -Version $Version -Lang $Lang
    try {
        Save-StealthEngineInstaller -Url $url -OutFile $installer
    }
    catch {
        Write-SetupLog "CDN installer failed, trying Mozilla redirect..." "Warn"
        $url = 'https://download.mozilla.org/?product=firefox-{0}-ssl&os=win64&lang={1}' -f $Version, $Lang
        Save-StealthEngineInstaller -Url $url -OutFile $installer
    }

    Write-SetupProgress -Percent 55 -Message "Установка Firefox и патч Stealth (может появиться UAC)..."
    Write-Step "Installing Firefox engine (silent, one UAC)..."
    $installerEscaped = $installer.Replace("'", "''")
    $engineScript = @"
`$ErrorActionPreference = 'Stop'
`$installer = '$installerEscaped'
`$proc = Start-Process -FilePath `$installer -ArgumentList '/S /MaintenanceService=false /DesktopShortcut=false /StartMenuShortcut=false' -Wait -PassThru -WindowStyle Hidden
if (`$proc.ExitCode -ne 0) { exit `$proc.ExitCode }
Start-Sleep -Seconds 5
$(Get-StealthFirefoxShortcutRemovalScript)
$(Get-StealthMaintenanceRemovalScript)
"@
    $exitCode = Invoke-StealthElevatedSilently -Script $engineScript
    if ($exitCode -ne 0) {
        throw "Stealth installer exited with code $exitCode"
    }

    $source = Wait-MozillaFirefoxInstalled
    if (-not $source) {
        throw "Firefox install finished but Mozilla Firefox was not found."
    }

    Remove-MozillaFirefoxShortcuts
    Write-SetupProgress -Percent 58 -Message "Патч брендинга Stealth..."
    return Sync-StealthEngine -Version $Version
}

function Get-StealthProfilePath {
    $profilesIni = Join-Path $env:APPDATA "Mozilla\Firefox\profiles.ini"
    if (-not (Test-Path $profilesIni)) { return $null }

    $browserRoot = Join-Path $env:APPDATA "Mozilla\Firefox"
    $profileName = $script:StealthProfileName
    $sectionName = $null
    $sectionPath = $null
    $sectionIsRelative = $true

    function Resolve-StealthProfilePath {
        if (-not $sectionPath) { return $null }
        $full = if ($sectionIsRelative) { Join-Path $browserRoot $sectionPath } else { $sectionPath }
        if (Test-Path $full) { return $full }
        return $null
    }

    foreach ($line in Get-Content $profilesIni) {
        if ($line -match '^\[(.+)\]$') {
            if ($sectionName -eq $profileName) {
                $resolved = Resolve-StealthProfilePath
                if ($resolved) { return $resolved }
            }
            $sectionName = $Matches[1]
            $sectionPath = $null
            $sectionIsRelative = $true
            continue
        }
        if ($line -match '^Name=(.+)$') { $sectionName = $Matches[1].Trim() }
        if ($line -match '^Path=(.+)$') { $sectionPath = $Matches[1].Trim() }
        if ($line -match '^IsRelative=(.+)$') { $sectionIsRelative = ($Matches[1].Trim() -eq '1') }
    }

    if ($sectionName -eq $profileName) {
        $resolved = Resolve-StealthProfilePath
        if ($resolved) { return $resolved }
    }

    $profilesDir = Join-Path $browserRoot "Profiles"
    return Get-ChildItem $profilesDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "\.$([regex]::Escape($profileName))$" } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

function Ensure-StealthProfile {
    param([string]$StealthExe)

    $profilePath = Get-StealthProfilePath
    if ($profilePath) { return $profilePath }

    Write-Step "Creating Stealth profile..."
    & $StealthExe -CreateProfile $script:StealthProfileName | Out-Null
    Start-Sleep -Seconds 2

    $profilePath = Get-StealthProfilePath
    if (-not $profilePath) {
        throw "Failed to create Stealth profile."
    }
    return $profilePath
}

function Get-StealthProfileMarker {
    param([string]$ProfilePath)

    $path = Join-Path $ProfilePath "chrome\$($script:StealthMarkerFile)"
    if (-not (Test-Path $path)) { return $null }

    $obj = Get-Content $path -Raw | ConvertFrom-Json
    return [PSCustomObject]@{
        SetupVersion = [string]$obj.setupVersion
        AppliedAt    = [string]$obj.appliedAt
    }
}

function Write-StealthProfileMarker {
    param(
        [string]$ProfilePath,
        [string]$SetupVersion
    )

    $chromeDir = Join-Path $ProfilePath "chrome"
    New-Item -ItemType Directory -Force -Path $chromeDir | Out-Null
    $marker = @{
        setupVersion = $SetupVersion
        appliedAt    = (Get-Date).ToUniversalTime().ToString("o")
    } | ConvertTo-Json
    Write-TextFileNoBom -Path (Join-Path $chromeDir $script:StealthMarkerFile) -Content $marker
}

function Test-StealthSetupNeedsUpdate {
    param(
        [string]$Installed,
        [string]$Available
    )

    if (-not $Installed) { return $true }
    if (-not $Available) { return $false }
    if ($Installed -eq $Available) { return $false }

    $installedBase = ConvertTo-StealthVersion $Installed
    $availableBase = ConvertTo-StealthVersion $Available
    if ($installedBase -and $availableBase) {
        if ($installedBase -lt $availableBase) { return $true }
        if ($installedBase -gt $availableBase) { return $false }
    }

    return $Installed -ne $Available
}

function Test-StealthEngineInstalled {
    $engineExe = Join-Path (Get-StealthEngineRoot) "firefox.exe"
    return Test-Path $engineExe
}

function Get-StealthSetupStatus {
    $cfg = Get-SetupVersion
    $profilePath = Get-StealthProfilePath
    $marker = if ($profilePath) { Get-StealthProfileMarker -ProfilePath $profilePath } else { $null }
    $installedVer = if ($marker) { $marker.SetupVersion } else { $null }
    $availableVer = $cfg.SetupVersion
    $needsUpdate = Test-StealthSetupNeedsUpdate -Installed $installedVer -Available $availableVer
    $engineInstalled = Test-StealthEngineInstalled
    $stealthInstalled = $engineInstalled -or [bool]$profilePath

    return [PSCustomObject]@{
        AvailableVersion = $availableVer
        InstalledVersion = $installedVer
        ProfilePath      = $profilePath
        ProfileExists    = [bool]$profilePath
        EngineInstalled  = $engineInstalled
        StealthInstalled = $stealthInstalled
        NeedsUpdate      = $needsUpdate
        IsCurrent        = [bool]($installedVer -and -not $needsUpdate)
    }
}

function Remove-LegacyStealthShortcuts {
    foreach ($legacy in @(
            (Join-Path $env:USERPROFILE "Desktop\uuj Firefox.lnk"),
            (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\uuj Firefox.lnk")
        )) {
        if (Test-Path $legacy) { Remove-Item $legacy -Force }
    }
}

function Install-StealthShortcut {
    param(
        [string]$Root,
        [string]$StealthExe,
        [string]$ProfilePath
    )

    $bundledIco = Join-Path $Root "assets\$($script:StealthIconFile)"
    if (-not (Test-Path $bundledIco)) {
        $bundledIco = Join-Path $script:InstallScriptDir "branding\$($script:StealthIconFile)"
    }
    if (-not (Test-Path $bundledIco)) {
        $bundledIco = Join-Path $env:LOCALAPPDATA "LLG_Relicus\$($script:StealthIconFile)"
    }
    if (-not (Test-Path $bundledIco)) {
        throw "Icon not found: $($script:StealthIconFile). Re-run Setup.cmd from the installer folder."
    }

    $shortcutName = $script:StealthShortcutName
    Write-Step "Creating $shortcutName shortcut..."
    $iconDir = Join-Path $env:LOCALAPPDATA "LLG_Relicus"
    New-Item -ItemType Directory -Force -Path $iconDir | Out-Null
    $icoPath = Join-Path $iconDir $script:StealthIconFile
    Copy-Item $bundledIco $icoPath -Force

    Remove-LegacyStealthShortcuts

    Install-StealthLauncherFiles -InstallScriptDir $script:InstallScriptDir
    $launcherExe = Get-StealthLauncherExe
    if (-not (Test-Path $launcherExe)) {
        throw "Stealth.exe was not built. Install .NET Framework 4.x and retry."
    }

    $shell = New-Object -ComObject WScript.Shell
    $paths = @(
        (Join-Path $env:USERPROFILE "Desktop\$shortcutName.lnk"),
        (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\$shortcutName.lnk")
    )

    foreach ($lnkPath in $paths) {
        $dir = Split-Path $lnkPath -Parent
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $shortcut = $shell.CreateShortcut($lnkPath)
        $shortcut.TargetPath = $launcherExe
        $shortcut.Arguments = ""
        $shortcut.WorkingDirectory = Get-StealthAppDir
        $shortcut.IconLocation = "$launcherExe,0"
        $shortcut.Description = $shortcutName
        $shortcut.Save() | Out-Null
        Set-StealthShortcutShellProperties -LnkPath $lnkPath -LauncherCmd $launcherExe -IconPath "$launcherExe,0"
        Write-SetupLog "shortcut: $lnkPath" "Detail"
    }

    Register-StealthTaskbarIdentity -StealthExe $StealthExe -LauncherPath $launcherExe -IconPath "$launcherExe,0" -ProfilePath $ProfilePath -SetAsDefaultBrowser
    Remove-MozillaFirefoxShortcuts
    $desktopLnk = Join-Path $env:USERPROFILE "Desktop\$shortcutName.lnk"
    Pin-StealthShortcutToTaskbar -LnkPath $desktopLnk -LauncherCmd $launcherExe -IconPath "$launcherExe,0"
    Write-SetupLog "Taskbar: Stealth pinned, Mozilla Firefox shortcuts removed" "Detail"
    Write-SetupLog "Launch via shortcut: $shortcutName" "Detail"
}

function Start-StealthAfterSetup {
    param([string]$StealthExe, [string]$ProfilePath)

    Write-Step "Starting Stealth..."
    $launcherExe = Get-StealthLauncherExe
    if (Test-Path $launcherExe) {
        Start-Process -FilePath $launcherExe | Out-Null
        return
    }
    Start-Process -FilePath $StealthExe -ArgumentList @(
        "-no-remote", "-profile", $ProfilePath, "-url", "about:blank"
    ) | Out-Null
}

function Apply-StealthProfileBundle {
    param(
        [string]$Root,
        [string]$ProfilePath,
        [string]$SetupVersion
    )

    $marker = Get-StealthProfileMarker -ProfilePath $ProfilePath
    if ($marker) {
        if ($marker.SetupVersion -eq $SetupVersion) {
            Write-SetupLog "Profile already at v$SetupVersion, re-applying bundle..." "Detail"
        }
        else {
            Write-Step "Updating Stealth profile $($marker.SetupVersion) -> $SetupVersion..."
        }
    }
    else {
        Write-Step "Applying Stealth profile v$SetupVersion..."
    }

    Write-Step "Installing LLG_Relicus fonts..."
    $winFontDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    New-Item -ItemType Directory -Force -Path $winFontDir | Out-Null
    $regPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
    foreach ($item in @(
            @{ Src = "LLG_Relicus-Regular.ttf"; Reg = "LLG_Relicus (TrueType)"; File = "LLG_Relicus-Regular.ttf" },
            @{ Src = "LLG_Relicus-Bold.ttf"; Reg = "LLG_Relicus Bold (TrueType)"; File = "LLG_Relicus-Bold.ttf" }
        )) {
        Copy-Item (Join-Path $Root $item.Src) (Join-Path $winFontDir $item.File) -Force
        New-ItemProperty -Path $regPath -Name $item.Reg -Value $item.File -PropertyType String -Force | Out-Null
    }
    Copy-Item (Join-Path $winFontDir "LLG_Relicus-Regular.ttf") (Join-Path $winFontDir "LLG_Relicus.ttf") -Force
    New-ItemProperty -Path $regPath -Name "LLG_Relicus (TrueType)" -Value "LLG_Relicus.ttf" -PropertyType String -Force | Out-Null

    Write-Step "Applying Stealth settings..."
    $chromeDir = Join-Path $ProfilePath "chrome"
    $faDest = Join-Path $chromeDir "fonts"
    New-Item -ItemType Directory -Force -Path $faDest, (Join-Path $chromeDir "icons") | Out-Null

    Copy-Item (Join-Path $Root "templates\userChrome.css") (Join-Path $chromeDir "userChrome.css") -Force
    Copy-Item (Join-Path $Root "templates\userChrome.js") (Join-Path $chromeDir "userChrome.js") -Force
    Copy-Item (Join-Path $Root "templates\userContent.css") (Join-Path $chromeDir "userContent.css") -Force
    Copy-Item (Join-Path $Root "LLG_Relicus-*.ttf") $faDest -Force
    Copy-Item (Join-Path $Root "fa-fonts\*.woff2") $faDest -Force
    Copy-Item (Join-Path $Root "fa-fonts\*.ttf") $faDest -Force
    Copy-Item (Join-Path $Root "assets\search-face*.png") (Join-Path $chromeDir "icons\") -Force

    $homeUrl = "chrome://browser/content/blanktab.html"

    $localePrefsPath = Join-Path $Root "templates\locale-prefs.js"
    $toolbarPrefsPath = Join-Path $Root "templates\toolbar-prefs.js"
    $searchPrefsPath = Join-Path $Root "templates\search-prefs.js"
    $userJs = Get-Content (Join-Path $Root "templates\user.js") -Raw
    if (Test-Path $localePrefsPath) {
        $userJs += "`n" + (Get-Content $localePrefsPath -Raw)
    }
    if ((-not $marker) -and (Test-Path $toolbarPrefsPath)) {
        $userJs += "`n" + (Get-Content $toolbarPrefsPath -Raw)
    }
    if (Test-Path $searchPrefsPath) {
        $userJs += "`n" + (Get-Content $searchPrefsPath -Raw)
    }
    Write-TextFileNoBom -Path (Join-Path $ProfilePath "user.js") -Content $userJs
    Set-ProfilePref -ProfilePath $ProfilePath -Name "taskbar.grouping.useprofile" -Value "false" -AsBool
    Set-ProfilePref -ProfilePath $ProfilePath -Name "browser.startup.blankWindow" -Value "false" -AsBool
    Set-ProfilePref -ProfilePath $ProfilePath -Name "browser.startup.homepage" -Value $homeUrl
    Set-ProfilePref -ProfilePath $ProfilePath -Name "browser.newtab.url" -Value $homeUrl
    Set-ProfilePref -ProfilePath $ProfilePath -Name "browser.startup.page" -Value "1" -AsInt
    Set-ProfileDefaultZoom -ProfilePath $ProfilePath
    Set-ProfileDefaultSearch -ProfilePath $ProfilePath

    Write-StealthProfileMarker -ProfilePath $ProfilePath -SetupVersion $SetupVersion
    Write-SetupLog "Profile marker: v$SetupVersion" "Ok"
}

function Invoke-StealthSetup {
    param([switch]$LaunchWhenDone, [switch]$ProfileOnly)

    $cfg = Get-SetupVersion
    $Root = Initialize-BundleRoot

    Write-SetupProgress -Percent 2 -Message "Подготовка..."
    if (Test-StealthRunning) {
        Write-SetupProgress -Percent 3 -Message "Закрытие Stealth / Firefox..."
        Write-Step "Closing Stealth / Firefox..."
        Stop-StealthProcess
    }
    if (Test-StealthRunning) {
        throw "Не удалось закрыть Stealth / Firefox. Закройте вручную и повторите."
    }
    Write-SetupProgress -Percent 5 -Message "Браузер закрыт"

    if ($ProfileOnly) {
        if (-not (Test-StealthEngineInstalled)) {
            throw "Stealth is not installed. Run full install first (without -ProfileOnly)."
        }
        Write-SetupProgress -Percent 60 -Message "Синхронизация движка Stealth..."
        $stealthExe = Sync-StealthEngine -Version $cfg.EngineVersion
        Write-SetupLog "Profile-only mode (skipping Mozilla install)" "Detail"
    }
    else {
        $stealthExe = Install-StealthIfNeeded -Version $cfg.EngineVersion -Lang $cfg.EngineLang
    }

    Write-SetupProgress -Percent 62 -Message "Удаление Mozilla Maintenance Service..."
    Remove-MozillaMaintenanceService

    Write-SetupProgress -Percent 68 -Message "Подготовка профиля Stealth..."
    Write-Step "Preparing Stealth profile..."
    $profilePath = Ensure-StealthProfile -StealthExe $stealthExe
    Write-SetupLog "Profile: $profilePath" "Detail"
    Clear-StealthProfileStartupCache -ProfilePath $profilePath

    Write-SetupProgress -Percent 78 -Message "Применение профиля и темы..."
    Apply-StealthProfileBundle -Root $Root -ProfilePath $profilePath -SetupVersion $cfg.SetupVersion
    Patch-StealthProfileLangpack -ProfilePath $profilePath
    Clear-StealthProfileStartupCache -ProfilePath $profilePath

    if (-not $ProfileOnly) {
        Write-SetupProgress -Percent 88 -Message "Создание ярлыков и таскбара..."
        Install-StealthShortcut -Root $Root -StealthExe $stealthExe -ProfilePath $profilePath
    }
    else {
        Install-StealthLauncherFiles -InstallScriptDir $script:InstallScriptDir
        $launcherExe = Get-StealthLauncherExe
        if (Test-Path $launcherExe) {
            Register-StealthTaskbarIdentity -StealthExe $stealthExe -LauncherPath $launcherExe -IconPath "$launcherExe,0" -ProfilePath $profilePath -SetAsDefaultBrowser
        }
    }

    Write-StealthLaunchConfig `
        -ProductName $cfg.ProductName `
        -GitHubRepo $cfg.GitHubRepo `
        -ProfilePath $profilePath `
        -StealthExe $stealthExe `
        -SetupVersion $cfg.SetupVersion `
        -EngineVersion $cfg.EngineVersion

    if ($LaunchWhenDone) {
        Write-SetupProgress -Percent 95 -Message "Запуск Stealth..."
        Start-StealthAfterSetup -StealthExe $stealthExe -ProfilePath $profilePath
    }

    Write-SetupProgress -Percent 100 -Message "Готово"
}

if ($MyInvocation.InvocationName -eq '.') {
    return
}

try {
    Write-Host ""
    $cfg = Get-SetupVersion
    Write-SetupLog "$($cfg.ProductName) v$($cfg.SetupVersion)" "Ok"
    Write-Host ""

    Invoke-StealthSetup -LaunchWhenDone -ProfileOnly:$ProfileOnly

    Write-Host ""
    Write-SetupLog "Done!" "Ok"
    if ($ProfileOnly) {
        Write-SetupLog "Stealth profile updated to v$($cfg.SetupVersion)." "Info"
    }
    else {
        Write-SetupLog "Stealth started (separate from default-release)." "Info"
        Write-SetupLog "Launch via shortcut: $($script:StealthShortcutName)" "Info"
    }
    Write-Host ""
}
catch {
    Write-Host ""
    Write-SetupLog "ERROR: $($_.Exception.Message)" "Error"
    Write-Host ""
    Read-Host "Press Enter to close"
    exit 1
}
