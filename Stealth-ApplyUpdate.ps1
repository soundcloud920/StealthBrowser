#Requires -Version 5.1
$ErrorActionPreference = "Stop"

try {
    if ($Host.Name -eq "ConsoleHost") {
        $Host.UI.RawUI.WindowTitle = "StealthBrowser — обновление"
    }
}
catch {
    # Non-interactive host.
}

function Write-StealthUpdateStep {
    param([string]$Message)
    $stamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$stamp] $Message"
}

$launcherRoot = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { $PSScriptRoot }
. (Join-Path $launcherRoot "Install-Stealth.ps1")
. (Join-Path $launcherRoot "Stealth-Update.ps1")

$config = Get-StealthLaunchConfig
if (-not $config) {
    Write-StealthUpdateStep "Конфигурация Stealth не найдена."
    Read-Host "Нажмите Enter для выхода"
    exit 1
}

$markerVer = $config.SetupVersion
if ($config.ProfilePath -and (Get-Command Get-StealthProfileMarker -ErrorAction SilentlyContinue)) {
    $marker = Get-StealthProfileMarker -ProfilePath $config.ProfilePath
    if ($marker) { $markerVer = $marker.SetupVersion }
}

Write-StealthUpdateStep "Текущая версия: v$markerVer"
Write-StealthUpdateStep "Проверка обновлений на GitHub..."

try {
    $offer = Get-StealthUpdateOffer `
        -CurrentVersion $markerVer `
        -GitHubRepo $config.GitHubRepo `
        -DismissedVersion $config.DismissedVersion `
        -UseCache

    if (-not $offer.Available) {
        if ($offer.Error) {
            Write-StealthUpdateStep "Проверка не удалась: $($offer.Error)"
        }
        else {
            Write-StealthUpdateStep "Обновление не требуется."
        }
        Read-Host "Нажмите Enter для выхода"
        exit 0
    }

    Write-StealthUpdateStep "Найдено обновление v$($offer.LatestVersion). Скачивание и установка..."
    Install-StealthReleaseUpdate -Release $offer.Release -InstallScriptDir $launcherRoot
    Write-StealthUpdateStep "Готово. Установлена версия v$($offer.LatestVersion)."
    Write-StealthUpdateStep "Закройте Stealth и запустите снова через ярлык."
}
catch {
    Write-StealthUpdateStep "Ошибка: $($_.Exception.Message)"
    Read-Host "Нажмите Enter для выхода"
    exit 1
}

Read-Host "Нажмите Enter для выхода"
