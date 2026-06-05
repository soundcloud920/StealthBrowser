#Requires -Version 5.1

function Get-StealthEngineRoot {
    return Join-Path (Get-StealthAppDir) "Engine"
}

function Get-MozillaFirefoxSource {
    foreach ($path in @(
            (Join-Path ${env:ProgramFiles} "Mozilla Firefox\firefox.exe"),
            (Join-Path ${env:ProgramFiles(x86)} "Mozilla Firefox\firefox.exe")
        )) {
        if (-not (Test-Path $path)) { continue }
        $info = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($path)
        if ($info.ProductVersion -match "(\d+\.\d+\.\d+)") {
            return [PSCustomObject]@{
                Path    = $path
                Dir     = Split-Path $path -Parent
                Version = $Matches[1]
            }
        }
    }
    return $null
}

function Get-StealthEngineVersionBase {
    param([string]$Version)

    if ($Version -match '^(\d+\.\d+\.\d+)') {
        return $Matches[1]
    }
    return $Version
}

function Test-StealthEngineVersionCompatible {
    param(
        [string]$Installed,
        [string]$Wanted
    )

    if (-not $Installed -or -not $Wanted) {
        return $false
    }
    return (Get-StealthEngineVersionBase $Installed) -eq (Get-StealthEngineVersionBase $Wanted)
}

function Get-RceditPath {
    $local = Join-Path (Get-StealthAppDir) "tools\rcedit-x64.exe"
    if (Test-Path $local) { return $local }

    $bundled = Join-Path $script:InstallScriptDir "tools\rcedit-x64.exe"
    if (Test-Path $bundled) {
        New-Item -ItemType Directory -Force -Path (Split-Path $local -Parent) | Out-Null
        Copy-Item $bundled $local -Force
        return $local
    }

    New-Item -ItemType Directory -Force -Path (Split-Path $local -Parent) | Out-Null
    $url = "https://github.com/electron/rcedit/releases/download/v2.0.0/rcedit-x64.exe"
    Invoke-WebRequest -Uri $url -OutFile $local -UseBasicParsing
    return $local
}

function Update-StealthBrandText {
    param([string]$Text)
    $Text = $Text -replace '(?m)^(-brand-shorter-name\s*=\s*).*$', '${1}Stealth'
    $Text = $Text -replace '(?m)^(-brand-short-name\s*=\s*).*$', '${1}Stealth'
    $Text = $Text -replace '(?m)^(-brand-shortcut-name\s*=\s*).*$', '${1}Stealth'
    $Text = $Text -replace '(?m)^(-brand-full-name\s*=\s*).*$', '${1}Stealth'
    $Text = $Text -replace '(?m)^(-brand-product-name\s*=\s*).*$', '${1}Stealth'
    $Text = $Text -replace '(?m)^(brandShorterName\s*=\s*).*$', '${1}Stealth'
    $Text = $Text -replace '(?m)^(brandShortName\s*=\s*).*$', '${1}Stealth'
    $Text = $Text -replace '(?m)^(brandShortcutName\s*=\s*).*$', '${1}Stealth'
    $Text = $Text -replace '(?m)^(brandFullName\s*=\s*).*$', '${1}Stealth'
    $Text = $Text -replace '(?m)^(brandProductName\s*=\s*).*$', '${1}Stealth'
    $Text = $Text -replace 'Mozilla Firefox', 'Stealth'
    $Text = $Text -replace '(?m)^(brand\w+\s*=\s*)Firefox\s*$', '${1}Stealth'
    return $Text
}

function Update-StealthLangpackText {
    param([string]$Text)

    $Text = Update-StealthBrandText -Text $Text
    $Text = $Text -replace '(?m)^(tabbrowser-empty-tab-title\s*=\s*).*$', '${1}Stealth'
    $Text = $Text -replace '(?m)^(tabbrowser-empty-private-tab-title\s*=\s*).*$', '${1}Stealth'
    $Text = $Text -replace '(?m)^(newtab-page-title\s*=\s*).*$', '${1}Stealth'
    return $Text
}

function Test-StealthLocalePatchEntry {
    param([string]$EntryName)
    if ([string]::IsNullOrEmpty($EntryName)) { return $false }
    return $EntryName -match 'branding/brand\.(ftl|properties)$|branding/brandings\.ftl$|browser/tabbrowser\.ftl$|browser/newtab/newtab\.ftl$|browser/browser\.ftl$|locales/.+/browser/newtab/newtab\.ftl$'
}

