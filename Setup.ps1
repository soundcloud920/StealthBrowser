#Requires -Version 5.1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (-not ('Stealth.DwmApi' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class StealthDwm {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
    public const int UseImmersiveDarkModeLegacy = 19;
    public const int UseImmersiveDarkMode = 20;
    public const int CaptionColor = 35;
    public const int TextColor = 36;
}
'@
}

function Set-StealthFormDarkTitleBar {
    param([System.Windows.Forms.Form]$Form)

    if (-not $Form.IsHandleCreated) {
        $Form.Add_HandleCreated({
            param($sender, $eventArgs)
            Set-StealthFormDarkTitleBar -Form $sender
        })
        return
    }

    $enabled = 1
    [void][StealthDwm]::DwmSetWindowAttribute($Form.Handle, [StealthDwm]::UseImmersiveDarkMode, [ref]$enabled, 4)
    [void][StealthDwm]::DwmSetWindowAttribute($Form.Handle, [StealthDwm]::UseImmersiveDarkModeLegacy, [ref]$enabled, 4)

    $captionColor = 0x000000
    $textColor = 0x00D0D0D0
    [void][StealthDwm]::DwmSetWindowAttribute($Form.Handle, [StealthDwm]::CaptionColor, [ref]$captionColor, 4)
    [void][StealthDwm]::DwmSetWindowAttribute($Form.Handle, [StealthDwm]::TextColor, [ref]$textColor, 4)
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$installScript = Join-Path $scriptRoot "Install-Stealth.ps1"
if (-not (Test-Path $installScript)) {
    [System.Windows.Forms.MessageBox]::Show("Install-Stealth.ps1 not found.", "Stealth", "OK", "Error") | Out-Null
    exit 1
}

. $installScript

$ColorBg      = [System.Drawing.Color]::FromArgb(0, 0, 0)
$ColorSurface = [System.Drawing.Color]::FromArgb(10, 10, 10)
$ColorLine    = [System.Drawing.Color]::FromArgb(26, 26, 26)
$ColorText    = [System.Drawing.Color]::FromArgb(208, 208, 208)
$ColorMuted   = [System.Drawing.Color]::FromArgb(138, 138, 138)
$ColorOk      = [System.Drawing.Color]::FromArgb(120, 200, 120)
$ColorWarn    = [System.Drawing.Color]::FromArgb(220, 180, 80)
$ColorMissing = [System.Drawing.Color]::FromArgb(195, 115, 115)
$ColorError   = [System.Drawing.Color]::FromArgb(220, 100, 100)

function Get-StealthBrandFontPath {
    param([string]$Root)

    foreach ($path in @(
            (Join-Path $Root 'fonts\LLG_Relicus-Regular.ttf'),
            (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts\LLG_Relicus-Regular.ttf')
        )) {
        if (Test-Path $path) { return $path }
    }

    $zipPath = Join-Path $Root 'bundle.zip'
    if (-not (Test-Path $zipPath)) { return $null }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $entry = [System.IO.Compression.ZipFile]::OpenRead($zipPath).GetEntry('LLG_Relicus-Regular.ttf')
    if (-not $entry) { return $null }

    $destDir = Join-Path $env:TEMP 'StealthSetupFonts'
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    $fontFile = Join-Path $destDir 'LLG_Relicus-Regular.ttf'
    if (-not (Test-Path $fontFile)) {
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $fontFile, $true)
    }
    return $fontFile
}

function Initialize-StealthUiFonts {
    param([string]$Root)

    $script:StealthUiFamily = $null
    $fontFile = Get-StealthBrandFontPath -Root $Root
    if (-not $fontFile) { return }

    $script:StealthFontCollection = New-Object System.Drawing.Text.PrivateFontCollection
    $script:StealthFontCollection.AddFontFile($fontFile)
    $script:StealthUiFamily = $script:StealthFontCollection.Families[0]
}

function New-StealthUiFont {
    param([float]$Size = 9)

    if ($script:StealthUiFamily) {
        return New-Object System.Drawing.Font(
            $script:StealthUiFamily, $Size, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)
    }
    return New-Object System.Drawing.Font('Segoe UI', $Size, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)
}

function Set-FlatButtonTheme {
    param(
        [System.Windows.Forms.Button]$Button,
        [switch]$Primary
    )

    if ($Primary) {
        $Button.ForeColor = [System.Drawing.Color]::Black
        $Button.BackColor = [System.Drawing.Color]::FromArgb(0, 217, 184)
        $Button.UseVisualStyleBackColor = $false
        $Button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(0, 217, 184)
        $Button.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(0, 232, 200)
        $Button.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(0, 196, 165)
        return
    }

    $Button.ForeColor = $ColorText
    $Button.BackColor = $ColorSurface
    $Button.UseVisualStyleBackColor = $false
    $Button.FlatAppearance.BorderColor = $ColorLine
    $Button.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(26, 26, 26)
    $Button.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(34, 34, 34)
}

function Get-StealthVersionSegments {
    param(
        [string]$Text,
        [System.Drawing.Color]$BaseColor,
        [string[]]$AccentWords,
        [System.Drawing.Color]$AccentColor
    )

    $segments = New-Object System.Collections.Generic.List[object]
    $remaining = $Text
    while ($remaining.Length -gt 0) {
        $bestIdx = -1
        $bestWord = $null
        foreach ($word in $AccentWords) {
            if ([string]::IsNullOrEmpty($word)) { continue }
            $idx = $remaining.IndexOf($word, [System.StringComparison]::Ordinal)
            if ($idx -ge 0 -and ($bestIdx -lt 0 -or $idx -lt $bestIdx)) {
                $bestIdx = $idx
                $bestWord = $word
            }
        }

        if ($bestIdx -lt 0) {
            $segments.Add([PSCustomObject]@{ Text = $remaining; Color = $BaseColor })
            break
        }

        if ($bestIdx -gt 0) {
            $segments.Add([PSCustomObject]@{
                Text  = $remaining.Substring(0, $bestIdx)
                Color = $BaseColor
            })
        }

        $segments.Add([PSCustomObject]@{
            Text  = $bestWord
            Color = $AccentColor
        })
        $remaining = $remaining.Substring($bestIdx + $bestWord.Length)
    }

    return $segments
}

function Set-StealthVersionLabel {
    param(
        [string]$Text,
        [System.Drawing.Color]$BaseColor = $ColorMuted,
        [string[]]$AccentWords = @('не найден'),
        [System.Drawing.Color]$AccentColor = $ColorMissing,
        [int]$MaxWidth = 452,
        [int]$MinHeight = 20
    )

    $pnlVersion.Controls.Clear()

    if (-not $Text) {
        $pnlVersion.Size = New-Object System.Drawing.Size($MaxWidth, $MinHeight)
        return
    }

    $lineY = 0
    foreach ($line in ($Text -split "`r?`n")) {
        $segments = Get-StealthVersionSegments -Text $line -BaseColor $BaseColor -AccentWords $AccentWords -AccentColor $AccentColor
        $x = 0
        $rowHeight = 0

        foreach ($segment in $segments) {
            $segSize = [System.Windows.Forms.TextRenderer]::MeasureText(
                $segment.Text,
                $uiFont,
                (New-Object System.Drawing.Size($MaxWidth, [int]::MaxValue)),
                [System.Windows.Forms.TextFormatFlags]::NoPadding)

            if ($x -gt 0 -and ($x + $segSize.Width) -gt $MaxWidth) {
                $lineY += $rowHeight + 2
                $x = 0
                $rowHeight = 0
            }

            $lbl = New-Object System.Windows.Forms.Label
            $lbl.AutoSize = $true
            $lbl.Text = $segment.Text
            $lbl.ForeColor = $segment.Color
            $lbl.BackColor = $ColorBg
            $lbl.Font = $uiFont
            $lbl.Margin = New-Object System.Windows.Forms.Padding(0)
            $lbl.Location = New-Object System.Drawing.Point($x, $lineY)
            $pnlVersion.Controls.Add($lbl) | Out-Null

            $x += $segSize.Width
            $rowHeight = [Math]::Max($rowHeight, $segSize.Height)
        }

        $lineY += $rowHeight + 4
    }

    $flags = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor `
        [System.Windows.Forms.TextFormatFlags]::TextBoxControl
    $size = [System.Windows.Forms.TextRenderer]::MeasureText(
        $Text,
        $uiFont,
        (New-Object System.Drawing.Size($MaxWidth, [int]::MaxValue)),
        $flags)
    $height = [Math]::Max($MinHeight, [Math]::Max(($lineY - 4), $size.Height + 2))
    $pnlVersion.Size = New-Object System.Drawing.Size($MaxWidth, $height)
}

function Set-StealthWrappedLabel {
    param(
        [System.Windows.Forms.Label]$Label,
        [string]$Text,
        [int]$MaxWidth = 452,
        [int]$MinHeight = 20
    )

    $Label.Text = $Text
    $flags = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor `
        [System.Windows.Forms.TextFormatFlags]::TextBoxControl
    $size = [System.Windows.Forms.TextRenderer]::MeasureText(
        $Text,
        $Label.Font,
        (New-Object System.Drawing.Size($MaxWidth, [int]::MaxValue)),
        $flags)
    $height = [Math]::Max($MinHeight, $size.Height + 2)
    $Label.Size = New-Object System.Drawing.Size($MaxWidth, $height)
}

function Update-InstallStatusText {
    param([string]$Text)

    Set-StealthWrappedLabel -Label $lblStatus -Text $Text -MinHeight 22
    Sync-InstallFormLayout
}

function Sync-InstallFormLayout {
    $y = $pnlVersion.Location.Y + $pnlVersion.Size.Height + 6
    $chkProfileOnly.Location = New-Object System.Drawing.Point(26, $y)
    $y += $chkProfileOnly.Size.Height + 8
    $btnInstall.Location = New-Object System.Drawing.Point(24, $y)
    $y += $btnInstall.Size.Height + 10
    $lblStatus.Location = New-Object System.Drawing.Point(26, $y)
    $y += $lblStatus.Size.Height + 8

    if ($progressBar.Visible) {
        $progressBar.Location = New-Object System.Drawing.Point(24, $y)
        $y += $progressBar.Size.Height + 10
    }

    if ($logPanel.Visible) {
        $logHeight = [Math]::Max(120, 438 - $y)
        $logPanel.Location = New-Object System.Drawing.Point(24, $y)
        $logPanel.Size = New-Object System.Drawing.Size(452, $logHeight)
    }
}

function New-FlatButton {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$W,
        [int]$H,
        [System.Windows.Forms.Form]$Parent,
        [System.Drawing.Font]$Font = $null
    )

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Location = New-Object System.Drawing.Point($X, $Y)
    $btn.Size = New-Object System.Drawing.Size($W, $H)
    $btn.FlatStyle = "Flat"
    $btn.FlatAppearance.BorderSize = 1
    $btn.FlatAppearance.BorderColor = $ColorLine
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    if ($Font) { $btn.Font = $Font }
    Set-FlatButtonTheme -Button $btn
    $Parent.Controls.Add($btn) | Out-Null
    return $btn
}

