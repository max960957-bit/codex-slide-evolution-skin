@echo off
setlocal
echo D6: six original images and EX video. Save work and exit ordinary Codex before running.
echo No existing task is required to start. Content screenshots are disabled.
echo GPU acceleration is disabled for this lab run to investigate the recorded GPU crashes.
echo The skin stays open until you click End Skin in the top-right controls. Keep this launcher open.
where pwsh.exe >nul 2>&1
if %ERRORLEVEL% EQU 0 (
  pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0glass-lab.ps1" -SequenceReview -DisableGpu
) else (
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0glass-lab.ps1" -SequenceReview -DisableGpu
)
set "LAB_EXIT=%ERRORLEVEL%"
echo Results are in the newest folder under %~dp0runs
pause
exit /b %LAB_EXIT%
