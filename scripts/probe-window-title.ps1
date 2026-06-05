Add-Type -TypeDefinition @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
public static class WinTitle {
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr h, StringBuilder s, int c);
    public static void DumpFirefox() {
        EnumWindows((h,l) => {
            uint p; GetWindowThreadProcessId(h, out p);
            try { if (Process.GetProcessById((int)p).ProcessName != "firefox") return true; } catch { return true; }
            var sb = new StringBuilder(512);
            GetWindowText(h, sb, 512);
            if (sb.Length > 0) Console.WriteLine("PID="+p+" title="+sb);
            return true;
        }, IntPtr.Zero);
    }
}
"@
[WinTitle]::DumpFirefox()
