@echo off
setlocal
set "NETORY_PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "NETORY_PS=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%NETORY_PS%" -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup.ps1" -Mode Uninstall
if errorlevel 1 pause
