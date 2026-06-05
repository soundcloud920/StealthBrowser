#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Diagnostics;

public static class AumidProbe {
    [DllImport("shell32.dll")]
    public static extern int GetCurrentProcessExplicitAppUserModelID(out IntPtr id);

    [DllImport("ole32.dll")]
    public static extern int CoTaskMemFree(IntPtr pv);

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
            return "(no AUMID property)";
        string val = Marshal.PtrToStringUni(pv.ptr);
        CoTaskMemFree(pv.ptr);
        return val ?? "(null)";
    }

    public static System.Collections.Generic.List<string> CollectFirefoxWindowInfo() {
        var lines = new System.Collections.Generic.List<string>();
        EnumWindows((hwnd, lparam) => {
            uint procId;
            GetWindowThreadProcessId(hwnd, out procId);
            if (procId == 0) return true;
            try {
                var p = Process.GetProcessById((int)procId);
                if (!p.ProcessName.Equals("firefox", StringComparison.OrdinalIgnoreCase)) return true;
            } catch { return true; }
            if (!IsWindowVisible(hwnd)) return true;
            var cls = new StringBuilder(256);
            var title = new StringBuilder(512);
            GetClassName(hwnd, cls, 256);
            GetWindowText(hwnd, title, 512);
            if (!cls.ToString().Contains("Mozilla") && title.Length == 0) return true;
            string aumid = ReadWindowAumid(hwnd);
            lines.Add(string.Format("PID={0} HWND={1} class={2} title={3} windowAUMID={4}",
                procId, hwnd, cls, title, aumid));
            return true;
        }, IntPtr.Zero);
        return lines;
    }
}
"@

$engine = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\firefox.exe'
$profile = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles\kn9q3hkf.stealth'

$running = Get-Process -Name firefox -ErrorAction SilentlyContinue
if ($running) {
    Write-Host 'firefox already running, killing for clean probe...'
    $running | Stop-Process -Force
    Start-Sleep -Seconds 2
}

Write-Host "Launching: $engine"
$proc = Start-Process -FilePath $engine -ArgumentList @('-no-remote', '-profile', "`"$profile`"") -PassThru
Write-Host "Started PID $($proc.Id), waiting for window..."
Start-Sleep -Seconds 8

$fp = Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.Id)"
Write-Host "ExecutablePath: $($fp.ExecutablePath)"
Write-Host "CommandLine: $($fp.CommandLine)"

$lines = [AumidProbe]::CollectFirefoxWindowInfo()
if ($lines.Count -eq 0) {
    Write-Host 'No firefox windows with AUMID found yet, waiting more...'
    Start-Sleep -Seconds 5
    $lines = [AumidProbe]::CollectFirefoxWindowInfo()
}
Write-Host "`n=== FIREFOX WINDOW AUMIDs ==="
foreach ($line in $lines) { Write-Host $line }
if ($lines.Count -eq 0) { Write-Host '(none)' }

# Compute expected install hash via cityhash if possible - read from registry TaskBarIDs expected value
$engineDir = Split-Path $engine -Parent
$expected = (Get-ItemProperty 'HKCU:\Software\Mozilla\Firefox\TaskBarIDs' -ErrorAction SilentlyContinue).$engineDir
Write-Host "`nTaskBarIDs expected AUMID for engine: $expected"

# Leave browser running for user
Write-Host "`nBrowser left running (PID $($proc.Id))."
