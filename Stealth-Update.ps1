#Requires -Version 5.1

function Expand-StealthArchive {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Archive not found: $Path"
    }

    if (Test-Path -LiteralPath $DestinationPath) {
        Remove-Item -LiteralPath $DestinationPath -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $DestinationPath | Out-Null

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($Path, $DestinationPath)
}

function Get-StealthAppDir {
    return Join-Path $env:LOCALAPPDATA "StealthBrowser"
}

function Get-StealthLauncherExe {
    return Join-Path (Get-StealthAppDir) "Stealth.exe"
}

function Install-StealthLauncherFiles {
    param([string]$InstallScriptDir)

    $appDir = Get-StealthAppDir
    New-Item -ItemType Directory -Force -Path $appDir | Out-Null

    $iconPath = Join-Path $InstallScriptDir "branding\stealth-dark.ico"
    if (-not (Test-Path $iconPath)) {
        $iconPath = Join-Path $InstallScriptDir "bundle\assets\stealth-dark.ico"
    }
    if (-not (Test-Path $iconPath)) {
        $iconPath = Join-Path $env:LOCALAPPDATA "LLG_Relicus\stealth-dark.ico"
    }

    $compileScript = Join-Path $InstallScriptDir "scripts\compile-stealth-launcher.ps1"
    $launcherExe = Get-StealthLauncherExe
    if (Test-Path $compileScript) {
        & $compileScript -SourceDir $InstallScriptDir -IconPath $iconPath -OutputPath $launcherExe
    }
    elseif (Test-Path (Join-Path $InstallScriptDir "Stealth.exe")) {
        Copy-Item (Join-Path $InstallScriptDir "Stealth.exe") $launcherExe -Force
    }

    foreach ($file in @(
            "Stealth-ApplyUpdate.ps1", "Stealth-Update.ps1", "Stealth-Taskbar.ps1",
            "Stealth-Engine.ps1", "Install-Stealth.ps1", "version.json"
        )) {
        $src = Join-Path $InstallScriptDir $file
        if (-not (Test-Path $src)) { continue }
        Copy-Item $src (Join-Path $appDir $file) -Force
    }
}

function Get-StealthLaunchConfigPath {
    return Join-Path (Get-StealthAppDir) "config.json"
}

function Get-StealthLaunchConfig {
    $path = Get-StealthLaunchConfigPath
    if (-not (Test-Path $path)) { return $null }
    $obj = Get-Content $path -Raw | ConvertFrom-Json
    return [PSCustomObject]@{
        ProductName           = [string]$obj.productName
        GitHubRepo            = [string]$obj.githubRepo
        ProfilePath           = [string]$obj.profilePath
        StealthExe            = [string]$obj.stealthExe
        SetupVersion          = [string]$obj.setupVersion
        EngineVersion         = [string]$obj.engineVersion
        SearchEngine          = if ($obj.searchEngine) { [string]$obj.searchEngine } else { "Google" }
        DismissedVersion      = if ($obj.dismissedVersion) { [string]$obj.dismissedVersion } else { $null }
        LastUpdateCheckUtc    = if ($obj.lastUpdateCheckUtc) { [string]$obj.lastUpdateCheckUtc } else { $null }
        LastUpdateCheckLatest = if ($obj.lastUpdateCheckLatest) { [string]$obj.lastUpdateCheckLatest } else { $null }
    }
}

function Test-StealthUpdateCacheFresh {
    param(
        [string]$CheckedAtUtc,
        [int]$MaxAgeHours = 24
    )

    if (-not $CheckedAtUtc) { return $false }

    try {
        $checkedAt = [datetime]::Parse($CheckedAtUtc, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal)
        return ((Get-Date).ToUniversalTime() - $checkedAt.ToUniversalTime()).TotalHours -lt $MaxAgeHours
    }
    catch {
        return $false
    }
}

