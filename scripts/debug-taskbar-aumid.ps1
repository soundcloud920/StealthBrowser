#Requires -Version 5.1
$ErrorActionPreference = 'Continue'

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class AumidDebug {
    [DllImport("kernel32.dll")]
    public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(IntPtr h);

    [DllImport("shell32.dll")]
    public static extern int GetCurrentProcessExplicitAppUserModelID(out IntPtr id);

    [DllImport("ole32.dll")]
    public static extern int CoTaskMemFree(IntPtr pv);

    [DllImport("shell32.dll", CharSet=CharSet.Unicode)]
    public static extern int SHGetPropertyStoreForWindow(IntPtr hwnd, ref Guid riid, out IntPtr ppv);

    [StructLayout(LayoutKind.Sequential, Pack=4)]
    public struct PropertyKey {
        public Guid fmtid;
        public uint pid;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PropVariant {
        public ushort vt;
        public ushort w1,w2,w3;
        public IntPtr ptr;
        public int i1,i2,i3,i4;
    }

    [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IPropertyStore {
        int GetCount(out uint c);
        int GetAt(uint i, out PropertyKey key);
        int GetValue(ref PropertyKey key, out PropVariant pv);
        int SetValue(ref PropertyKey key, ref PropVariant pv);
        int Commit();
    }

    public static readonly Guid IID_IPropertyStore = new Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99");
    public static readonly PropertyKey PKEY_AppUserModel_ID = new PropertyKey {
        fmtid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), pid = 5
    };

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll", SetLastError=true)]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);

    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder text, int count);

    public static string GetProcessAumid() {
        IntPtr id;
        if (GetCurrentProcessExplicitAppUserModelID(out id) != 0 || id == IntPtr.Zero) return "(none)";
        string s = Marshal.PtrToStringUni(id);
        CoTaskMemFree(id);
        return s ?? "(null)";
    }

    public static string GetWindowAumid(IntPtr hwnd) {
        IntPtr store;
        Guid iid = IID_IPropertyStore;
        if (SHGetPropertyStoreForWindow(hwnd, ref iid, out store) != 0 || store == IntPtr.Zero) return "(no store)";
        var ps = (IPropertyStore)Marshal.GetObjectForIUnknown(store);
        Marshal.Release(store);
        PropVariant pv;
        var key = PKEY_AppUserModel_ID;
        if (ps.GetValue(ref key, out pv) != 0 || pv.vt != 31) return "(no prop)";
        string val = Marshal.PtrToStringUni(pv.ptr);
        CoTaskMemFree(pv.ptr);
        return val ?? "(null)";
    }
}
"@

$engine = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\firefox.exe'
$launcher = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Stealth.exe'
$profile = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles\kn9q3hkf.stealth'

Write-Host '========== PATHS =========='
Write-Host "Engine:   $engine"
Write-Host "Launcher: $launcher"
Write-Host "Profile:  $profile"

Write-Host "`n========== RUNNING PROCESSES =========="
$procs = Get-CimInstance Win32_Process -Filter "Name='firefox.exe'" -ErrorAction SilentlyContinue
if (-not $procs) {
    Write-Host 'No firefox.exe running.'
} else {
    $procs | ForEach-Object {
        Write-Host "--- PID $($_.ProcessId) ---"
        Write-Host "Path: $($_.ExecutablePath)"
        Write-Host "Cmd:  $($_.CommandLine)"
    }
}

Write-Host "`n========== WINDOW AUMIDs (Mozilla windows) =========="
$script:seen = 0
[AumidDebug+EnumWindowsProc]$cb = {
    param($hwnd, $lParam)
    $procId = [uint32]0
    [void][AumidDebug]::GetWindowThreadProcessId($hwnd, [ref]$procId)
    if ($procId -eq 0) { return $true }
    try {
        $p = Get-Process -Id $procId -ErrorAction Stop
        if ($p.ProcessName -ne 'firefox') { return $true }
    } catch { return $true }
    $title = New-Object System.Text.StringBuilder 512
    $class = New-Object System.Text.StringBuilder 256
    [void][AumidDebug]::GetWindowText($hwnd, $title, 512)
    [void][AumidDebug]::GetClassName($hwnd, $class, 256)
    if ($title.Length -eq 0 -and $class.ToString() -notmatch 'Mozilla') { return $true }
    $aumid = [AumidDebug]::GetWindowAumid($hwnd)
    Write-Host "HWND=$hwnd PID=$procId class=$($class) title=$($title)"
    Write-Host "  Window AUMID: $aumid"
    $script:seen++
    return $true
}
[void][AumidDebug]::EnumWindows($cb, [IntPtr]::Zero)
if ($script:seen -eq 0) { Write-Host 'No visible firefox windows found.' }