$logQueue = New-Object System.Collections.Concurrent.ConcurrentQueue[string]
$statusQueue = New-Object System.Collections.Concurrent.ConcurrentQueue[string]
$progressQueue = New-Object System.Collections.Concurrent.ConcurrentQueue[object]

$form = New-Object System.Windows.Forms.Form
$form.Text = "StealthBrowser"
$form.BackColor = $ColorBg
$form.ForeColor = $ColorText
$form.ClientSize = New-Object System.Drawing.Size(500, 480)
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ControlBox = $false
$form.StartPosition = "CenterScreen"
$script:allowFormClose = $false
Set-StealthFormDarkTitleBar -Form $form

$iconPath = Join-Path $scriptRoot "branding\stealth-dark.ico"
if (-not (Test-Path $iconPath)) {
    $iconPath = Join-Path $scriptRoot "bundle\assets\stealth-dark.ico"
}
if (Test-Path $iconPath) {
    $form.Icon = New-Object System.Drawing.Icon($iconPath)
}

Initialize-StealthUiFonts -Root $scriptRoot
$titleFont = New-StealthUiFont -Size 24
$uiFont = New-StealthUiFont -Size 9
$logFont = New-StealthUiFont -Size 8.5
$btnFont = New-StealthUiFont -Size 10
$form.Font = $uiFont

