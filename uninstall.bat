@echo off
REM Double-click to remove "Open with VS Code" from the right-click menu.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1"
pause
