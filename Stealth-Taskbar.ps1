#Requires -Version 5.1

if (-not ("StealthTaskbar.PInvoke" -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace StealthTaskbar {
    [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IPropertyStore {
        int GetCount(out uint cProps);
        int GetAt(uint iProp, out PropertyKey pkey);
        int GetValue(ref PropertyKey key, out PropVariant pv);
        int SetValue(ref PropertyKey key, ref PropVariant pv);
        int Commit();
    }

    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    public struct PropertyKey {
        public Guid fmtid;
        public uint pid;
        public PropertyKey(Guid fmtid, uint pid) { this.fmtid = fmtid; this.pid = pid; }
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PropVariant {
        public ushort vt;
        public ushort w1, w2, w3;
        public IntPtr ptr;
        public int i1, i2, i3, i4;
        public static PropVariant FromString(string value) {
            var pv = new PropVariant();
            pv.vt = 31;
            pv.ptr = Marshal.StringToCoTaskMemUni(value);
            return pv;
        }
    }

    [ComImport, Guid("0000010c-0000-0000-C000-000000000046")]
    public interface IPersist {
        int GetClassID(out Guid pClassID);
    }

    [ComImport, Guid("0000010b-0000-0000-C000-000000000046")]
    public interface IPersistFile : IPersist {
        new int GetClassID(out Guid pClassID);
        int IsDirty();
        int Load([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, uint dwMode);
        int Save([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, bool fRemember);
        int SaveCompleted([MarshalAs(UnmanagedType.LPWStr)] string pszFileName);
        int GetCurFile([MarshalAs(UnmanagedType.LPWStr)] out string ppszFileName);
    }

    [ComImport, Guid("00021401-0000-0000-C000-000000000046")]
    public interface IShellLinkW {
        void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszFile, int cchMaxPath, IntPtr pfd, uint fFlags);
        void GetIDList(out IntPtr ppidl);
        void SetIDList(IntPtr pidl);
        void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszName, int cchMaxName);
        void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);
        void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszDir, int cchMaxPath);
        void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDir);
        void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszArgs, int cchMaxPath);
        void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);
        void GetHotkey(out short pwHotkey);
        void SetHotkey(short wHotkey);
        void GetShowCmd(out int piShowCmd);
        void SetShowCmd(int iShowCmd);
        void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszIconPath, int cchIconPath, out int piIcon);
        void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string pszIconPath, int iIcon);
        void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string pszPath, uint dwReserved);
        void Resolve(IntPtr hwnd, uint fFlags);
        void SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);
    }

    public static class ShellLinkHelper {
        public static readonly PropertyKey PKEY_AppUserModel_ID =
            new PropertyKey(new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), 5);
        public static readonly PropertyKey PKEY_AppUserModel_RelaunchCommand =
            new PropertyKey(new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), 2);
        public static readonly PropertyKey PKEY_AppUserModel_RelaunchDisplayNameResource =
            new PropertyKey(new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), 3);
        public static readonly PropertyKey PKEY_AppUserModel_RelaunchIconResource =
            new PropertyKey(new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), 4);

        public static void SetShortcutProperties(string lnkPath, string appId, string relaunchCmd, string relaunchName, string relaunchIcon) {
            var shellLink = (IShellLinkW)Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("00021401-0000-0000-C000-000000000046")));
            var persistFile = (IPersistFile)shellLink;
            persistFile.Load(lnkPath, 0);
            var propertyStore = (IPropertyStore)shellLink;

            var id = PropVariant.FromString(appId);
            var keyId = PKEY_AppUserModel_ID;
            propertyStore.SetValue(ref keyId, ref id);

            var cmd = PropVariant.FromString(relaunchCmd);
            var keyCmd = PKEY_AppUserModel_RelaunchCommand;
            propertyStore.SetValue(ref keyCmd, ref cmd);

            var name = PropVariant.FromString(relaunchName);
            var keyName = PKEY_AppUserModel_RelaunchDisplayNameResource;
            propertyStore.SetValue(ref keyName, ref name);

            if (!string.IsNullOrEmpty(relaunchIcon)) {
                var icon = PropVariant.FromString(relaunchIcon);
                var keyIcon = PKEY_AppUserModel_RelaunchIconResource;
                propertyStore.SetValue(ref keyIcon, ref icon);
            }

            propertyStore.Commit();
            persistFile.Save(lnkPath, true);
        }
    }
}
"@
}

