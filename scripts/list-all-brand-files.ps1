Add-Type -AssemblyName System.IO.Compression.FileSystem
$omni = Join-Path $env:LOCALAPPDATA 'StealthBrowser\Engine\browser\omni.ja'
$zip = [IO.Compression.ZipFile]::OpenRead($omni)
$zip.Entries |
    Where-Object { $_.FullName -match 'branding/brand\.(ftl|properties)$' } |
    ForEach-Object {
        $sr = New-Object IO.StreamReader($_.Open())
        $t = $sr.ReadToEnd()
        $sr.Close()
        $full = if ($t -match 'brand-full-name\s*=\s*(.+)$') { $Matches[1].Trim() } 
                elseif ($t -match 'brandFullName\s*=\s*(.+)$') { $Matches[1].Trim() }
                else { '?' }
        Write-Host "$($_.FullName) => $full"
    }
$zip.Dispose()
