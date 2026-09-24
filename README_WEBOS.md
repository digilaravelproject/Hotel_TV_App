# LG webOS TV Guide - PAX TV Hospitality (Flutter)

Yeh guide aapko `Hotel_TV_App` Flutter project ko **Web** aur **LG webOS `.ipk` package** me build aur deploy karne ke instructions deti hai.

---

## 1. Fast 1-Click Build (.ipk Generation)

Aap direct 1-click batch script run kar sakte hain:

### Command Prompt:
```cmd
cd C:\xampp_old\htdocs\Digi_Laravel_Prrojects\Hotel_TV_App
build_webos.bat
```

### PowerShell:
```powershell
cd C:\xampp_old\htdocs\Digi_Laravel_Prrojects\Hotel_TV_App
.\build_webos.ps1
```

Yeh script:
1. `web/appinfo.json` ke version ko **automatically increment (1.0.0 -> 1.0.1 -> 1.0.2)** karta hai.
2. Har build par uniquely versioned package generate karta hai (jaise `com.pax.hospitality.tv_1.0.1_all.ipk`).
3. Always-latest alias `pax_tv.ipk` bhi generate karta hai.

#### Optional Switches:
* Naya code recompile karne ke liye: `.\build_webos.ps1 -Rebuild`
* Custom version set karne ke liye: `.\build_webos.ps1 -SetVersion 1.2.0`
* Bina version change kiye pack karne ke liye: `.\build_webos.ps1 -NoBump`

---

## 2. webOS TV Simulator me Run Karne ka Tareeqa

Agar aap **webOS TV 26 Simulator** use kar rahe hain:

### Option A (Sabse Easy & Direct Folder Load):
1. Simulator me top menu par **File** -> **Open App** (ya `Ctrl + O`) par click karein.
2. Is path ko select karein:
   ```
   C:\xampp_old\htdocs\Digi_Laravel_Prrojects\Hotel_TV_App\webos
   ```
3. App instantly bina kisi black screen ke load ho jayega!

### Option B (.ipk Install):
Naya generated `.ipk` package simulator par drag-and-drop karein:
```
C:\xampp_old\htdocs\Digi_Laravel_Prrojects\Hotel_TV_App\com.pax.hospitality.tv_1.0.0_all.ipk
```


---

## 2. Manual Step-by-Step Commands

Agar aap manually commands run karna chahte hain:

```powershell
# Step 1: Flutter Web build karein
flutter build web --release

# Step 2: ares-package se IPK generate karein
ares-package build/web -o .
```

Output:
`com.pax.hospitality.tv_1.0.0_all.ipk`

---

## 3. Deploy & Run on LG webOS TV / Emulator

### Step 1: Target Device Check Karein
```powershell
ares-device -l
```

### Step 2: Real LG TV Connect Karein (Optional)
Agar physical LG TV par deploy karna ho:
1. LG TV par **Developer Mode** app install karke on karein.
2. PC se TV add karein (replace `192.168.1.50` with your TV's IP):
```powershell
ares-setup-device -a "my_lg_tv" -i "192.168.1.50" -p 9922 -u prisoner
```

### Step 3: Install `.ipk`
```powershell
# Emulator par:
ares-install -d emulator com.pax.hospitality.tv_1.0.0_all.ipk

# Real TV par:
ares-install -d my_lg_tv com.pax.hospitality.tv_1.0.0_all.ipk
```

### Step 4: Launch App
```powershell
# Emulator par:
ares-launch -d emulator com.pax.hospitality.tv

# Real TV par:
ares-launch -d my_lg_tv com.pax.hospitality.tv
```

### Step 5: Live Remote Chrome DevTools Debugging
```powershell
ares-inspect -d emulator -a com.pax.hospitality.tv -o
```

---

## 4. Run & Preview in Local Browser

Web preview test karne ke liye:

```powershell
flutter run -d chrome
```
ya:
```powershell
ares-server -o build/web
```