$facePath = Join-Path $scriptRoot "branding\search-face-32.png"
if (-not (Test-Path $facePath)) {
    $facePath = Join-Path $scriptRoot "bundle\assets\search-face-32.png"
}

$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = New-Object System.Drawing.Point(24, 16)
$headerPanel.Size = New-Object System.Drawing.Size(452, 44)
$headerPanel.BackColor = $ColorBg
$form.Controls.Add($headerPanel) | Out-Null

$faceBox = New-Object System.Windows.Forms.PictureBox
$faceBox.Location = New-Object System.Drawing.Point(0, 6)
$faceBox.Size = New-Object System.Drawing.Size(32, 32)
$faceBox.BackColor = $ColorBg
$faceBox.SizeMode = "Zoom"
if (Test-Path $facePath) {
    $faceBox.Image = [System.Drawing.Image]::FromFile($facePath)
}
$headerPanel.Controls.Add($faceBox) | Out-Null

$lblBrand = New-Object System.Windows.Forms.Label
$lblBrand.Text = "Stealth"
$lblBrand.Font = $titleFont
$lblBrand.ForeColor = $ColorText
$lblBrand.BackColor = $ColorBg
$lblBrand.AutoSize = $false
$lblBrand.Size = New-Object System.Drawing.Size(180, 36)
$lblBrand.Location = New-Object System.Drawing.Point(40, 4)
$lblBrand.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$headerPanel.Controls.Add($lblBrand) | Out-Null

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text = "Отдельный профиль — не трогает другие профили Firefox"
$lblSub.Font = $uiFont
$lblSub.ForeColor = $ColorMuted
$lblSub.BackColor = $ColorBg
$lblSub.AutoSize = $false
$lblSub.Size = New-Object System.Drawing.Size(452, 24)
$lblSub.Location = New-Object System.Drawing.Point(26, 68)
$form.Controls.Add($lblSub) | Out-Null

