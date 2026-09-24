@echo off
setlocal
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_webos.ps1" %*
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Build script failed with exit code %ERRORLEVEL%
    pause
    exit /b %ERRORLEVEL%
)

echo.
pause
