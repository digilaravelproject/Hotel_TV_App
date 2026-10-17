# ═══════════════════════════════════════════════════════════════════
#  PAX Hotel TV - Batch Installer for Multiple LG webOS TVs
#  Run this script once to install app on ALL hotel TVs
#
#  USAGE:
#    1. TV IPs list karo neeche (HOTEL_TV_IPS array me)
#    2. Ek baar run karo: .\batch_install_tvs.ps1
#    3. Sab TVs par app install + launch ho jayega automatically
# ═══════════════════════════════════════════════════════════════════

# ── CONFIGURATION ─────────────────────────────────────────────────
$IPK_FILE   = ".\com.pax.hospitality.tv_1.0.1_all.ipk"
$APP_ID     = "com.pax.hospitality.tv"
$SSH_PORT   = 9922
$PASSPHRASE = "57309C"

# ── HOTEL TV IP LIST — Yahaan apne saare TVs ke IPs daalo ─────────
$HOTEL_TV_IPS = @(
    "192.168.1.121",   # Room 101
    "192.168.1.122",   # Room 102
    "192.168.1.123",   # Room 103
    # Aur IPs add karte jao...
)

# ── SCRIPT START ───────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   PAX Hotel TV - Batch Installer             ║" -ForegroundColor Cyan
Write-Host "║   Total TVs: $($HOTEL_TV_IPS.Count)                              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if (!(Test-Path $IPK_FILE)) {
    Write-Host "[ERROR] IPK file nahi mili: $IPK_FILE" -ForegroundColor Red
    exit 1
}

$success = 0
$failed  = 0
$results = @()

foreach ($ip in $HOTEL_TV_IPS) {
    $deviceName = "tv_$($ip -replace '\.', '_')"
    Write-Host "─────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "TV: $ip" -ForegroundColor Yellow

    try {
        # Step 1: Device add karo
        Write-Host "   [1/3] Device register..." -NoNewline
        & ares-setup-device --add $deviceName --info "{`"host`":`"$ip`",`"port`":$SSH_PORT,`"username`":`"prisoner`",`"privateKey`":{`"openSsh`":`"mytv_webos`"},`"passphrase`":`"$PASSPHRASE`"}" 2>&1 | Out-Null
        Write-Host " OK" -ForegroundColor Green

        # Step 2: IPK install karo
        Write-Host "   [2/3] App install..." -NoNewline
        $installOut = & ares-install -d $deviceName $IPK_FILE 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host " INSTALLED" -ForegroundColor Green
        } else {
            Write-Host " FAILED" -ForegroundColor Red
            $failed++
            $results += [PSCustomObject]@{ IP=$ip; Status="FAILED"; Reason=$installOut }
            & ares-setup-device --remove $deviceName 2>&1 | Out-Null
            continue
        }

        # Step 3: App launch karo
        Write-Host "   [3/3] App launch..." -NoNewline
        $launchOut = & ares-launch -d $deviceName $APP_ID 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host " LAUNCHED" -ForegroundColor Green
        } else {
            Write-Host " OK (already installed)" -ForegroundColor DarkYellow
        }
        $success++
        $results += [PSCustomObject]@{ IP=$ip; Status="SUCCESS"; Reason="" }

    } catch {
        Write-Host " ERROR: $_" -ForegroundColor Red
        $failed++
        $results += [PSCustomObject]@{ IP=$ip; Status="ERROR"; Reason=$_.ToString() }
    }

    & ares-setup-device --remove $deviceName 2>&1 | Out-Null
}

Write-Host ""
Write-Host "SUMMARY: Success=$success  Failed=$failed" -ForegroundColor Cyan
$results | Format-Table -AutoSize
