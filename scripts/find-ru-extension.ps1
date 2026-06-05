$profile = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles\kn9q3hkf.stealth'
$ext = Join-Path $profile 'extensions.json'
if (Test-Path $ext) {
    $json = Get-Content $ext -Raw | ConvertFrom-Json
    $json.addons | Where-Object { $_.id -match 'langpack|ru@' } | ForEach-Object {
        Write-Host "$($_.id) v$($_.version) active=$($_.active)"
    }
}
Get-ChildItem (Join-Path $profile 'storage\default') -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'langpack|ru' } | Select-Object -First 10 Name
