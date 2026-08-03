#!/bin/bash
# ============================================================
# Hotel TV Auto Device Owner Setup Script
# ============================================================
# Usage:
#   chmod +x auto_setup_device_owner.sh
#   ./auto_setup_device_owner.sh [TV_IP]        # specific IP
#   ./auto_setup_device_owner.sh                # auto scan
# ============================================================

PACKAGE="com.digiemperor.hotel"
ADMIN_RECEIVER="com.digiemperor.hotel/.MyDeviceAdminReceiver"
ADB_PORT=5555
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "============================================================"
echo "  Hotel TV Auto Device Owner Setup"
echo "============================================================"
echo ""

# Step 1: Find TV IP
if [ -n "$1" ]; then
    TV_IP="$1"
    echo -e "${YELLOW}Using provided IP: $TV_IP${NC}"
else
    echo -e "${YELLOW}Scanning network for Android TV (port 5555)...${NC}"
    LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
    SUBNET=$(echo "$LOCAL_IP" | cut -d'.' -f1-3)

    if [ -z "$SUBNET" ]; then
        echo -e "${RED}Could not detect local network. Provide TV IP manually:${NC}"
        echo "   ./auto_setup_device_owner.sh [TV_IP]"
        exit 1
    fi

    echo "   Scanning $SUBNET.1 - $SUBNET.254 ..."
    TV_IP=""
    for i in $(seq 1 254); do
        IP="$SUBNET.$i"
        nc -z -w 0.3 "$IP" $ADB_PORT 2>/dev/null && TV_IP="$IP" && break
    done

    if [ -z "$TV_IP" ]; then
        echo -e "${RED}No Android TV found with ADB port open.${NC}"
        echo ""
        echo "Make sure:"
        echo "  1. TV and Mac are on same WiFi"
        echo "  2. ADB enabled on TV"
        echo "  3. Or run: ./auto_setup_device_owner.sh 192.168.1.XXX"
        exit 1
    fi
    echo -e "${GREEN}Found TV at: $TV_IP${NC}"
fi

# Step 2: ADB Connect
echo ""
echo -e "${YELLOW}Connecting via ADB...${NC}"
adb kill-server > /dev/null 2>&1
adb start-server > /dev/null 2>&1
CONNECT_RESULT=$(adb connect "$TV_IP:$ADB_PORT" 2>&1)
echo "   $CONNECT_RESULT"
sleep 2

DEVICES=$(adb devices 2>&1 | grep "$TV_IP")
if [ -z "$DEVICES" ]; then
    echo -e "${RED}ADB connection failed to $TV_IP:$ADB_PORT${NC}"
    exit 1
fi
echo -e "${GREEN}ADB connected!${NC}"

# Step 3: Check if already Device Owner
echo ""
echo -e "${YELLOW}Checking Device Owner status...${NC}"
IS_OWNER=$(adb -s "$TV_IP:$ADB_PORT" shell dpm list-owners 2>&1 | grep "$PACKAGE")

if [ -n "$IS_OWNER" ]; then
    echo -e "${GREEN}Already Device Owner! No action needed.${NC}"
    echo ""
    echo "   App is permanently set as launcher. Done!"
    exit 0
fi

# Step 4: Check for Google Accounts
echo ""
echo -e "${YELLOW}Checking for Google accounts...${NC}"
ACCOUNTS=$(adb -s "$TV_IP:$ADB_PORT" shell "dumpsys account | grep 'Account {'" 2>&1)
if echo "$ACCOUNTS" | grep -q "google"; then
    echo -e "${RED}Google Account detected! Must remove first.${NC}"
    echo ""
    echo "   TV me jaao: Settings > Accounts > Google > Remove Account"
    echo "   Phir script dobara run karo."
    exit 1
fi
echo -e "${GREEN}No Google accounts. Proceeding...${NC}"

# Step 5: Set Device Owner
echo ""
echo -e "${YELLOW}Setting Device Owner...${NC}"
SET_RESULT=$(adb -s "$TV_IP:$ADB_PORT" shell dpm set-device-owner "$ADMIN_RECEIVER" 2>&1)
echo "   $SET_RESULT"

if echo "$SET_RESULT" | grep -q "Success"; then
    echo ""
    echo -e "${GREEN}============================================================${NC}"
    echo -e "${GREEN}  SUCCESS! Device Owner set permanently!${NC}"
    echo -e "${GREEN}============================================================${NC}"
    echo ""
    echo "  Hotel TV App ab:"
    echo "  - Permanent Home Launcher (reboot safe)"
    echo "  - Kiosk Mode Active"
    echo "  - ADB auto-enabled on every launch"
    echo "  - Guest exit/uninstall nahi kar sakta"
    echo ""
    echo -e "${YELLOW}  App restart kar raha hoon...${NC}"
    adb -s "$TV_IP:$ADB_PORT" shell am force-stop "$PACKAGE"
    sleep 1
    adb -s "$TV_IP:$ADB_PORT" shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1
    echo -e "${GREEN}  Done! TV fully locked.${NC}"
else
    echo ""
    echo -e "${RED}Failed to set Device Owner.${NC}"
    echo "   Reason: $SET_RESULT"
    echo ""
    echo "   Fix karo:"
    echo "   - Sab Google accounts remove karo"
    echo "   - TV factory reset karke try karo"
    echo "   - App install check: adb install TVHotel.apk"
fi
