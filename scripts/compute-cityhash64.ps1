# CityHash64 for Firefox install path (UTF-16LE bytes) - validate against known PF path
Add-Type -TypeDefinition @"
using System;
using System.Text;

// Port of CityHash64 v1.0.3 (Google) - minimal for path hashing
public static class CityHash64 {
    private const ulong k0 = 0xc3a5c85c97cb3127UL;
    private const ulong k1 = 0xb492b66fbe98f273UL;
    private const ulong k2 = 0x9ae16a3b2f90404fUL;

    private static ulong Fetch64(byte[] s, int pos) {
        return BitConverter.ToUInt64(s, pos);
    }
    private static uint Fetch32(byte[] s, int pos) {
        return BitConverter.ToUInt32(s, pos);
    }
    private static ulong Rotate(ulong val, int shift) {
        return shift == 0 ? val : (val >> shift) | (val << (64 - shift));
    }
    private static ulong ShiftMix(ulong val) { return val ^ (val >> 47); }
    private static ulong HashLen16(ulong u, ulong v) {
        return Hash128To64(u, v);
    }
    private static ulong Hash128To64(ulong lo, ulong hi) {
        const ulong kMul = 0x9ddfea08eb382d69UL;
        ulong a = (lo ^ hi) * kMul; a ^= a >> 47;
        ulong b = (hi ^ a) * kMul; b ^= b >> 47; b *= kMul;
        return b;
    }
    private static ulong HashLen0to16(byte[] s, int len) {
        if (len >= 8) {
            ulong mul = k2 + (ulong)len * 2;
            ulong a = Fetch64(s, 0) + k1;
            ulong b = Fetch64(s, len - 8);
            ulong c = Rotate(b, 37) * mul + a;
            ulong d = (Rotate(a, 25) + b) * mul;
            return HashLen16(c, d, mul);
        }
        if (len >= 4) {
            ulong mul = k2 + (ulong)len * 2;
            ulong a = Fetch32(s, 0);
            return HashLen16((ulong)len + (a << 3), Fetch32(s, len - 4), mul);
        }
        if (len > 0) {
            byte a = s[0]; byte b = s[len >> 1]; byte c = s[len - 1];
            int y = (int)a + ((int)b << 8);
            int z = len + ((int)c << 2);
            return ShiftMix((ulong)y * k2 ^ (ulong)z * k0) * k2;
        }
        return k2;
    }
    private static ulong HashLen16(ulong u, ulong v, ulong mul) {
        ulong a = (u ^ v) * mul; a ^= a >> 47;
        ulong b = (v ^ a) * mul; b ^= b >> 47; b *= mul;
        return b;
    }
    private static ulong HashLen17to32(byte[] s, int len) {
        ulong mul = k2 + (ulong)len * 2;
        ulong a = Fetch64(s, 0) * k1;
        ulong b = Fetch64(s, 8);
        ulong c = Fetch64(s, len - 8) * mul;
        ulong d = Fetch64(s, len - 16) * k2;
        return HashLen16(Rotate(a + b, 43) + Rotate(c, 30) + d,
            a + Rotate(b + k2, 18) + c, mul);
    }
    private static ulong HashLen33to64(byte[] s, int len) {
        ulong mul = k2 + (ulong)len * 2;
        ulong a = Fetch64(s, 0) * k2;
        ulong b = Fetch64(s, 8);
        ulong c = Fetch64(s, len - 24);
        ulong d = Fetch64(s, len - 32);
        ulong e = Fetch64(s, 16) * k2;
        ulong f = Fetch64(s, 24) * 9;
        ulong g = Fetch64(s, len - 8);
        ulong h = Fetch64(s, len - 16) * mul;
        ulong u = Rotate(a + g, 43) + (Rotate(b, 30) + c) * 9;
        ulong v = ((a + g) ^ d) + f + 1;
        ulong w = BitConverter.ToUInt64(BitConverter.GetBytes(g ^ (e + f)), 0) + b;
        ulong x = Rotate(e, 42) + c;
        ulong y = (Rotate((u + v + w) * mul, 35) + h) * mul;
        ulong z = HashLen16(u, v, mul);
        return HashLen16(x + z, y + Rotate(g + h, 44) + f, mul);
    }
    public static ulong Hash64(byte[] s) {
        int len = s.Length;
        if (len <= 32) {
            if (len <= 16) return HashLen0to16(s, len);
            return HashLen17to32(s, len);
        }
        if (len <= 64) return HashLen33to64(s, len);
        ulong x = Fetch64(s, len - 40);
        ulong y = Fetch64(s, len - 16) + Fetch64(s, len - 56);
        ulong z = HashLen16(Fetch64(s, len - 48) + (ulong)len, Fetch64(s, len - 24));
        ulong vFirst = Fetch64(s, len - 64);
        ulong vSecond = Fetch64(s, len - 64 + 8);
        ulong wFirst = Fetch64(s, len - 32);
        ulong wSecond = Fetch64(s, len - 32 + 8);
        x = Rotate(x + y + vFirst + Fetch64(s, 8), 37) * k1;
        y = Rotate(y + vSecond + Fetch64(s, 48), 42) * k1;
        x ^= wSecond;
        y += vFirst + Fetch64(s, 40);
        z = Rotate(z + wFirst, 33) * k1;
        int end = ((len - 1) / 64) * 64;
        int last64 = end + ((len - 1) & 63) - 63;
        int i = 0;
        do {
            x = Rotate(x + y + vFirst + Fetch64(s, i + 8), 37) * k1;
            y = Rotate(y + vSecond + Fetch64(s, i + 48), 42) * k1;
            x ^= wSecond;
            y += vFirst + Fetch64(s, i + 40);
            z = Rotate(z + wFirst, 33) * k1;
            ulong tempVFirst = vFirst;
            vFirst = z;
            z = tempVFirst;
            ulong a = vSecond * k1 ^ Fetch64(s, i) * k0;
            ulong b = vFirst + Fetch64(s, i + 40);
            ulong c = wFirst + Fetch64(s, i + 16);
            ulong d = wSecond + Fetch64(s, i + 56);
            ulong temp = x; x = z; z = temp;
            vSecond = a + c;
            vFirst = b + d;
            wFirst = Fetch64(s, i + 32);
            wSecond = Fetch64(s, i + 24);
            i += 64;
        } while (i != end);
        return HashLen16(HashLen16(vFirst, wFirst) + ShiftMix(y) * k1 + z,
            HashLen16(vSecond, wSecond) + x);
    }
    public static string HashPath(string path) {
        byte[] bytes = Encoding.Unicode.GetBytes(path);
        ulong h = Hash64(bytes);
        return h.ToString("X");
    }
}
"@

$pf = 'C:\Program Files\Mozilla Firefox'
$engine = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine'
Write-Host "PF hash:   $([CityHash64]::HashPath($pf))"
Write-Host "Engine hash: $([CityHash64]::HashPath($engine))"
