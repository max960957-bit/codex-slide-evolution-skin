@echo off
setlocal
set "TARGET=%LOCALAPPDATA%\CodexSlideEvolutionSkin"
if not exist "%TARGET%\manage-skins.ps1" (echo 请先运行 install-user.cmd 安装换肤工具。 & pause & exit /b 1)
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%TARGET%\manage-skins.ps1"
