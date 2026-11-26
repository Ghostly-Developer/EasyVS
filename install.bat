@echo off
REM Double-click to add "Open with VS Code" to the right-click menu.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
pause
