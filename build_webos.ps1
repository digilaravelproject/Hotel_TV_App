# ========================================================
#   PAX TV Hospitality - LG webOS Build & Package Script (PowerShell)
# ========================================================

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  PAX TV Hospitality - LG webOS Build & Package Script  " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/3] Verifying webOS platform directory..." -ForegroundColor Yellow
if (-not (Test-Path "webos\appinfo.json")) {
    Write-Host "[ERROR] 'webos\appinfo.json' not found!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[2/3] Locating LG webOS CLI (ares-package)..." -ForegroundColor Yellow
$aresPkg = "ares-package"
$aresCmd = Get-Command $aresPkg -ErrorAction SilentlyContinue
if (-not $aresCmd) {
    if (Test-Path "C:\Program Files\nodejs\ares-package.cmd") {
        $aresPkg = "C:\Program Files\nodejs\ares-package.cmd"
    } else {
        Write-Host "[ERROR] 'ares-package' command not found!" -ForegroundColor Red
        Write-Host "Please ensure webOS TV CLI is installed or added to PATH." -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""
Write-Host "[3/3] Packaging LG webOS .ipk bundle..." -ForegroundColor Yellow
& $aresPkg webos -o .
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Packaging with ares-package failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

Copy-Item "com.pax.hospitality.tv_1.0.0_all.ipk" "pax_tv.ipk" -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "  SUCCESS! LG webOS IPK Package created successfully!   " -ForegroundColor Green
Write-Host "  Package: com.pax.hospitality.tv_1.0.0_all.ipk (pax_tv.ipk)" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "To install on your LG TV or Emulator:" -ForegroundColor Cyan
Write-Host "  ares-install -d emulator com.pax.hospitality.tv_1.0.0_all.ipk" -ForegroundColor White
Write-Host "  ares-launch  -d emulator com.pax.hospitality.tv" -ForegroundColor White
Write-Host ""
