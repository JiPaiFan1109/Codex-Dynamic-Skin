@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0scripts\install.ps1" %*
if errorlevel 1 (
  echo Installation failed. See the error above.
  pause
  exit /b 1
)
echo Installation complete. Use the desktop shortcuts to start.
pause
