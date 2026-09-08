@echo off
setlocal
set "TARGET=%LOCALAPPDATA%\CodexSlideEvolutionSkin"
if not exist "%TARGET%\import-skin.ps1" (
  echo 请先运行 install-user.cmd 安装换肤工具。
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%TARGET%\import-skin.ps1"
if errorlevel 1 pause