function Get-FirefoxTaskbarModelIds {
    param(
        [string]$StealthExe,
        [string]$ProfilePath
    )

    $ids = New-Object System.Collections.Generic.List[string]
    $paths = @(
        "HKLM:\Software\Mozilla\Firefox\TaskBarIDs",
        "HKCU:\Software\Mozilla\Firefox\TaskBarIDs"
    )

    foreach ($regPath in $paths) {
        if (-not (Test-Path $regPath)) { continue }
        $props = Get-ItemProperty -Path $regPath
        foreach ($name in $props.PSObject.Properties.Name) {
            if ($name -in @("PSPath", "PSParentPath", "PSChildName", "PSDrive", "PSProvider")) { continue }
            $val = [string]$props.$name
            if ($val) { [void]$ids.Add($val) }
            if ($ProfilePath -and ($name -eq $ProfilePath -or $name -like "*$([IO.Path]::GetFileName($ProfilePath))*")) {
                [void]$ids.Add($val)
            }
        }
    }

    [void]$ids.Add("StealthBrowser.Stealth")
    return @($ids | Select-Object -Unique)
}

function Get-MozillaHashString {
    param([byte[]]$Bytes)

    [uint32]$hash = 0
    foreach ($b in $Bytes) {
        $hash = [uint32](([uint64]$hash * 37 + $b) % [uint64]4294967296)
    }
    return [string]$hash
}

function Get-StealthTaskbarModelIds {
    param(
        [string]$StealthExe,
        [string]$ProfilePath
    )

    $ids = New-Object System.Collections.Generic.List[string]
    foreach ($modelId in (Get-FirefoxTaskbarModelIds -StealthExe $StealthExe -ProfilePath $ProfilePath)) {
        [void]$ids.Add($modelId)
        [void]$ids.Add("Firefox-$modelId")
    }

    [void]$ids.Add("StealthBrowser.Stealth")
    [void]$ids.Add("7FDD1D39F7222CD")
    [void]$ids.Add("Firefox-7FDD1D39F7222CD")

    if ($ProfilePath) {
        $utf8 = [Text.UTF8Encoding]::new($false)
        [void]$ids.Add((Get-MozillaHashString -Bytes $utf8.GetBytes($ProfilePath)))
        $utf16 = [Text.UnicodeEncoding]::new($false, $false)
        [void]$ids.Add((Get-MozillaHashString -Bytes $utf16.GetBytes($ProfilePath)))
    }

    return @($ids | Where-Object { $_ } | Select-Object -Unique)
}

function Register-StealthEngineTaskBarMapping {
    param([string]$StealthExe)

    $engineDir = Split-Path $StealthExe -Parent
    foreach ($vendor in @("Firefox", "Stealth", "StealthBrowser")) {
        $regPath = "HKCU:\Software\Mozilla\$vendor\TaskBarIDs"
        New-Item -Path $regPath -Force | Out-Null
        Set-ItemProperty -Path $regPath -Name $engineDir -Value "StealthBrowser.Stealth" -Type String
    }
}