$pnlVersion = New-Object System.Windows.Forms.Panel
$pnlVersion.BackColor = $ColorBg
$pnlVersion.Size = New-Object System.Drawing.Size(452, 22)
$pnlVersion.Location = New-Object System.Drawing.Point(26, 94)
$form.Controls.Add($pnlVersion) | Out-Null

$chkProfileOnly = New-Object System.Windows.Forms.CheckBox
$chkProfileOnly.Text = "Только обновить профиль (без установки движка)"
$chkProfileOnly.Font = $uiFont
$chkProfileOnly.ForeColor = $ColorText
$chkProfileOnly.BackColor = $ColorBg
$chkProfileOnly.FlatStyle = "Flat"
$chkProfileOnly.AutoSize = $false
$chkProfileOnly.Size = New-Object System.Drawing.Size(452, 22)
$chkProfileOnly.Location = New-Object System.Drawing.Point(26, 120)
$chkProfileOnly.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(120, 120, 120)
$chkProfileOnly.FlatAppearance.CheckedBackColor = [System.Drawing.Color]::FromArgb(0, 217, 184)
$chkProfileOnly.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(26, 26, 26)
$form.Controls.Add($chkProfileOnly) | Out-Null

$btnInstall = New-FlatButton -Text "Установить" -X 24 -Y 150 -W 452 -H 40 -Parent $form -Font $btnFont

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Font = $uiFont
$lblStatus.ForeColor = $ColorMuted
$lblStatus.BackColor = $ColorBg
$lblStatus.AutoSize = $false
$lblStatus.Size = New-Object System.Drawing.Size(452, 22)
$lblStatus.Location = New-Object System.Drawing.Point(26, 200)
$form.Controls.Add($lblStatus) | Out-Null
Set-StealthWrappedLabel -Label $lblStatus -Text "Одна установка: Firefox → Stealth. Браузеры закроются автоматически." -MinHeight 22

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(24, 226)
$progressBar.Size = New-Object System.Drawing.Size(452, 14)
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$progressBar.Value = 0
$progressBar.Style = "Continuous"
$progressBar.Visible = $false
$progressBar.ForeColor = $ColorOk
$progressBar.BackColor = $ColorSurface
$form.Controls.Add($progressBar) | Out-Null

