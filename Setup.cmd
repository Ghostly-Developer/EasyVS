@echo off
REM Double-click to open the "Open with VS Code" setup window (install, update or uninstall).
if not exist "%~dp0OpenWithVSCode.ps1" (
    echo OpenWithVSCode.ps1 was not found next to Setup.cmd.
    echo Extract the whole zip first ^(right-click it, then Extract All^), then run Setup.cmd again.
    pause
    exit /b 1
)
start "" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0OpenWithVSCode.ps1"