function Write-StealthUpdateCheckCache {
    param([string]$LatestVersion)

    $config = Get-StealthLaunchConfig
    if (-not $config) { return }

    Write-StealthLaunchConfig `
        -ProductName $config.ProductName `
        -GitHubRepo $config.GitHubRepo `
        -ProfilePath $config.ProfilePath `
        -StealthExe $config.StealthExe `
        -SetupVersion $config.SetupVersion `
        -EngineVersion $config.EngineVersion `
        -DismissedVersion $config.DismissedVersion `
        -LastUpdateCheckUtc ((Get-Date).ToUniversalTime().ToString('o')) `
        -LastUpdateCheckLatest $LatestVersion
}

function Write-StealthLaunchConfig {
    param(
        [string]$ProductName,
        [string]$GitHubRepo,
        [string]$ProfilePath,
        [string]$StealthExe,
        [string]$SetupVersion,
        [string]$EngineVersion,
        [string]$SearchEngine,
        [string]$DismissedVersion,
        [string]$LastUpdateCheckUtc,
        [string]$LastUpdateCheckLatest
    )

    $appDir = Get-StealthAppDir
    New-Item -ItemType Directory -Force -Path $appDir | Out-Null

    $existing = Get-StealthLaunchConfig
    if (-not $PSBoundParameters.ContainsKey("DismissedVersion") -and $existing) {
        $DismissedVersion = $existing.DismissedVersion
    }
    if (-not $PSBoundParameters.ContainsKey("LastUpdateCheckUtc") -and $existing) {
        $LastUpdateCheckUtc = $existing.LastUpdateCheckUtc
    }
    if (-not $PSBoundParameters.ContainsKey("LastUpdateCheckLatest") -and $existing) {
        $LastUpdateCheckLatest = $existing.LastUpdateCheckLatest
    }
    if (-not $PSBoundParameters.ContainsKey("SearchEngine") -and $existing) {
        $SearchEngine = $existing.SearchEngine
    }
    if ([string]::IsNullOrWhiteSpace($SearchEngine)) {
        $SearchEngine = "Google"
    }

    $config = @{
        productName           = $ProductName
        githubRepo            = $GitHubRepo
        profilePath           = $ProfilePath
        stealthExe            = $StealthExe
        setupVersion          = $SetupVersion
        engineVersion         = $EngineVersion
        searchEngine          = $SearchEngine
        dismissedVersion      = $DismissedVersion
        lastUpdateCheckUtc    = $LastUpdateCheckUtc
        lastUpdateCheckLatest = $LastUpdateCheckLatest
    } | ConvertTo-Json

    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText((Get-StealthLaunchConfigPath), $config, $utf8NoBom)
}

function ConvertTo-StealthVersion {
    param([string]$Value)
    if (-not $Value) { return $null }
    $clean = $Value.Trim().TrimStart("v", "V")
    if ($clean -match '^([^-+]+)') { $clean = $Matches[1] }
    try { return [version]$clean }
    catch { return $null }
}

function Get-StealthVersionLabel {
    param([string]$Value)
    if (-not $Value) { return "" }
    return $Value.Trim().TrimStart("v", "V")
}

function Get-GitHubLatestStealthRelease {
    param(
        [string]$GitHubRepo = "soundcloud920/StealthBrowser",
        [int]$TimeoutSec = 15
    )

    $uri = "https://api.github.com/repos/$GitHubRepo/releases/latest"
    $headers = @{ "User-Agent" = "StealthBrowser-Updater" }
    $release = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -TimeoutSec $TimeoutSec
    $asset = @($release.assets | Where-Object { $_.name -like "StealthBrowser-setup-*.zip" } | Select-Object -First 1)[0]
    if (-not $asset) { throw "No StealthBrowser-setup zip in latest release." }

    $tagVersion = ConvertTo-StealthVersion $release.tag_name
    return [PSCustomObject]@{
        TagName      = [string]$release.tag_name
        Version      = if ($tagVersion) { $tagVersion.ToString() } else { $release.tag_name.TrimStart("v") }
        Name         = [string]$release.name
        HtmlUrl      = [string]$release.html_url
        DownloadUrl  = [string]$asset.browser_download_url
        FileName     = [string]$asset.name
    }
}

function Get-StealthUpdateOffer {
    param(
        [string]$CurrentVersion,
        [string]$GitHubRepo = "soundcloud920/StealthBrowser",
        [string]$DismissedVersion,
        [switch]$UseCache
    )

    $current = ConvertTo-StealthVersion $CurrentVersion
    if (-not $current) { return [PSCustomObject]@{ Available = $false } }

    if ($UseCache) {
        $config = Get-StealthLaunchConfig
        if ($config -and (Test-StealthUpdateCacheFresh -CheckedAtUtc $config.LastUpdateCheckUtc)) {
            $cachedLatest = ConvertTo-StealthVersion $config.LastUpdateCheckLatest
            if ($cachedLatest -and $cachedLatest -le $current) {
                return [PSCustomObject]@{ Available = $false }
            }
        }
    }

    try {
        $timeoutSec = if ($UseCache) { 5 } else { 15 }
        $release = Get-GitHubLatestStealthRelease -GitHubRepo $GitHubRepo -TimeoutSec $timeoutSec
        Write-StealthUpdateCheckCache -LatestVersion $release.Version
    }
    catch {
        return [PSCustomObject]@{ Available = $false; Error = $_.Exception.Message }
    }

    $latest = ConvertTo-StealthVersion $release.Version
    if (-not $latest -or $latest -le $current) {
        return [PSCustomObject]@{ Available = $false; Release = $release }
    }

    if ($DismissedVersion) {
        $dismissed = ConvertTo-StealthVersion $DismissedVersion
        if ($dismissed -and $latest -le $dismissed) {
            return [PSCustomObject]@{ Available = $false; Release = $release }
        }
    }

    return [PSCustomObject]@{
        Available       = $true
        CurrentVersion  = $current.ToString()
        LatestVersion   = $latest.ToString()
        Release         = $release
    }
}

function Show-StealthUpdateDialog {
    param(
        [string]$ProductName,
        [string]$CurrentVersion,
        [string]$LatestVersion,
        [string]$ReleaseUrl
    )

    Add-Type -AssemblyName System.Windows.Forms
    $text = @"
Доступно обновление $ProductName.

Установлено: v$CurrentVersion
На GitHub:    v$LatestVersion

Обновить сейчас?
(Позже - запустить Stealth без обновления)
(Пропустить - не напоминать про v$LatestVersion)
"@

    $result = [System.Windows.Forms.MessageBox]::Show(
        $text,
        ($ProductName + " - update"),
        [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )

    switch ($result) {
        ([System.Windows.Forms.DialogResult]::Yes) { return "Update" }
        ([System.Windows.Forms.DialogResult]::Cancel) { return "Dismiss" }
        default { return "Later" }
    }
}

function Install-StealthReleaseUpdate {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Release,
        [string]$InstallScriptDir
    )

    if (-not $InstallScriptDir) {
        $InstallScriptDir = Get-StealthAppDir
    }

    $installScript = Join-Path $InstallScriptDir "Install-Stealth.ps1"
    if (-not (Test-Path $installScript)) {
        throw "Install-Stealth.ps1 not found in $InstallScriptDir"
    }

    . $installScript

    if (Test-StealthRunning) {
        Stop-StealthProcess
    }

    $workRoot = Join-Path $env:TEMP ("StealthBrowser-update-" + [guid]::NewGuid().ToString("n"))
    $zipPath = Join-Path $workRoot "package.zip"
    $extractDir = Join-Path $workRoot "package"
    New-Item -ItemType Directory -Force -Path $workRoot, $extractDir | Out-Null

    try {
        Invoke-WebRequest -Uri $Release.DownloadUrl -OutFile $zipPath -UseBasicParsing
        Expand-StealthArchive -Path $zipPath -DestinationPath $extractDir

        $remoteVersionPath = Join-Path $extractDir "version.json"
        if (-not (Test-Path $remoteVersionPath)) {
            throw "Downloaded package has no version.json"
        }
        $remoteCfg = Get-Content $remoteVersionPath -Raw | ConvertFrom-Json
        $remoteEngine = if ($remoteCfg.engineVersion) { [string]$remoteCfg.engineVersion } else { [string]$remoteCfg.firefoxVersion }
        $localCfg = Get-StealthLaunchConfig
        $profileOnly = $localCfg -and ($localCfg.EngineVersion -eq $remoteEngine)

        Push-Location $extractDir
        try {
            . (Join-Path $extractDir "Install-Stealth.ps1")
            $searchEngine = if ($localCfg -and $localCfg.SearchEngine) { $localCfg.SearchEngine } else { "Google" }
            Invoke-StealthSetup -ProfileOnly:$profileOnly -LaunchWhenDone:$false -SearchEngine $searchEngine
        }
        finally {
            Pop-Location
        }

        Install-StealthLauncherFiles -InstallScriptDir $extractDir
    }
    finally {
        Remove-Item $workRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Test-StealthUpdateAtLaunch {
    param(
        [switch]$Quiet,
        [switch]$SkipBrowserLaunch
    )

    $config = Get-StealthLaunchConfig
    if (-not $config) { return }

    if (-not $SkipBrowserLaunch -and $config.StealthExe -and $config.ProfilePath -and (Test-Path $config.StealthExe)) {
        if (Get-Command Start-StealthAfterSetup -ErrorAction SilentlyContinue) {
            Start-StealthAfterSetup -StealthExe $config.StealthExe -ProfilePath $config.ProfilePath
        }
        else {
            Start-Process -FilePath $config.StealthExe -ArgumentList @('-no-remote', '--allow-downgrade', '-profile', $config.ProfilePath) | Out-Null
        }
    }

    $markerVer = $config.SetupVersion
    if ($config.ProfilePath -and (Get-Command Get-StealthProfileMarker -ErrorAction SilentlyContinue)) {
        $marker = Get-StealthProfileMarker -ProfilePath $config.ProfilePath
        if ($marker) { $markerVer = $marker.SetupVersion }
    }

    $offer = Get-StealthUpdateOffer `
        -CurrentVersion $markerVer `
        -GitHubRepo $config.GitHubRepo `
        -DismissedVersion $config.DismissedVersion `
        -UseCache

    if (-not $offer.Available) { return }

    $choice = Show-StealthUpdateDialog `
        -ProductName $config.ProductName `
        -CurrentVersion $offer.CurrentVersion `
        -LatestVersion $offer.LatestVersion `
        -ReleaseUrl $offer.Release.HtmlUrl

    if ($choice -eq "Dismiss") {
        Write-StealthLaunchConfig `
            -ProductName $config.ProductName `
            -GitHubRepo $config.GitHubRepo `
            -ProfilePath $config.ProfilePath `
            -StealthExe $config.StealthExe `
            -SetupVersion $markerVer `
            -EngineVersion $config.EngineVersion `
            -SearchEngine $config.SearchEngine `
            -DismissedVersion $offer.LatestVersion
        return
    }

    if ($choice -eq "Update") {
        try {
            Install-StealthReleaseUpdate -Release $offer.Release
        }
        catch {
            if (-not $Quiet) {
                Add-Type -AssemblyName System.Windows.Forms
                [void][System.Windows.Forms.MessageBox]::Show(
                    "Не удалось обновить: $($_.Exception.Message)",
                    "StealthBrowser",
                    "OK",
                    "Error"
                )
            }
        }
    }
}
