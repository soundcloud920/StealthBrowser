#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$engine = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\firefox.exe'
$profile = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles\kn9q3hkf.stealth'
$prefs = Join-Path $profile 'prefs.js'

Get-Process firefox -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

function Get-MainTitle {
    Add-Type @"
using System; using System.Diagnostics; using System.Runtime.InteropServices; using System.Text;
public static class T {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc e, IntPtr l);
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int c);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int c);
  public static string MainMozilla() {
    string found = null;
    EnumWindows((h,l) => {
      uint p; GetWindowThreadProcessId(h, out p);
      try { if (Process.GetProcessById((int)p).ProcessName != "firefox") return true; } catch { return true; }
      var cls = new StringBuilder(256); GetClassName(h, cls, 256);
      if (cls.ToString() != "MozillaWindowClass") return true;
      var sb = new StringBuilder(512); GetWindowText(h, sb, 512);
      if (sb.Length > 0) found = sb.ToString();
      return true;
    }, IntPtr.Zero);
    return found ?? '(none)';
  }
}
"@ -ErrorAction SilentlyContinue
    return [T]::MainMozilla()
}

foreach ($locale in @('en-GB', 'en-US')) {
    Write-Host "`n=== Testing locale: $locale ==="
    $proc = Start-Process -FilePath $engine -ArgumentList @(
        '-no-remote', '-profile', "`"$profile`"", '-pref', "intl.locale.requested=$locale"
    ) -PassThru
    Start-Sleep -Seconds 8
    Write-Host "Window title: $(Get-MainTitle)"
    $proc | Stop-Process -Force -ErrorAction SilentlyContinue
    Get-Process firefox -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
}
