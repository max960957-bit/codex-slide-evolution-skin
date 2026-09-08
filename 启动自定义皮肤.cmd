@echo off
setlocal
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0select-skin.ps1"
set "SKIN_EXIT=%ERRORLEVEL%"
pause
exit /b %SKIN_EXIT%
