$engine = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\firefox.exe'
$launcher = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Stealth.exe'
$profile = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles\kn9q3hkf.stealth'
Get-Process firefox -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

Add-Type @"
using System; using System.Diagnostics; using System.Runtime.InteropServices; using System.Text;
public static class TitleWatch {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc e, IntPtr l);
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int c);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int c);
  public static string GetMain() {
    string found = null;
    EnumWindows((h,l) => {
      uint procId; GetWindowThreadProcessId(h, out procId);
      try { if (Process.GetProcessById((int)procId).ProcessName != "firefox") return true; } catch { return true; }
      var cls = new StringBuilder(256); GetClassName(h, cls, 256);
      if (cls.ToString() != "MozillaWindowClass") return true;
      var sb = new StringBuilder(512); GetWindowText(h, sb, 512);
      if (sb.Length > 0) found = sb.ToString();
      return true;
    }, IntPtr.Zero);
    return found ?? '(none)';
  }
}
"@

Write-Host '=== Via Stealth.exe launcher ==='
Start-Process $launcher
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Seconds 2
    $t = [TitleWatch]::GetMain()
    Write-Host "t+${i}s: $t"
    if ($t -eq 'Mozilla Firefox') { Write-Host '*** REGRESSION TO Mozilla Firefox ***'; break }
}