function Patch-StealthLocaleXpi {
    param(
        [string]$XpiPath,
        [string]$Label
    )

    $zip = [System.IO.Compression.ZipFile]::Open($XpiPath, [System.IO.Compression.ZipArchiveMode]::Update)
    $patched = 0
    try {
        foreach ($entry in @($zip.Entries)) {
            if (-not (Test-StealthLocalePatchEntry -EntryName $entry.FullName)) { continue }
            $reader = New-Object System.IO.StreamReader($entry.Open())
            $text = $reader.ReadToEnd()
            $reader.Close()
            $newText = Update-StealthLangpackText -Text $text
            if ($newText -eq $text) { continue }
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($newText)
            Set-StealthOmniZipEntry -Zip $zip -EntryName $entry.FullName -Bytes $bytes
            $patched++
        }
    }
    finally {
        $zip.Dispose()
    }
    if ($patched -gt 0) {
        Write-SetupLog "Patched $Label ($patched files)" "Ok"
    }
}

function Patch-StealthProfileLangpack {
    param([string]$ProfilePath)

    if (-not $ProfilePath) { return }
    $extDir = Join-Path $ProfilePath 'extensions'
    if (-not (Test-Path $extDir)) { return }

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    foreach ($xpi in Get-ChildItem $extDir -Filter 'langpack-*.xpi' -ErrorAction SilentlyContinue) {
        Patch-StealthLocaleXpi -XpiPath $xpi.FullName -Label "langpack $($xpi.Name)"
    }

    $newtab = Join-Path $extDir 'newtab@mozilla.org.xpi'
    if (Test-Path $newtab) {
        Patch-StealthLocaleXpi -XpiPath $newtab -Label 'newtab extension'
    }
}

function Set-StealthOmniZipEntry {
    param(
        [System.IO.Compression.ZipArchive]$Zip,
        [string]$EntryName,
        [byte[]]$Bytes
    )

    $existing = $Zip.GetEntry($EntryName)
    if ($existing) { $existing.Delete() }
    $entry = $Zip.CreateEntry($EntryName, [System.IO.Compression.CompressionLevel]::Optimal)
    $stream = $entry.Open()
    try { $stream.Write($Bytes, 0, $Bytes.Length) }
    finally { $stream.Close() }
}

function Export-StealthIconPngBytes {
    param(
        [string]$IconPath,
        [int]$Size
    )

    Add-Type -AssemblyName System.Drawing
    $icon = New-Object System.Drawing.Icon $IconPath
    $source = $icon.ToBitmap()
    $bitmap = New-Object System.Drawing.Bitmap $Size, $Size
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.DrawImage($source, 0, 0, $Size, $Size)
    $graphics.Dispose()
    $source.Dispose()
    $icon.Dispose()

    $stream = New-Object System.IO.MemoryStream
    $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
    return $stream.ToArray()
}

function Copy-StealthOmniBrandingIconsFromSource {
    param(
        [System.IO.Compression.ZipArchive]$TargetZip,
        [string]$EngineRoot
    )

    $sourceOmni = Join-Path ${env:ProgramFiles} "Mozilla Firefox\browser\omni.ja"
    if (-not (Test-Path $sourceOmni)) {
        Write-SetupLog "Source omni.ja not found, keeping existing tab icons" "Warn"
        return
    }

    $sourceZip = [System.IO.Compression.ZipFile]::OpenRead($sourceOmni)
    try {
        foreach ($entryName in @(
                "chrome/browser/content/branding/icon16.png",
                "chrome/browser/content/branding/icon32.png",
                "chrome/browser/content/branding/icon48.png",
                "chrome/browser/content/branding/icon64.png",
                "chrome/browser/content/branding/icon128.png",
                "chrome/browser/content/branding/document.ico"
            )) {
            $sourceEntry = $sourceZip.GetEntry($entryName)
            if (-not $sourceEntry) { continue }
            $reader = $sourceEntry.Open()
            $ms = New-Object System.IO.MemoryStream
            $reader.CopyTo($ms)
            $reader.Close()
            Set-StealthOmniZipEntry -Zip $TargetZip -EntryName $entryName -Bytes $ms.ToArray()
            $ms.Dispose()
        }
    }
    finally {
        $sourceZip.Dispose()
    }

    Write-SetupLog "Restored tab/favicon icons from Mozilla source" "Detail"
}

