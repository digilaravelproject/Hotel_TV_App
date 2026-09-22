@echo off
setlocal enabledelayedexpansion

echo ========================================================
echo   PAX TV Hospitality - LG webOS Build ^& Package Script
echo ========================================================
echo.

echo [1/3] Verifying webOS platform directory...
if not exist "webos\appinfo.json" (
    echo [ERROR] 'webos\appinfo.json' not found!
    exit /b 1
)

echo.
echo [2/3] Locating LG webOS CLI (ares-package)...
set "ARES_PKG=ares-package"
where ares-package >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    if exist "C:\Program Files\nodejs\ares-package.cmd" (
        set "ARES_PKG=C:\Program Files\nodejs\ares-package.cmd"
    ) else (
        echo [ERROR] 'ares-package' command not found!
        echo Please ensure webOS TV CLI is installed or in PATH.
        exit /b 1
    )
)

echo.
echo [3/3] Packaging LG webOS .ipk bundle...
call "%ARES_PKG%" webos -o .
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Packaging with ares-package failed!
    exit /b %ERRORLEVEL%
)

copy "com.pax.hospitality.tv_1.0.0_all.ipk" "pax_tv.ipk" >nul 2>nul

echo.
echo ========================================================
echo   SUCCESS! LG webOS IPK Package created successfully!
echo   Package: com.pax.hospitality.tv_1.0.0_all.ipk (pax_tv.ipk)
echo ========================================================
echo.
echo To install on your LG TV or Emulator:
echo   ares-install -d emulator com.pax.hospitality.tv_1.0.0_all.ipk
echo   ares-launch  -d emulator com.pax.hospitality.tv
echo.
pause