function Register-StealthProtocolHandler {
    param(
        [string]$ProgId,
        [string]$DisplayName,
        [string]$OpenCommand,
        [string]$IconPath
    )

    $root = "HKCU:\Software\Classes\$ProgId"
    New-Item -Path $root -Force | Out-Null
    Set-ItemProperty -Path $root -Name "(default)" -Value $DisplayName -Type String
    Set-ItemProperty -Path $root -Name "FriendlyTypeName" -Value $DisplayName -Type String
    if ($ProgId -like "*URL") {
        Set-ItemProperty -Path $root -Name "URL Protocol" -Value "" -Type String
    }
    if ($IconPath) {
        Set-ItemProperty -Path $root -Name "DefaultIcon" -Value "$IconPath,0" -Type String
    }

    $shellOpen = Join-Path $root "shell\open\command"
    New-Item -Path (Split-Path $shellOpen -Parent) -Force | Out-Null
    New-Item -Path $shellOpen -Force | Out-Null
    Set-ItemProperty -Path $shellOpen -Name "(default)" -Value $OpenCommand -Type String
}

function Set-StealthStartMenuInternetShellOpen {
    param(
        [string]$ClientRoot,
        [string]$LaunchCommand
    )

    $shellOpen = Join-Path $ClientRoot "shell\open\command"
    New-Item -Path (Split-Path $shellOpen -Parent) -Force | Out-Null
    New-Item -Path $shellOpen -Force | Out-Null
    Set-ItemProperty -Path $shellOpen -Name "(default)" -Value $LaunchCommand -Type String
}

function Register-StealthStartMenuInternetEntry {
    param(
        [string]$ClientId,
        [string]$DisplayName,
        [string]$LaunchCommand,
        [string]$IconResource,
        [string]$UrlProgId,
        [string]$HtmlProgId,
        [string]$RegisteredApplications
    )

    $clientRoot = "HKCU:\Software\Clients\StartMenuInternet\$ClientId"
    New-Item -Path $clientRoot -Force | Out-Null
    Set-ItemProperty -Path $clientRoot -Name "(default)" -Value $DisplayName -Type String
    Set-ItemProperty -Path $clientRoot -Name "shell" -Value "open" -Type String
    Set-ItemProperty -Path $clientRoot -Name "DefaultIcon" -Value $IconResource -Type String
    Set-StealthStartMenuInternetShellOpen -ClientRoot $clientRoot -LaunchCommand $LaunchCommand

    $capabilities = Join-Path $clientRoot "Capabilities"
    New-Item -Path $capabilities -Force | Out-Null
    Set-ItemProperty -Path $capabilities -Name "ApplicationName" -Value $DisplayName -Type String
    Set-ItemProperty -Path $capabilities -Name "ApplicationDescription" -Value $DisplayName -Type String
    Set-ItemProperty -Path $capabilities -Name "ApplicationIcon" -Value $IconResource -Type String

    $urlAssoc = Join-Path $capabilities "URLAssociations"
    New-Item -Path $urlAssoc -Force | Out-Null
    Set-ItemProperty -Path $urlAssoc -Name "http" -Value $UrlProgId -Type String
    Set-ItemProperty -Path $urlAssoc -Name "https" -Value $UrlProgId -Type String

    $fileAssoc = Join-Path $capabilities "FileAssociations"
    New-Item -Path $fileAssoc -Force | Out-Null
    foreach ($ext in @(".htm", ".html", ".xhtml", ".xht", ".shtml")) {
        Set-ItemProperty -Path $fileAssoc -Name $ext -Value $HtmlProgId -Type String
    }

    Set-ItemProperty -Path $RegisteredApplications -Name $ClientId -Value "Software\Clients\StartMenuInternet\$ClientId\Capabilities" -Type String
}