function Add-StealthOmniCssBlock {
    param(
        [string]$Css,
        [string]$Marker,
        [string]$Block
    )

    if ($Css -match [regex]::Escape($Marker)) {
        return $Css
    }
    return ($Css.TrimEnd() + "`n`n" + $Block.Trim() + "`n")
}

function Set-StealthToolkitOmniStyling {
    param([System.IO.Compression.ZipArchive]$Zip)

    $monoFilter = "grayscale(1) brightness(0.4) contrast(1.12)"
    $patches = @{
        "chrome/toolkit/content/global/elements/moz-promo.css" = @"
/* Stealth: black default-browser promo + monochrome illustrations */
.image-container img {
  filter: $monoFilter;
  opacity: 0.88;
}

:host,
:host([type="default"]),
:host([type="vibrant"]) {
  --promo-message-text-color: #d0d0d0;
  --promo-heading-text-color: #e8e8e8;
  --promo-background-color: #000000;
  --promo-border-color: #1a1a1a;
}

.container {
  background-color: #000000;
  border-color: #1a1a1a;
  color: #d0d0d0;
}
"@
        "chrome/toolkit/content/global/elements/moz-page-nav-button.css" = @"
/* Stealth: monochrome settings sidebar icons */
.page-nav-icon {
  filter: $monoFilter;
  opacity: 0.88;
}
"@
        "chrome/toolkit/content/global/elements/moz-page-nav.css" = @"
/* Stealth: monochrome settings heading logo */
.page-nav-heading-wrapper > .logo {
  filter: $monoFilter;
  opacity: 0.88;
}
"@
    }

    foreach ($entryName in $patches.Keys) {
        $entry = $Zip.GetEntry($entryName)
        if (-not $entry) {
            Write-SetupLog "Toolkit entry missing: $entryName" "Warn"
            continue
        }
        $reader = New-Object System.IO.StreamReader($entry.Open())
        $css = $reader.ReadToEnd()
        $reader.Close()
        $css = Add-StealthOmniCssBlock -Css $css -Marker "/* Stealth:" -Block $patches[$entryName]
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($css)
        Set-StealthOmniZipEntry -Zip $Zip -EntryName $entryName -Bytes $bytes
    }
}

function Set-StealthBrowserOmniStyling {
    param([System.IO.Compression.ZipArchive]$Zip)

    $entryName = "chrome/browser/content/browser/aboutwelcome/aboutwelcome.css"
    $entry = $Zip.GetEntry($entryName)
    if (-not $entry) {
        Write-SetupLog "Browser entry missing: $entryName" "Warn"
        return
    }

    $reader = New-Object System.IO.StreamReader($entry.Open())
    $css = $reader.ReadToEnd()
    $reader.Close()

    $block = @"
/* Stealth: black default-browser / spotlight callout */
:root,
.onboardingContainer,
#feature-callout,
#feature-callout .onboardingContainer,
#feature-callout .screen[pos=callout] .section-main .main-content {
  --fc-background: #000000 !important;
  --fc-background-dark: #000000 !important;
  --fc-background-light: #000000 !important;
  --fc-message-text-color: #d0d0d0 !important;
  --fc-heading-text-color: #e8e8e8 !important;
  --fc-button-background: #111111 !important;
  --fc-button-background-hover: #1a1a1a !important;
  --fc-button-background-active: #222222 !important;
  --fc-button-text-color: #e8e8e8 !important;
  --fc-primary-button-background: #00d9b8 !important;
  --fc-primary-button-background-hover: #00e8c8 !important;
  --fc-primary-button-background-active: #00c4a5 !important;
  --fc-primary-button-text-color: #000000 !important;
  --fc-dismiss-button-background: transparent !important;
  --fc-dismiss-button-background-hover: #111111 !important;
  --fc-dismiss-button-background-active: #1a1a1a !important;
  --fc-dismiss-button-text-color: #d0d0d0 !important;
  --fc-dismiss-button-text-color-hover: #ffffff !important;
  background: #000000 !important;
  background-color: #000000 !important;
  color: #d0d0d0 !important;
}

#feature-callout .screen[pos=callout] .section-main .main-content {
  border: 1px solid #1a1a1a !important;
  box-shadow: none !important;
}

