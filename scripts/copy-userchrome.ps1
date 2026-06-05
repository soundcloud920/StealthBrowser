$profileChrome = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles\kn9q3hkf.stealth\chrome'
New-Item -ItemType Directory -Force -Path $profileChrome | Out-Null
Copy-Item (Join-Path (Split-Path $PSScriptRoot -Parent) 'bundle\templates\userChrome.css') (Join-Path $profileChrome 'userChrome.css') -Force
Write-Host "Copied userChrome.css -> $profileChrome"
