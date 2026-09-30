@echo off
title Hotel TV Template v2.0.1 - Build & Packager
color 0A

echo ===============================================================
echo   HOTEL TV TEMPLATE v2.0.1 - AUTOMATED BUILD & PACKAGER
echo ===============================================================
echo.
echo [*] Working directory: %~dp0
echo [*] Executing build engine (build.js)...
echo.

cd /d "%~dp0"

:: Check for node in PATH or default Program Files
where node >nul 2>nul
if %errorlevel% equ 0 (
    node build.js
) else if exist "C:\Program Files\nodejs\node.exe" (
    "C:\Program Files\nodejs\node.exe" build.js
) else (
    color 0C
    echo [ERROR] Node.js was not found! Please ensure Node.js is installed.
)

echo.
echo ===============================================================
echo   Press any key to close this window.
echo ===============================================================
pause >nul
