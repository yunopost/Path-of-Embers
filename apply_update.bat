@echo off
REM Path of Embers - apply the latest code update.
REM Double-click this file. It unpacks poe_update.tgz over the project folder
REM it is sitting in, overwriting only the files that changed.
cd /d "%~dp0"
if not exist "poe_update.tgz" (
  echo Could not find poe_update.tgz next to this script.
  pause
  exit /b 1
)
echo Applying update to %CD% ...
tar -xzf poe_update.tgz
if errorlevel 1 (
  echo.
  echo Extract failed. You can unpack poe_update.tgz manually over this folder.
  pause
  exit /b 1
)
echo.
echo Done. Open the project in Godot - it will re-import anything that changed.
pause
