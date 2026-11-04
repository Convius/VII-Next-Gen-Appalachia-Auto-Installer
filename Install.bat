@echo off
title VII Next-Gen Appalachia 4.0 - Installer
if not exist "%~dp0payload\presets" (
  echo.
  echo  The payload folder was not found next to this file.
  echo  Please extract the WHOLE zip to a normal folder first, then run Install.bat again.
  echo.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Installer.ps1"
