$ext = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles\kn9q3hkf.stealth\extensions.json'
$json = Get-Content $ext -Raw | ConvertFrom-Json
$json.addons | ForEach-Object { Write-Host $_.id }
