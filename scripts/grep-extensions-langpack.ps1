$profile = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles\kn9q3hkf.stealth'
$ext = Join-Path $profile 'extensions.json'
$raw = Get-Content $ext -Raw
if ($raw -match 'langpack') { Write-Host 'langpack found in extensions.json' }
Select-String -Path $ext -Pattern 'langpack|ru@mozilla' -AllMatches | ForEach-Object { $_.Line.Substring(0, [Math]::Min(500, $_.Line.Length)) }
