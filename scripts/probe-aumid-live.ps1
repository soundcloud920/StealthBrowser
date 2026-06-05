#Requires -Version 5.1
# Probe running firefox windows without killing/relaunching.
$ErrorActionPreference = 'Stop'

if (-not ('LiveAumidProbe' -as [type])) {
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Diagnostics;

public static class LiveAumidProbe {
    [DllImport("shell32.dll", CharSet=CharSet.Unicode)]
    public static extern int SHGetPropertyStoreForWindow(IntPtr hwnd, ref Guid riid, out IntPtr ppv);

    [StructLayout(LayoutKind.Sequential, Pack=4)]
    public struct PropertyKey { public Guid fmtid; public uint pid; }

    [StructLayout(LayoutKind.Sequential)]
    public struct PropVariant {
        public ushort vt; public ushort w1,w2,w3; public IntPtr ptr;
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

    [DllImport("ole32.dll")]
    public static extern int CoTaskMemFree(IntPtr pv);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder text, int count);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    public static string ReadWindowAumid(IntPtr hwnd) {
        IntPtr store;
        Guid iid = IID_IPropertyStore;
        if (SHGetPropertyStoreForWindow(hwnd, ref iid, out store) != 0 || store == IntPtr.Zero)
            return "(no property store)";
        var ps = (IPropertyStore)Marshal.GetObjectForIUnknown(store);
        Marshal.Release(store);
        PropVariant pv;
        var key = PKEY_AppUserModel_ID;
        if (ps.GetValue(ref key, out pv) != 0 || pv.vt != 31)
            return "(no AUMID)";
        string val = Marshal.PtrToStringUni(pv.ptr);
        CoTaskMemFree(pv.ptr);
        return val ?? "(null)";
    }
}
"@
}

function Get-AumidDisplayName {
    param([string]$Aumid)
    if (-not $Aumid -or $Aumid -match '^\(') { return '(n/a)' }
    $paths = @(
        "HKCU:\Software\Classes\AppUserModelId\$Aumid",
        "HKLM:\Software\Classes\AppUserModelId\$Aumid"
    )
    foreach ($p in $paths) {
        if (-not (Test-Path $p)) { continue }
        $props = Get-ItemProperty $p
        $friendly = $props.FriendlyAppName
        $def = $props.'(default)'
        if ($friendly) { return "FriendlyAppName=$friendly (default=$def) [$p]" }
        if ($def) { return "default=$def [$p]" }
    }
    # StartMenuInternet fallback for Firefox-style IDs
    foreach ($client in @("Firefox-$Aumid", $Aumid)) {
        $smi = "HKLM:\Software\Clients\StartMenuInternet\$client"
        if (Test-Path $smi) {
            $cap = Join-Path $smi 'Capabilities'
            $name = (Get-ItemProperty $smi -ErrorAction SilentlyContinue).'(default)'
            $app = if (Test-Path $cap) { (Get-ItemProperty $cap -ErrorAction SilentlyContinue).ApplicationName } else { '' }
            return "StartMenuInternet HKLM: $name / $app"
        }
    }
    return '(no registry name)'
}

Write-Host '=== LIVE FIREFOX WINDOW PROBE (no kill) ==='
$found = 0
$cb = [LiveAumidProbe+EnumWindowsProc]{
    param($hwnd, $lParam)
    [uint32]$procId = 0
    [void][LiveAumidProbe]::GetWindowThreadProcessId($hwnd, [ref]$procId)
    if ($procId -eq 0) { return $true }
    try {
        $p = [Diagnostics.Process]::GetProcessById([int]$procId)
        if (-not $p.ProcessName.Equals('firefox', [StringComparison]::OrdinalIgnoreCase)) { return $true }
    } catch { return $true }
    if (-not [LiveAumidProbe]::IsWindowVisible($hwnd)) { return $true }
    $cls = New-Object Text.StringBuilder 256
    $title = New-Object Text.StringBuilder 512
    [void][LiveAumidProbe]::GetClassName($hwnd, $cls, 256)
    [void][LiveAumidProbe]::GetWindowText($hwnd, $title, 512)
    if ($title.Length -eq 0 -and $cls.ToString() -notmatch 'Mozilla') { return $true }
    $aumid = [LiveAumidProbe]::ReadWindowAumid($hwnd)
    $regName = Get-AumidDisplayName $aumid
    Write-Host "PID=$procId HWND=$hwnd class=$($cls) title=$($title)"
    Write-Host "  windowAUMID=$aumid"
    Write-Host "  registryName=$regName"
    Write-Host "  >>> taskbar preview header likely: $(if ($title.Length -gt 0) { $title } else { $regName })"
    $script:found++
    return $true
}
[void][LiveAumidProbe]::EnumWindows($cb, [IntPtr]::Zero)
if ($script:found -eq 0) { Write-Host 'No visible firefox windows.' }

$engineDir = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine'
$expected = (Get-ItemProperty 'HKCU:\Software\Mozilla\Firefox\TaskBarIDs' -ErrorAction SilentlyContinue).$engineDir
Write-Host "`nTaskBarIDs maps engine => $expected"
