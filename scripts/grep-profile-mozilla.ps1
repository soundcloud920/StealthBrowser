$profile = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles\kn9q3hkf.stealth'
Get-ChildItem $profile -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch 'parent\.lock|\.sqlite|\.jsonlz4|\.msf' } |
    ForEach-Object {
        try {
            if ($_.Length -gt 500000) { return }
            $c = Get-Content $_.FullName -Raw -ErrorAction Stop
            if ($c -match 'Mozilla Firefox') { Write-Host $_.FullName }
        } catch {}
    }
