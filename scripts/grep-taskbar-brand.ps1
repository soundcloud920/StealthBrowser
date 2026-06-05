Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\browser\omni.ja'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
foreach ($entry in $zip.Entries) {
    if ($entry.Length -gt 300000) { continue }
    if ($entry.FullName -notmatch '\.(ftl|properties|js|mjs)$') { continue }
    $sr = New-Object IO.StreamReader($entry.Open())
    $t = $sr.ReadToEnd()
    $sr.Close()
    if ($t -match 'Mozilla Firefox|brandFullName|taskbar|AppUserModel') {
        if ($t -match 'Mozilla Firefox') {
            Write-Host "$($entry.FullName) => Mozilla Firefox"
        }
    }
}
$zip.Dispose()
