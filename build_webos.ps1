param(
    [switch]$Rebuild,
    [string]$SetVersion = "",
    [switch]$NoBump
)

# ========================================================
#   PAX TV Hospitality - LG webOS Build & Package Script (PowerShell)
# ========================================================

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  PAX TV Hospitality - LG webOS Auto-Versioning & Package" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# [1/5] Auto-Versioning in appinfo.json
Write-Host "[1/5] Resolving webOS package version..." -ForegroundColor Yellow
$appInfoPath = "web\appinfo.json"
if (-not (Test-Path $appInfoPath)) {
    Write-Host "[ERROR] '$appInfoPath' not found!" -ForegroundColor Red
    exit 1
}

$appInfo = Get-Content $appInfoPath -Raw | ConvertFrom-Json
$oldVersion = $appInfo.version

if ($SetVersion -ne "") {
    $newVersion = $SetVersion
    Write-Host "Explicit version set: $newVersion" -ForegroundColor Green
} elseif ($NoBump) {
    $newVersion = $oldVersion
    Write-Host "Using existing version without bump: $newVersion" -ForegroundColor Cyan
} else {
    $parts = $oldVersion.Split('.')
    if ($parts.Count -eq 3) {
        $patch = [int]$parts[2] + 1
        $newVersion = "$($parts[0]).$($parts[1]).$patch"
    } else {
        $newVersion = "1.0.1"
    }
    Write-Host "Auto-incremented version: $oldVersion -> $newVersion" -ForegroundColor Green
}

$appInfo.version = $newVersion
$appInfo | ConvertTo-Json -Depth 10 | Set-Content $appInfoPath -Encoding UTF8

Write-Host ""
Write-Host "[2/5] Checking Flutter Web compilation..." -ForegroundColor Yellow
if ($Rebuild -or (-not (Test-Path "build\web\index.html"))) {
    Write-Host "Compiling Flutter Web release bundle..." -ForegroundColor Cyan
    flutter build web --release --no-tree-shake-icons
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Flutter Web compilation failed!" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

Write-Host ""
Write-Host "[3/5] Syncing version $newVersion & assets to build/web..." -ForegroundColor Yellow
Copy-Item "web\appinfo.json" "build\web\" -Force
Copy-Item "web\icon.png" "build\web\" -Force
Copy-Item "web\largeIcon.png" "build\web\" -Force
Copy-Item "web\index.html" "build\web\" -Force
if (Test-Path "web\webOSTVjs-1.2.13") {
    Copy-Item -Recurse -Force "web\webOSTVjs-1.2.13" "build\web\"
}
if (Test-Path "web\assets") {
    Copy-Item -Recurse -Force "web\assets" "build\web\"
}

Write-Host ""
Write-Host "[4/5] Locating LG webOS CLI (ares-package)..." -ForegroundColor Yellow
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
Write-Host "[5/5] Packaging version $newVersion into LG webOS .ipk bundle..." -ForegroundColor Yellow
& $aresPkg build/web -o .
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Packaging with ares-package failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

$generatedIpk = "com.pax.hospitality.tv_$($newVersion)_all.ipk"
if (Test-Path $generatedIpk) {
    Copy-Item $generatedIpk "pax_tv.ipk" -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "  SUCCESS! LG webOS IPK Package created successfully!   " -ForegroundColor Green
Write-Host "  Version: $newVersion" -ForegroundColor Green
Write-Host "  Package: $generatedIpk" -ForegroundColor Green
Write-Host "  Alias:   pax_tv.ipk (Always latest)" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "To install this latest version on your LG TV or Emulator:" -ForegroundColor Cyan
Write-Host "  ares-install -d emulator $generatedIpk" -ForegroundColor White
Write-Host "  ares-launch  -d emulator com.pax.hospitality.tv" -ForegroundColor White
Write-Host ""
