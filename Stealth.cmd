@echo off
set "LAUNCHER=%LOCALAPPDATA%\StealthBrowser\Launch-Stealth.ps1"
if not exist "%LAUNCHER%" set "LAUNCHER=%~dp0Launch-Stealth.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%LAUNCHER%"
exit /b %ERRORLEVEL%