function Register-StealthStartMenuInternetClient {
    param(
        [string]$StealthExe,
        [string]$ProfilePath,
        [string]$IconPath
    )

    $displayName = "Stealth"
    $iconResource = if ($IconPath) { "$IconPath,0" } else { "$StealthExe,0" }
    $registered = "HKCU:\Software\RegisteredApplications"
    New-Item -Path $registered -Force | Out-Null

    $launcherExe = if (Get-Command Get-StealthLauncherExe -ErrorAction SilentlyContinue) {
        Get-StealthLauncherExe
    }
    else {
        Join-Path $env:LOCALAPPDATA "StealthBrowser\Stealth.exe"
    }
    if ($launcherExe -and (Test-Path $launcherExe)) {
        $launchCommand = "`"$launcherExe`""
    }
    else {
        $launchCommand = "`"$StealthExe`" -profile `"$ProfilePath`""
    }

    # URL/file handlers should target firefox.exe directly: this is the most
    # reliable path for Windows external link activation.
    $urlCommand = "`"$StealthExe`" -profile `"$ProfilePath`" `"%1`""
    $htmlCommand = $urlCommand

    Register-StealthProtocolHandler -ProgId "StealthBrowserURL" -DisplayName "Stealth URL" -OpenCommand $urlCommand -IconPath $IconPath
    Register-StealthProtocolHandler -ProgId "StealthBrowserHTML" -DisplayName "Stealth HTML Document" -OpenCommand $htmlCommand -IconPath $IconPath

    $installHashScript = Join-Path $PSScriptRoot "scripts\Get-StealthInstallHash.ps1"
    $installHash = $null
    if (Test-Path $installHashScript) {
        . $installHashScript
        $installHash = Get-StealthFirefoxInstallHash -StealthExe $StealthExe
    }

    if ($installHash) {
        $firefoxUrlProgId = "FirefoxURL-$installHash"
        $firefoxHtmlProgId = "FirefoxHTML-$installHash"
        $firefoxPdfProgId = "FirefoxPDF-$installHash"
        Register-StealthProtocolHandler -ProgId $firefoxUrlProgId -DisplayName "Firefox URL" -OpenCommand $urlCommand -IconPath $IconPath
        Register-StealthProtocolHandler -ProgId $firefoxHtmlProgId -DisplayName "Firefox HTML Document" -OpenCommand $htmlCommand -IconPath $IconPath
        Register-StealthProtocolHandler -ProgId $firefoxPdfProgId -DisplayName "Firefox PDF Document" -OpenCommand $urlCommand -IconPath $IconPath

        Register-StealthStartMenuInternetEntry `
            -ClientId "Firefox-$installHash" `
            -DisplayName $displayName `
            -LaunchCommand $launchCommand `
            -IconResource $iconResource `
            -UrlProgId $firefoxUrlProgId `
            -HtmlProgId $firefoxHtmlProgId `
            -RegisteredApplications $registered
    }

    Register-StealthStartMenuInternetEntry `
        -ClientId "StealthBrowser" `
        -DisplayName $displayName `
        -LaunchCommand $launchCommand `
        -IconResource $iconResource `
        -UrlProgId "StealthBrowserURL" `
        -HtmlProgId "StealthBrowserHTML" `
        -RegisteredApplications $registered
}

function Set-StealthAppUserModelDisplayName {
    param(
        [string]$ModelId,
        [string]$DisplayName = "Stealth",
        [string]$IconPath = $null
    )

    if (-not $ModelId) { return }
    $path = "HKCU:\Software\Classes\AppUserModelId\$ModelId"
    New-Item -Path $path -Force | Out-Null
    Set-ItemProperty -Path $path -Name "(default)" -Value $DisplayName -Type String
    Set-ItemProperty -Path $path -Name "FriendlyAppName" -Value $DisplayName -Type String
    if ($IconPath) {
        Set-ItemProperty -Path $path -Name "IconResource" -Value "$IconPath,0" -Type String
    }
}

function Clear-StealthJumpListForModelId {
    param([string]$ModelId)

    if (-not $ModelId) { return }
    if (-not ("StealthJumpList.Clearer" -as [type])) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace StealthJumpList {
    [ComImport, Guid("6332debf-8b83-4c83-859a-084981dd9ca3"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface ICustomDestinationList {
        int SetAppID([MarshalAs(UnmanagedType.LPWStr)] string pszAppID);
        int BeginList(out uint pcMaxSlots, ref Guid pguidKey);
        int AppendCategory([MarshalAs(UnmanagedType.LPWStr)] string pszCategory);
        int AppendKnownCategory(int category);
        int AddUserTasks(IntPtr poa);
        int AppendSeparator();
        int AppendShortcut([MarshalAs(UnmanagedType.LPWStr)] string pszLink);
        int AppendShortcut([MarshalAs(UnmanagedType.LPWStr)] string pszLink, [MarshalAs(UnmanagedType.LPWStr)] string pszArguments);
        int DeleteList([MarshalAs(UnmanagedType.LPWStr)] string pszAppID);
        int AbortList();
        int CommitList();
    }

    public static class Clearer {
        public static void Clear(string appId) {
            var cdl = (ICustomDestinationList)Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("6332debf-8b83-4c83-859a-084981dd9ca3")));
            cdl.DeleteList(appId);
            cdl.SetAppID(appId);
            cdl.CommitList();
        }
    }
}
"@
    }

    try {
        [StealthJumpList.Clearer]::Clear($ModelId)
    }
    catch {
    }
}

