Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($omni in @(
    (Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\browser\omni.ja'),
    (Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\omni.ja')
)) {
    $zip = [IO.Compression.ZipFile]::OpenRead($omni)
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName -notmatch 'panelUI|toolbarseparator') { continue }
        if ($entry.Length -gt 500000) { continue }
        $sr = New-Object IO.StreamReader($entry.Open())
        $text = $sr.ReadToEnd()
        $sr.Close()
        if ($text -match 'toolbarseparator.*::before|proton-zap') {
            Write-Host "--- $($entry.FullName) ---"
            $text -split "`n" | Select-String 'toolbarseparator|proton-zap' | Select-Object -First 15
        }
    }
    $zip.Dispose()
}