$logPanel = New-Object System.Windows.Forms.Panel
$logPanel.Location = New-Object System.Drawing.Point(24, 250)
$logPanel.Size = New-Object System.Drawing.Size(452, 180)
$logPanel.BackColor = $ColorLine
$logPanel.Padding = New-Object System.Windows.Forms.Padding(1)
$logPanel.Visible = $false
$form.Controls.Add($logPanel) | Out-Null

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ReadOnly = $true
$logBox.ScrollBars = "None"
$logBox.BorderStyle = "None"
$logBox.BackColor = $ColorSurface
$logBox.ForeColor = $ColorText
$logBox.Font = $logFont
$logBox.Dock = "Fill"
$logPanel.Controls.Add($logBox) | Out-Null

$btnClose = New-FlatButton -Text "Закрыть" -X 376 -Y 440 -W 100 -H 32 -Parent $form -Font $btnFont
Set-FlatButtonTheme -Button $btnClose
Set-FlatButtonTheme -Button $btnInstall -Primary

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 150
$timer.Add_Tick({
    $line = $null
    while ($logQueue.TryDequeue([ref]$line)) {
        $logBox.AppendText("$line`r`n")
        $logBox.SelectionStart = $logBox.Text.Length
        $logBox.ScrollToCaret()
    }
    $status = $null
    while ($statusQueue.TryDequeue([ref]$status)) {
        Update-InstallStatusText -Text $status
    }
    $prog = $null
    while ($progressQueue.TryDequeue([ref]$prog)) {
        if ($prog.Percent -lt 0) {
            $progressBar.Style = "Marquee"
            $progressBar.MarqueeAnimationSpeed = 30
        }
        else {
            if ($progressBar.Style -eq "Marquee") {
                $progressBar.Style = "Continuous"
                $progressBar.Value = 0
            }
            $progressBar.Value = [Math]::Min(100, [Math]::Max(0, $prog.Percent))
        }
        if ($prog.Message) {
            Update-InstallStatusText -Text $prog.Message
        }
    }

    $installResult = Complete-InstallRunspace
    if ($installResult.Done) {
        Complete-InstallUi -Faulted $installResult.Faulted
    }
})
$timer.Start()

$script:installPs = $null
$script:installHandle = $null
$script:installRunspace = $null
$script:installUiFinalized = $false
$script:installEnded = $false
$script:installFaulted = $false

function Complete-InstallRunspace {
    if (-not $script:installHandle -or -not $script:installPs) {
        return @{ Done = $false; Faulted = $false }
    }
    if (-not $script:installHandle.IsCompleted) {
        return @{ Done = $false; Faulted = $false }
    }
    if ($script:installEnded) {
        return @{ Done = $true; Faulted = $script:installFaulted }
    }

    $script:installEnded = $true
    $faulted = $false
    try {
        $null = $script:installPs.EndInvoke($script:installHandle)
    }
    catch {
        $faulted = $true
        [void]$logQueue.Enqueue("[x] $($_.Exception.Message)")
    }

    if ($script:installPs.HadErrors) {
        $faulted = $true
        foreach ($err in $script:installPs.Streams.Error) {
            if ($err.Exception.Message) {
                [void]$logQueue.Enqueue("[x] $($err.Exception.Message)")
            }
        }
    }

    $script:installFaulted = $faulted
    return @{ Done = $true; Faulted = $faulted }
}