function Set-StealthShortcutShellProperties {
    param(
        [string]$LnkPath,
        [string]$LauncherCmd,
        [string]$IconPath
    )

    if (-not (Test-Path $LnkPath)) { return }

    $appId = "StealthBrowser.Stealth"
    $relaunchCmd = "`"$LauncherCmd`""
    $relaunchName = "Stealth"
    $relaunchIcon = if ($IconPath) { "$IconPath,0" } else { $null }

    try {
        [StealthTaskbar.ShellLinkHelper]::SetShortcutProperties($LnkPath, $appId, $relaunchCmd, $relaunchName, $relaunchIcon)
    }
    catch {
        Write-Verbose $_.Exception.Message
    }
}

function Install-StealthDistributionPolicies {
    param([string]$StealthExe)

    Write-StealthDistributionPolicies -EngineRoot (Split-Path $StealthExe -Parent)
}

function Pin-StealthShortcutToTaskbar {
    param(
        [string]$LnkPath,
        [string]$LauncherCmd,
        [string]$IconPath
    )

    if (-not (Test-Path $LnkPath)) {
        if (Get-Command Write-SetupLog -ErrorAction SilentlyContinue) {
            Write-SetupLog "Taskbar pin skipped: shortcut not found" "Warn"
        }
        return
    }

    $pinDir = Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar'
    New-Item -ItemType Directory -Force -Path $pinDir | Out-Null
    $pinPath = Join-Path $pinDir 'Stealth.lnk'
    Copy-Item $LnkPath $pinPath -Force
    Set-StealthShortcutShellProperties -LnkPath $pinPath -LauncherCmd $LauncherCmd -IconPath $IconPath

    $vbsPath = Join-Path $env:TEMP ("stealth-pin-taskbar-{0}.vbs" -f ([guid]::NewGuid().ToString('n')))
    $escapedPin = $pinPath.Replace('\', '\\')
    @"
On Error Resume Next
Set shell = CreateObject("Shell.Application")
Set fso = CreateObject("Scripting.FileSystemObject")
lnkPath = "$escapedPin"
Set folder = shell.Namespace(fso.GetParentFolderName(lnkPath))
If folder Is Nothing Then WScript.Quit 1
Set item = folder.ParseName(fso.GetFileName(lnkPath))
If item Is Nothing Then WScript.Quit 1
For Each verb In item.Verbs
    vName = Replace(verb.Name, "&", "")
    If InStr(LCase(vName), "taskbar") > 0 Or InStr(vName, ChrW(1087) & ChrW(1072) & ChrW(1085) & ChrW(1077) & ChrW(1083)) > 0 Then
        verb.DoIt
        Exit For
    End If
Next
"@ | Set-Content -Path $vbsPath -Encoding ASCII
    Start-Process wscript.exe -ArgumentList "`"$vbsPath`"" -Wait -WindowStyle Hidden | Out-Null
    Remove-Item $vbsPath -Force -ErrorAction SilentlyContinue

    if (Test-Path "$env:SystemRoot\System32\ie4uinit.exe") {
        Start-Process ie4uinit.exe -ArgumentList '-show' -WindowStyle Hidden | Out-Null
    }

    if (Get-Command Write-SetupLog -ErrorAction SilentlyContinue) {
        Write-SetupLog "Pinned Stealth to taskbar" "Detail"
    }
}

