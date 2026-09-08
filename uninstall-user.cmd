@echo off
setlocal
set "TARGET=%LOCALAPPDATA%\CodexSlideEvolutionSkin"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "& '%TARGET%\uninstall.ps1'"
if errorlevel 1 pause