#feature-callout .screen[pos=callout] .section-main .dismiss-button,
#feature-callout .screen[pos=callout] .section-main .more-button,
#feature-callout button,
#feature-callout .primary-button {
  box-shadow: none !important;
}
"@

    $css = Add-StealthOmniCssBlock -Css $css -Marker "/* Stealth: black default-browser" -Block $block
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($css)
    Set-StealthOmniZipEntry -Zip $Zip -EntryName $entryName -Bytes $bytes
}

function Set-StealthOmniBranding {
    param(
        [string]$EngineRoot,
        [string]$IconPath
    )

    $browserOmniPath = Join-Path $EngineRoot "browser\omni.ja"
    $toolkitOmniPath = Join-Path $EngineRoot "omni.ja"
    if (-not (Test-Path $browserOmniPath)) {
        Write-SetupLog "browser/omni.ja not found, skipping internal branding patch" "Warn"
        return
    }

    $stampPath = Join-Path $EngineRoot ".omni-branded"
    if ((Test-Path $stampPath) -and ((Get-Content $stampPath -Raw).Trim() -eq "7")) {
        return
    }

    Write-Step "Patching Stealth branding (taskbar name + icon)..."
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $zip = [System.IO.Compression.ZipFile]::Open($browserOmniPath, [System.IO.Compression.ZipArchiveMode]::Update)
    try {
        Set-StealthBrowserOmniStyling -Zip $zip

        foreach ($entry in @($zip.Entries | Where-Object { $_.FullName -match 'branding/brand\.(ftl|properties)$' })) {
            $reader = New-Object System.IO.StreamReader($entry.Open())
            $text = Update-StealthBrandText -Text $reader.ReadToEnd()
            $reader.Close()
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
            Set-StealthOmniZipEntry -Zip $zip -EntryName $entry.FullName -Bytes $bytes
        }

        Copy-StealthOmniBrandingIconsFromSource -TargetZip $zip -EngineRoot $EngineRoot

        $enGbBrand = $zip.GetEntry('chrome/en-GB/locale/branding/brand.properties')
        if ($enGbBrand) {
            $reader = New-Object System.IO.StreamReader($enGbBrand.Open())
            $brandProps = Update-StealthBrandText -Text $reader.ReadToEnd()
            $reader.Close()
            $brandBytes = [System.Text.Encoding]::UTF8.GetBytes($brandProps)
            foreach ($entryName in @(
                    'chrome/en-GB/locale/branding/brand.properties',
                    'chrome/en-US/locale/branding/brand.properties'
                )) {
                Set-StealthOmniZipEntry -Zip $zip -EntryName $entryName -Bytes $brandBytes
            }
        }
    }
    finally {
        $zip.Dispose()
    }

    if (Test-Path $toolkitOmniPath) {
        $toolkitZip = [System.IO.Compression.ZipFile]::Open($toolkitOmniPath, [System.IO.Compression.ZipArchiveMode]::Update)
        try {
            Set-StealthToolkitOmniStyling -Zip $toolkitZip
        }
        finally {
            $toolkitZip.Dispose()
        }
        Write-SetupLog "Patched toolkit/omni.ja settings styling" "Detail"
    }

    Write-TextFileNoBom -Path $stampPath -Content "7"
    Write-SetupLog "Patched browser/omni.ja branding" "Detail"
}

function Set-StealthVisualElements {
    param(
        [string]$EngineRoot,
        [string]$IconPath
    )

    if (-not (Test-Path $IconPath)) { return }
    $veDir = Join-Path $EngineRoot "browser\VisualElements"
    if (-not (Test-Path $veDir)) { return }

    foreach ($size in @(70, 150)) {
        $png = Export-StealthIconPngBytes -IconPath $IconPath -Size $size
        [System.IO.File]::WriteAllBytes((Join-Path $veDir "VisualElements_$size.png"), $png)
    }
    Write-SetupLog "Updated VisualElements icons" "Detail"
}

