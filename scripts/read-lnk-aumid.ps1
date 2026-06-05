#Requires -Version 5.1
param([string[]]$Paths = @(
    (Join-Path $env:USERPROFILE 'Desktop\Stealth.lnk'),
    (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Stealth.lnk')
))

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class LnkAumid {
    [ComImport, Guid("00021401-0000-0000-C000-000000000046")]
    public interface IShellLinkW {
        void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszFile, int cchMaxPath, IntPtr pfd, uint fFlags);
        void GetIDList(out IntPtr ppidl);
        void SetIDList(IntPtr pidl);
        void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszName, int cchMaxName);
        void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);
        void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszDir, int cchMaxPath);
        void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDir);
        void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszArgs, int cchMaxPath);
        void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);
        void GetHotkey(out short pwHotkey);
        void SetHotkey(short wHotkey);
        void GetShowCmd(out int piShowCmd);
        void SetShowCmd(int iShowCmd);
        void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszIconPath, int cchIconPath, out int piIcon);
        void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string pszIconPath, int iIcon);
        void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string pszPath, uint dwReserved);
        void Resolve(IntPtr hwnd, uint fFlags);
        void SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);
    }

    [ComImport, Guid("0000010c-0000-0000-C000-000000000046")]
    public interface IPersist { int GetClassID(out Guid pClassID); }

    [ComImport, Guid("0000010b-0000-0000-C000-000000000046")]
    public interface IPersistFile : IPersist {
        new int GetClassID(out Guid pClassID);
        int IsDirty();
        int Load([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, uint dwMode);
        int Save([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, bool fRemember);
        int SaveCompleted([MarshalAs(UnmanagedType.LPWStr)] string pszFileName);
        int GetCurFile([MarshalAs(UnmanagedType.LPWStr)] out string ppszFileName);
    }

    [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IPropertyStore {
        int GetCount(out uint c);
        int GetAt(uint i, out PropertyKey key);
        int GetValue(ref PropertyKey key, out PropVariant pv);
        int SetValue(ref PropertyKey key, ref PropVariant pv);
        int Commit();
    }

    [StructLayout(LayoutKind.Sequential, Pack=4)]
    public struct PropertyKey { public Guid fmtid; public uint pid; }

    [StructLayout(LayoutKind.Sequential)]
    public struct PropVariant {
        public ushort vt; public ushort w1,w2,w3; public IntPtr ptr;
        public int i1,i2,i3,i4;
    }

    public static readonly PropertyKey PKEY_AppUserModel_ID = new PropertyKey {
        fmtid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), pid = 5
    };
    public static readonly PropertyKey PKEY_RelaunchName = new PropertyKey {
        fmtid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), pid = 3
    };

    [DllImport("ole32.dll")]
    public static extern int CoTaskMemFree(IntPtr pv);

    public static string ReadProp(IPropertyStore ps, PropertyKey key) {
        PropVariant pv;
        if (ps.GetValue(ref key, out pv) != 0 || pv.vt != 31) return "";
        string val = Marshal.PtrToStringUni(pv.ptr);
        CoTaskMemFree(pv.ptr);
        return val ?? "";
    }
}
"@

foreach ($lnk in $Paths) {
    Write-Host "=== $lnk ==="
    if (-not (Test-Path $lnk)) { Write-Host '  (missing)'; continue }
    $shell = [LnkAumid+IShellLinkW][Activator]::CreateInstance([Type]::GetTypeFromCLSID([Guid]'00021401-0000-0000-C000-000000000046'))
    $pf = [LnkAumid+IPersistFile]$shell
    $pf.Load($lnk, 0)
    $path = New-Object Text.StringBuilder 260
    $args = New-Object Text.StringBuilder 1024
    $shell.GetPath($path, 260, [IntPtr]::Zero, 0)
    $shell.GetArguments($args, 1024)
    Write-Host "  Target=$($path) Args=$($args)"
    $ps = [LnkAumid+IPropertyStore]$shell
    $idKey = [LnkAumid]::PKEY_AppUserModel_ID
    $nameKey = [LnkAumid]::PKEY_RelaunchName
    Write-Host "  AppUserModelId=$([LnkAumid]::ReadProp($ps, $idKey))"
    Write-Host "  RelaunchDisplayName=$([LnkAumid]::ReadProp($ps, $nameKey))"
}