function Invoke-StealthSetDefaultBrowser {
    param(
        [string]$StealthExe,
        [string]$ProfilePath
    )

    if (-not (Test-Path -LiteralPath $StealthExe)) {
        return $false
    }

    try {
        Start-Process -FilePath $StealthExe -ArgumentList @(
            "-no-remote",
            "-profile", $ProfilePath,
            "-setDefaultBrowser"
        ) -WindowStyle Hidden -ErrorAction Stop | Out-Null
        if (Get-Command Write-SetupLog -ErrorAction SilentlyContinue) {
            Write-SetupLog "Stealth default-browser prompt started (confirm in Windows if shown)" "Ok"
        }
        return $true
    }
    catch {
        if (Get-Command Write-SetupLog -ErrorAction SilentlyContinue) {
            Write-SetupLog "Default browser registration: $($_.Exception.Message)" "Warn"
        }
        return $false
    }
}

function Register-StealthTaskbarIdentity {
    param(
        [string]$StealthExe,
        [string]$LauncherPath,
        [string]$IconPath,
        [string]$ProfilePath,
        [switch]$SetAsDefaultBrowser
    )

    Install-StealthDistributionPolicies -StealthExe $StealthExe
    Register-StealthEngineTaskBarMapping -StealthExe $StealthExe

    $iconExe = if ($IconPath -match '^([^,]+)') { $Matches[1] } else { $IconPath }
    Register-StealthStartMenuInternetClient -StealthExe $StealthExe -ProfilePath $ProfilePath -IconPath $iconExe
    if ($SetAsDefaultBrowser) {
        Invoke-StealthSetDefaultBrowser -StealthExe $StealthExe -ProfilePath $ProfilePath | Out-Null
    }
    foreach ($modelId in (Get-StealthTaskbarModelIds -StealthExe $StealthExe -ProfilePath $ProfilePath)) {
        Set-StealthAppUserModelDisplayName -ModelId $modelId -DisplayName "Stealth" -IconPath $iconExe
        Clear-StealthJumpListForModelId -ModelId $modelId
    }

    foreach ($lnk in @(
            (Join-Path $env:USERPROFILE "Desktop\Stealth.lnk"),
            (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Stealth.lnk")
        )) {
        Set-StealthShortcutShellProperties -LnkPath $lnk -LauncherCmd $LauncherPath -IconPath $IconPath
    }

    $engineExe = $StealthExe
    $pinnedDir = Join-Path $env:APPDATA "Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
    if (Test-Path $pinnedDir) {
        $shell = New-Object -ComObject WScript.Shell
        Get-ChildItem $pinnedDir -Filter "*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
            $shortcut = $shell.CreateShortcut($_.FullName)
            $target = $shortcut.TargetPath
            $isStealth = $target -like "*Stealth.exe*" -or $target -like "*Stealth.cmd*"
            $isEngine = $target -like "*StealthBrowser\Engine\firefox.exe"
            if ($isStealth -or $isEngine) {
                $launcher = if ($isEngine) { "`"$target`" $($shortcut.Arguments)" } else { $LauncherPath }
                Set-StealthShortcutShellProperties -LnkPath $_.FullName -LauncherCmd $launcher -IconPath $IconPath
            }
        }
    }
}