function Set-StealthEngineExeBranding {
    param(
        [string]$EngineRoot,
        [string]$IconPath,
        [string]$Rcedit
    )

    $targets = @(
        @{ Name = "firefox.exe"; Product = "Stealth"; Description = "Stealth" },
        @{ Name = "plugin-container.exe"; Product = "Stealth"; Description = "Stealth" },
        @{ Name = "private_browsing.exe"; Product = "Stealth"; Description = "Stealth" }
    )

    foreach ($target in $targets) {
        $exe = Join-Path $EngineRoot $target.Name
        if (-not (Test-Path $exe)) { continue }
        $args = @(
            $exe,
            "--set-version-string", "ProductName", $target.Product,
            "--set-version-string", "FileDescription", $target.Description,
            "--set-version-string", "InternalName", "Stealth",
            "--set-version-string", "OriginalFilename", "Stealth.exe"
        )
        if ($target.Name -eq "firefox.exe" -and (Test-Path $IconPath)) {
            $args += @("--set-icon", $IconPath)
        }
        & $rcedit @args
        if ($LASTEXITCODE -ne 0) {
            throw "rcedit failed for $($target.Name) with exit code $LASTEXITCODE"
        }
    }
}

function Set-StealthEngineBranding {
    param(
        [string]$EngineRoot,
        [string]$IconPath
    )

    $engineExe = Join-Path $EngineRoot "firefox.exe"
    if (-not (Test-Path $engineExe)) { throw "Engine firefox.exe not found." }

    $iniPath = Join-Path $EngineRoot "application.ini"
    if (Test-Path $iniPath) {
        $ini = Get-Content $iniPath -Raw
        $ini = $ini -replace '(?m)^Name=.*$', 'Name=Firefox'
        $ini = $ini -replace '(?m)^RemotingName=.*$', 'RemotingName=stealth'
        $utf8 = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($iniPath, $ini, $utf8)
    }

    if (-not (Test-Path $IconPath)) {
        $IconPath = Join-Path $EngineRoot "browser\visualElements\VisualElements_150.png"
    }

    Set-StealthOmniBranding -EngineRoot $EngineRoot -IconPath $IconPath
    Set-StealthVisualElements -EngineRoot $EngineRoot -IconPath $IconPath

    $rcedit = Get-RceditPath
    Set-StealthEngineExeBranding -EngineRoot $EngineRoot -IconPath $IconPath -Rcedit $rcedit
}

function Get-StealthBundleDistributionDir {
    foreach ($path in @(
            (Join-Path $script:InstallScriptDir "bundle\templates\distribution"),
            (Join-Path $script:InstallScriptDir "bundle\distribution"),
            (Join-Path $script:InstallScriptDir "_bundle\templates\distribution")
        )) {
        if (Test-Path $path) { return $path }
    }
    return $null
}

function Get-StealthDistributionPoliciesObject {
    @{
        policies = @{
            DisableTelemetry          = $true
            DisableFirefoxStudies     = $true
            DisableRemoteImprovements = $true
            NetworkPrediction         = $false
            DisablePocket             = $true
            SearchEngines = @{
                Add = @(
                    @{
                        Name        = "SearXNG"
                        URLTemplate = "https://searx.tiekoetter.com/search?q={searchTerms}&language=ru-RU"
                        Encoding    = "UTF-8"
                        Method      = "GET"
                        IconURL     = "https://searx.tiekoetter.com/static/themes/simple/img/favicon.png"
                    }
                )
                Default = "SearXNG"
            }
            Preferences = @{
                "browser.taskbar.lists.enabled"          = $false
                "browser.taskbar.lists.tasks.enabled"    = $false
                "browser.taskbar.lists.frequent.enabled" = $false
                "browser.taskbar.lists.recent.enabled"   = $false
                "taskbar.grouping.useprofile"            = $false
                "intl.accept_languages"                  = "ru-RU, ru, en-US, en"
            }
        }
    }
}

