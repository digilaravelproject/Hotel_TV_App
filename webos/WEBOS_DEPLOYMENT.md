# LG webOS TV Deployment & Testing Guide

Is guide me PAX TV Hospitality application ko LG webOS TV Emulator ya Real LG Smart TV par deploy aur test karne ke exact instructions diye gaye hain.

---

## 1. Prerequisites (Already Available on System)

LG webOS CLI tools aapke system par already installed hain:
- `ares-package` (Package web app into `.ipk`)
- `ares-install` (Install `.ipk` onto TV / Emulator)
- `ares-launch` (Launch app on TV / Emulator)
- `ares-inspect` (Remote Chrome DevTools inspection for TV)
- `ares-server` (Local development HTTP preview server)

---

## 2. Test Locally via Browser / Local Server

App ko browser ya webOS web engine me run karne ke liye:

```powershell
cd c:\xampp_old\htdocs\Digi_Laravel_Prrojects\web_os\first_attempt

# Option A: Run directly using webOS CLI development server
& 'C:\Program Files\nodejs\ares-server.cmd' -o .

# Option B: Open index.html directly in any browser
Start-Process "chrome.exe" "index.html"
```

---

## 3. Package into `.ipk` Bundle

App ko package karne ke liye:

```powershell
cd c:\xampp_old\htdocs\Digi_Laravel_Prrojects\web_os\first_attempt
& 'C:\Program Files\nodejs\ares-package.cmd' .
```
Output:
`com.pax.hospitality.tv_1.0.0_all.ipk`

---

## 4. Deploy to LG webOS TV Emulator or Real LG Smart TV

### Step 1: Check or Add Target Device

Available target devices list karne ke liye:
```powershell
& 'C:\Program Files\nodejs\ares-device.cmd' -l
```

Agar real LG TV connect karna hai (Developer Mode app TV par enable hona chahiye):
```powershell
# LG TV add karein (Replace TV_IP with your TV's IP address)
& 'C:\Program Files\nodejs\ares-setup-device.cmd' -a "my_lg_tv" -i "192.168.1.50" -p 9922 -u prisoner
```

### Step 2: Install `.ipk` on TV / Emulator

```powershell
& 'C:\Program Files\nodejs\ares-install.cmd' -d "emulator" com.pax.hospitality.tv_1.0.0_all.ipk
# Ya real TV par:
& 'C:\Program Files\nodejs\ares-install.cmd' -d "my_lg_tv" com.pax.hospitality.tv_1.0.0_all.ipk
```

### Step 3: Launch App on TV

```powershell
& 'C:\Program Files\nodejs\ares-launch.cmd' -d "emulator" com.pax.hospitality.tv
# Ya real TV par:
& 'C:\Program Files\nodejs\ares-launch.cmd' -d "my_lg_tv" com.pax.hospitality.tv
```

### Step 4: Live Remote Debugging & Console Logs

TV par chalte hue app ko inspect karne ke liye (Chrome DevTools khul jayega):
```powershell
& 'C:\Program Files\nodejs\ares-inspect.cmd' -d "emulator" -a com.pax.hospitality.tv -o
```

---

## 5. Remote D-Pad & Key Testing Reference

| TV Remote Key | KeyCode | Action in App |
|---|---|---|
| **Arrow UP** | `38` | Navigate focus to element above |
| **Arrow DOWN** | `40` | Navigate focus to element below |
| **Arrow LEFT** | `37` | Navigate focus to left element / card |
| **Arrow RIGHT** | `39` | Navigate focus to right element / card |
| **OK / Center** | `13` | Select / Click active card, channel, or button |
| **BACK** | `461` | Close modal / exit player / return to home |
| **Numeric 0-9** | `48-57` | Direct IPTV channel change & PIN input |
| **Inactivity (2 min)** | — | Automatically triggers Ambient Screensaver |
