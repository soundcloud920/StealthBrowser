#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'Stealth-Update.ps1')
. (Join-Path $root 'Stealth-Engine.ps1')

function Write-SetupLog {
    param([string]$Message, [string]$Level = 'Info')
    switch ($Level) {
        'Step' { Write-Host ">> $Message" -ForegroundColor Cyan; break }
        'Warn' { Write-Host "   $Message" -ForegroundColor Yellow; break }
        'Detail' { Write-Host "   $Message" -ForegroundColor DarkYellow; break }
        default { Write-Host $Message }
    }
}
function Write-Step($msg) { Write-SetupLog $msg 'Step' }
function Write-TextFileNoBom {
    param([string]$Path, [string]$Content)
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [IO.File]::WriteAllText($Path, $Content, $utf8)
}

$engine = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine'
$iconCandidates = @(
    (Join-Path $root 'bundle\assets\stealth-dark.ico'),
    (Join-Path $env:LOCALAPPDATA 'LLG_Relicus\stealth-dark.ico'),
    'C:\Users\france\Desktop\stealth\branding\stealth-dark.ico'
)
$icon = $iconCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

$stamp = Join-Path $engine '.omni-branded'
if (Test-Path $stamp) { Remove-Item $stamp -Force }

Set-StealthOmniBranding -EngineRoot $engine -IconPath $icon

$profileChrome = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles\kn9q3hkf.stealth\chrome'
New-Item -ItemType Directory -Force -Path $profileChrome | Out-Null
Copy-Item (Join-Path $root 'bundle\templates\userContent.css') (Join-Path $profileChrome 'userContent.css') -Force

Write-Host "Engine omni stamp: $((Get-Content $stamp -Raw).Trim())"
Write-Host "userContent.css -> $profileChrome"
