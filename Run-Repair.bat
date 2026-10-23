@echo off
setlocal
title Codex Runtime Repair

cd /d "%~dp0"

if not exist "%~dp0Repair-CodexRuntime.ps1" (
    echo [ERROR] Repair-CodexRuntime.ps1 was not found next to this launcher.
    echo Keep both files in the same folder and try again.
    echo.
    pause
    exit /b 1
)

where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Windows PowerShell was not found on PATH.
    echo.
    pause
    exit /b 1
)

echo Codex Runtime Repair
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Repair-CodexRuntime.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if "%EXIT_CODE%"=="0" (
    echo Result: repair completed or nothing to repair.
) else if "%EXIT_CODE%"=="2" (
    echo Result: copy finished with warnings. Read the output above.
) else (
    echo Result: repair failed with exit code %EXIT_CODE%. Read the output above.
)

echo.
pause
exit /b %EXIT_CODE%