function Write-StealthDistributionPolicies {
    param([string]$EngineRoot)

    $distDir = Join-Path $EngineRoot "distribution"
    New-Item -ItemType Directory -Force -Path $distDir | Out-Null

    $policies = Get-StealthDistributionPoliciesObject | ConvertTo-Json -Depth 6
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    $dest = Join-Path $distDir "policies.json"

    try {
        [System.IO.File]::WriteAllText($dest, $policies, $utf8NoBom)
    }
    catch {
        $tempPolicies = Join-Path $env:TEMP ("stealth-browser-policies-{0}.json" -f [guid]::NewGuid().ToString('n'))
        [System.IO.File]::WriteAllText($tempPolicies, $policies, $utf8NoBom)
        $cmd = "New-Item -ItemType Directory -Force -Path '$distDir' | Out-Null; Copy-Item -Force '$tempPolicies' '$dest'"
        Start-Process powershell.exe -Verb RunAs -ArgumentList @("-NoProfile", "-Command", $cmd) -Wait | Out-Null
        Remove-Item $tempPolicies -Force -ErrorAction SilentlyContinue
    }

    $srcDistribution = Get-StealthBundleDistributionDir
    if ($srcDistribution) {
        $srcPlugins = Join-Path $srcDistribution "searchplugins"
        if (Test-Path $srcPlugins) {
            $destPlugins = Join-Path $distDir "searchplugins"
            if (Test-Path $destPlugins) {
                Remove-Item $destPlugins -Recurse -Force -ErrorAction SilentlyContinue
            }
            Copy-Item $srcPlugins $destPlugins -Recurse -Force
        }
    }
}

function Install-StealthDistributionConfig {
    param([string]$EngineRoot)

    Write-StealthDistributionPolicies -EngineRoot $EngineRoot
    Write-SetupLog "Default search: SearXNG (searx.tiekoetter.com)" "Ok"
}

function Sync-StealthEngine {
    param(
        [string]$Version = "151.0.3"
    )

    $source = Get-MozillaFirefoxSource
    if (-not $source) {
        throw "Mozilla Firefox is not installed. Run full Stealth setup first."
    }

    if ($source.Version -ne $Version) {
        Write-SetupLog "Mozilla $($source.Version) installed, Stealth wants $Version" "Warn"
    }

    $engineRoot = Get-StealthEngineRoot
    $stampPath = Join-Path $engineRoot ".engine-version"
    $engineExe = Join-Path $engineRoot "firefox.exe"
    $needsSync = -not (Test-Path $engineExe) -or -not (Test-Path $stampPath) -or ((Get-Content $stampPath -Raw).Trim() -ne $source.Version)

    $iconPath = Join-Path $script:InstallScriptDir "branding\stealth-dark.ico"
    if (-not (Test-Path $iconPath)) {
        $iconPath = Join-Path $script:InstallScriptDir "bundle\assets\stealth-dark.ico"
    }
    if (-not (Test-Path $iconPath)) {
        $iconPath = Join-Path $env:LOCALAPPDATA "LLG_Relicus\stealth-dark.ico"
    }

    if ($needsSync) {
        Write-Step "Building Stealth engine (branded copy)..."
        New-Item -ItemType Directory -Force -Path $engineRoot | Out-Null

        $robolog = Join-Path $env:TEMP ("stealth-engine-robo-" + [guid]::NewGuid().ToString("n") + ".log")
        & robocopy $source.Dir $engineRoot /MIR /XD "uninstall" /R:1 /W:1 /NFL /NDL /NJH /NJS /nc /ns /np /LOG:$robolog | Out-Null
        if ($LASTEXITCODE -ge 8) {
            throw "Failed to copy Firefox engine (robocopy $LASTEXITCODE)."
        }

        Write-TextFileNoBom -Path $stampPath -Content $source.Version
        Write-SetupLog "Engine: $engineExe" "Detail"
    }

    Set-StealthEngineBranding -EngineRoot $engineRoot -IconPath $iconPath
    Install-StealthDistributionConfig -EngineRoot $engineRoot
    return $engineExe
}

function Clear-StealthProfileStartupCache {
    param([string]$ProfilePath)

    if (-not $ProfilePath) { return }
    foreach ($dir in @("startupCache", "minidumps")) {
        $path = Join-Path $ProfilePath $dir
        if (Test-Path $path) {
            Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-SetupLog "Cleared $dir" "Detail"
        }
    }
}

function Get-InstalledStealth {
    $engineExe = Join-Path (Get-StealthEngineRoot) "firefox.exe"
    if (Test-Path $engineExe) {
        $info = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($engineExe)
        $ver = if ($info.ProductVersion -match "(\d+\.\d+\.\d+)") { $Matches[1] } else { $info.ProductVersion }
        return [PSCustomObject]@{
            Path    = $engineExe
            Version = $ver
            IsEngine = $true
        }
    }

    $source = Get-MozillaFirefoxSource
    if ($source) {
        return [PSCustomObject]@{
            Path    = $source.Path
            Version = $source.Version
            IsEngine = $false
        }
    }
    return $null
}