function Complete-InstallUi {
    param([bool]$Faulted)

    if ($script:installUiFinalized) { return }
    $script:installUiFinalized = $true

    if ($Faulted) {
        Update-InstallStatusText -Text "Ошибка установки."
        $lblStatus.ForeColor = $ColorError
        [void]$logQueue.Enqueue("")
        [void]$logQueue.Enqueue("[x] Установка не удалась.")
        $progressBar.Style = "Continuous"
        $progressBar.Value = 0
    }
    else {
        if ($chkProfileOnly.Checked) {
            Update-InstallStatusText -Text "Готово. Профиль Stealth обновлён."
        }
        else {
            Update-InstallStatusText -Text "Готово. Stealth запущен."
        }
        $lblStatus.ForeColor = $ColorOk
        [void]$logQueue.Enqueue("")
        [void]$logQueue.Enqueue("[ok] Готово!")
        if (-not $chkProfileOnly.Checked) {
            [void]$logQueue.Enqueue("Ярлык: Stealth (рабочий стол / Пуск / панель задач)")
            [void]$logQueue.Enqueue("Ярлык Mozilla Firefox не создаётся")
        }
        $progressBar.Style = "Continuous"
        $progressBar.Value = 100
    }

    Update-InstallUiState
    Set-FlatButtonTheme -Button $btnClose

    if ($script:installPs) {
        $script:installPs.Dispose()
        $script:installPs = $null
    }
    if ($script:installRunspace) {
        $script:installRunspace.Close()
        $script:installRunspace.Dispose()
        $script:installRunspace = $null
    }
    $script:installHandle = $null
}

function Update-InstallUiState {
    $status = Get-StealthSetupStatus
    $cfg = Get-SetupVersion

    if (-not $status.StealthInstalled) {
        Set-StealthVersionLabel -Text (@(
            "Stealth не установлен"
            "Установщик v$($cfg.SetupVersion) скачает движок и настроит профиль"
        ) -join "`r`n") -BaseColor $ColorWarn -MinHeight 22
        $btnInstall.Text = "Установить Stealth"
        $btnInstall.Enabled = $true
        Set-FlatButtonTheme -Button $btnInstall -Primary
    }
    elseif (-not $status.ProfileExists) {
        Set-StealthVersionLabel -Text "Профиль Stealth: не найден · установщик v$($cfg.SetupVersion)" -BaseColor $ColorMuted -MinHeight 22
        $btnInstall.Text = "Установить"
        $btnInstall.Enabled = $true
        Set-FlatButtonTheme -Button $btnInstall -Primary
    }
    elseif ($status.IsCurrent) {
        Set-StealthVersionLabel -Text (@(
            "Профиль Stealth: v$($status.InstalledVersion)"
            "Установлена последняя версия"
        ) -join "`r`n") -BaseColor $ColorOk -AccentWords @("последняя") -AccentColor $ColorOk -MinHeight 36
        $btnInstall.Text = "Переустановить профиль"
        $btnInstall.Enabled = $true
        Set-FlatButtonTheme -Button $btnInstall
    }
    elseif ($status.InstalledVersion) {
        Set-StealthVersionLabel -Text "Профиль Stealth: v$($status.InstalledVersion) → v$($cfg.SetupVersion)" -BaseColor $ColorWarn -AccentWords @() -MinHeight 22
        $btnInstall.Text = "Обновить до v$($cfg.SetupVersion)"
        $btnInstall.Enabled = $true
        Set-FlatButtonTheme -Button $btnInstall -Primary
    }
    else {
        Set-StealthVersionLabel -Text "Профиль Stealth без маркера версии · установщик v$($status.AvailableVersion)" -BaseColor $ColorWarn -AccentWords @() -MinHeight 22
        $btnInstall.Text = "Применить профиль"
        $btnInstall.Enabled = $true
        Set-FlatButtonTheme -Button $btnInstall -Primary
    }

    $chkProfileOnly.Enabled = $status.EngineInstalled
    if (-not $status.EngineInstalled) {
        $chkProfileOnly.Checked = $false
    }
    elseif ($status.NeedsUpdate -and $status.ProfileExists) {
        $chkProfileOnly.Checked = $true
    }
    elseif ($status.IsCurrent) {
        $chkProfileOnly.Checked = $false
    }

    if ($chkProfileOnly.Enabled) {
        $chkProfileOnly.ForeColor = $ColorText
    }
    else {
        $chkProfileOnly.ForeColor = $ColorMuted
    }

    Sync-InstallFormLayout
}