Write-Host "`n========== TASKBARIDS =========="
foreach ($vendor in @('Firefox','Stealth','StealthBrowser')) {
    $reg = "HKCU:\Software\Mozilla\$vendor\TaskBarIDs"
    if (-not (Test-Path $reg)) { Write-Host "$reg (missing)"; continue }
    $props = Get-ItemProperty $reg
    foreach ($n in $props.PSObject.Properties.Name) {
        if ($n -match '^PS') { continue }
        Write-Host "$vendor\$n => $($props.$n)"
    }
}

Write-Host "`n========== STARTMENUINTERNET (HKCU) =========="
foreach ($id in @('Firefox-308046B0AF4A39CB','StealthBrowser','Firefox-7FDD1D39F7222CD')) {
    $p = "HKCU:\Software\Clients\StartMenuInternet\$id"
    if (Test-Path $p) {
        $d = (Get-ItemProperty $p).'(default)'
        $cap = Join-Path $p 'Capabilities'
        $app = if (Test-Path $cap) { (Get-ItemProperty $cap).ApplicationName } else { '' }
        Write-Host "$id => default='$d' ApplicationName='$app'"
    }
}
Write-Host '--- HKLM ---'
foreach ($id in @('Firefox-308046B0AF4A39CB')) {
    $p = "HKLM:\Software\Clients\StartMenuInternet\$id"
    if (Test-Path $p) {
        $d = (Get-ItemProperty $p).'(default)'
        $cap = Join-Path $p 'Capabilities'
        $app = if (Test-Path $cap) { (Get-ItemProperty $cap).ApplicationName } else { '' }
        Write-Host "HKLM $id => default='$d' ApplicationName='$app'"
    }
}

Write-Host "`n========== AUMID DISPLAY NAMES =========="
Get-ChildItem 'HKCU:\Software\Classes\AppUserModelId' -ErrorAction SilentlyContinue |
    Where-Object { $_.PSChildName -match '308046|7FDD|Stealth' } |
    ForEach-Object {
        $props = Get-ItemProperty $_.PSPath
        Write-Host "$($_.PSChildName) => default='$($props.'(default)')' Friendly='$($props.FriendlyAppName)' Icon='$($props.IconResource)'"
    }

Write-Host "`n========== PINNED TASKBAR SHORTCUTS =========="
$pinned = Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar'
if (Test-Path $pinned) {
    $shell = New-Object -ComObject WScript.Shell
    Get-ChildItem $pinned -Filter '*.lnk' | ForEach-Object {
        $sc = $shell.CreateShortcut($_.FullName)
        if ($sc.TargetPath -match 'firefox|Stealth|Mozilla') {
            Write-Host "$($_.Name) => $($sc.TargetPath) $($sc.Arguments)"
        }
    }
} else { Write-Host 'No pinned dir' }

Write-Host "`n========== EXE VERSION INFO =========="
foreach ($path in @($engine, $launcher)) {
    if (-not (Test-Path $path)) { continue }
    $v = [Diagnostics.FileVersionInfo]::GetVersionInfo($path)
    Write-Host "$path"
    Write-Host "  Product=$($v.ProductName) FileDesc=$($v.FileDescription) Company=$($v.CompanyName)"
}

Write-Host "`n========== PROFILE PREFS =========="
$prefs = Join-Path $profile 'prefs.js'
if (Test-Path $prefs) {
    Select-String -Path $prefs -Pattern 'taskbar|useprofile' | ForEach-Object { $_.Line.Trim() }
}
