@echo off
setlocal
cd /d "%~dp0"
echo Running Godot Environment Setup...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
if %ERRORLEVEL% neq 0 (
    echo.
    echo Setup failed. Press any key to exit.
    pause >nul
    exit /b %ERRORLEVEL%
)
echo.
echo Setup completed!
pause