$chkProfileOnly.Add_CheckedChanged({
    if (-not $chkProfileOnly.Enabled) { return }

    $status = Get-StealthSetupStatus
    $cfg = Get-SetupVersion

    if ($chkProfileOnly.Checked) {
        if ($status.NeedsUpdate) {
            $btnInstall.Text = "Обновить до v$($cfg.SetupVersion)"
            Set-FlatButtonTheme -Button $btnInstall -Primary
        }
        else {
            $btnInstall.Text = "Обновить профиль"
            Set-FlatButtonTheme -Button $btnInstall
        }
        return
    }

    Update-InstallUiState
})

Update-InstallUiState

$btnInstall.Add_Click({
    if ($script:installHandle -and -not $script:installHandle.IsCompleted) { return }

    $btnInstall.Enabled = $false
    $chkProfileOnly.Enabled = $false
    $logBox.Clear()
    Update-InstallStatusText -Text "Запуск установки..."
    $lblStatus.ForeColor = $ColorText
    $progressBar.Visible = $true
    $progressBar.Style = "Marquee"
    $progressBar.MarqueeAnimationSpeed = 30
    $logPanel.Visible = $true
    Sync-InstallFormLayout

    $drain = $null
    while ($logQueue.TryDequeue([ref]$drain)) {}
    while ($statusQueue.TryDequeue([ref]$drain)) {}
    while ($progressQueue.TryDequeue([ref]$drain)) {}

    [void]$logQueue.Enqueue("StealthBrowser setup")
    [void]$logQueue.Enqueue("")

    $useProfileOnly = $chkProfileOnly.Checked
    $script:installUiFinalized = $false
    $script:installEnded = $false
    $script:installFaulted = $false

    if ($script:installPs) {
        $script:installPs.Dispose()
        $script:installPs = $null
    }
    if ($script:installRunspace) {
        $script:installRunspace.Close()
        $script:installRunspace.Dispose()
        $script:installRunspace = $null
    }

    $script:installRunspace = [runspacefactory]::CreateRunspace()
    $script:installRunspace.Open()
    $script:installPs = [powershell]::Create()
    $script:installPs.Runspace = $script:installRunspace

    $installScriptBlock = @'
param(
    [string]$Root,
    [object]$LogQueue,
    [object]$StatusQueue,
    [object]$ProgressQueue,
    [bool]$ProfileOnly
)
Set-Location $Root
. (Join-Path $Root "Install-Stealth.ps1")
$script:SetupLogQueue = $LogQueue
$script:SetupStatusQueue = $StatusQueue
$script:SetupProgressQueue = $ProgressQueue
try {
    Invoke-StealthSetup -LaunchWhenDone -ProfileOnly:$ProfileOnly
    if (-not $ProfileOnly) {
        $status = Get-StealthSetupStatus
        if (-not $status.ProfileExists) {
            throw "Профиль Stealth не создан. Повторите установку."
        }
    }
}
catch {
    [void]$LogQueue.Enqueue("[x] $($_.Exception.Message)")
    throw
}
'@

    $null = $script:installPs.AddScript($installScriptBlock)
    $null = $script:installPs.AddArgument($scriptRoot)
    $null = $script:installPs.AddArgument($logQueue)
    $null = $script:installPs.AddArgument($statusQueue)
    $null = $script:installPs.AddArgument($progressQueue)
    $null = $script:installPs.AddArgument([bool]$useProfileOnly)

    $script:installHandle = $script:installPs.BeginInvoke()
})

$form.Add_FormClosing({
    param($sender, $eventArgs)
    if (-not $script:allowFormClose) {
        $eventArgs.Cancel = $true
    }
})

$btnClose.Add_Click({
    $script:allowFormClose = $true
    $form.Close()
})

[void]$form.ShowDialog()

$timer.Stop()
if ($script:installHandle -and -not $script:installHandle.IsCompleted) {
    $deadline = [datetime]::UtcNow.AddSeconds(30)
    while (-not $script:installHandle.IsCompleted -and [datetime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 100
    }
}
if (-not $script:installUiFinalized) {
    $installResult = Complete-InstallRunspace
    if ($installResult.Done) {
        Complete-InstallUi -Faulted $installResult.Faulted
    }
}
