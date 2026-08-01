# Remaining Action Steps: Android TV Launcher & Headwind MDM Deployment

All code-level modifications in Flutter (Dart, Kotlin, and Android XML configuration) are **100% complete and fully implemented**. 

Because we used standard Android `RestrictionsManager` APIs, the code is fully compatible with **Headwind MDM**'s managed configuration system out of the box.

To successfully deploy and test this on your 500+ TVs using your **Hostinger VPS**, you only need to perform the following operational steps.

---

## Step 1: Build the Release APK
You need to compile the production-ready APK file.
1. Open your terminal in the root of the project:
   ```bash
   flutter build apk --release
   ```
2. Once complete, your output file will be saved at:
   `build/app/outputs/flutter-apk/app-release.apk`

---

## Step 2: Install Headwind MDM on Hostinger VPS
Follow the installation guide in [doc/tv_lockdown_mdm_guide.md](file:///Users/firozmohammad/DigiEmperor/Hotel/doc/tv_lockdown_mdm_guide.md) to set up the MDM server on your Hostinger Ubuntu VPS:
1. Reinstall VPS OS to **Ubuntu 22.04**.
2. Point your domain (DNS A Record) to the VPS IP.
3. SSH into the server and run:
   ```bash
   wget https://h-mdm.com/files/hmdm-install.sh
   chmod +x hmdm-install.sh
   sudo ./hmdm-install.sh
   ```
4. Note down the Admin Panel URL (e.g. `https://mdm.yourdomain.com`) and password displayed at the end of the installation.

---

## Step 3: Configure Kiosk & Policies in MDM Web Panel
Log into your self-hosted Headwind MDM panel using the credentials from Step 2:

1. **Upload the Launcher APK:**
   * Go to **Applications** -> Click **Add**.
   * Upload your `app-release.apk` file.
   * Set the Package Name to `com.digiemperor.hotel`.
2. **Create Configuration:**
   * Go to **Configurations** -> Click **Add** -> Name it `Hotel_TV_Default`.
   * Under the applications list, find `PAX TV Hospitality` (your app) and set the **Action** to `Install and Run`.
   * Set **Kiosk Mode** to `ON` and check **Set as Default Launcher**.
3. **Configure Auto-Login parameters (Managed Configurations):**
   * Select your app configuration -> Click **Preferences / Managed Configurations**.
   * Enter the values for EMM automatic login:
     * **license_key:** Enter your hospitality licensing key (e.g., `P1SU-FOO9-F4T7-YJZF`).
     * **room_no:** Enter the room number (e.g., `101`).
4. **Lockdown Settings:**
   * Go to **System Settings** in the configuration tabs:
     * Disable **Factory Reset**.
     * Disable **USB Debugging**.
     * Hide **Status Bars / Navigation**.

---

## Step 4: Provision the TVs (On-Site Setup Procedure)

This is the step-by-step procedure for the technician setting up each TV in the hotel rooms.

### 4.1 Prerequisites
* The TV must be brand new (first boot) OR **Factory Reset** to the welcome screen. (You cannot provision a TV that has already gone through the normal Android setup wizard).
* A cheap **USB Mouse** (wired or wireless) is required to click on the non-touchscreen TV.
* The technician must have the **Provisioning QR Code** (or EMM text token) printed or open on their phone from the MDM console.

### 4.2 Step-by-Step Execution
1. **Connect the USB Mouse:** Plug the USB mouse receiver/cable into any available USB port on the back/side of the Android TV.
2. **Boot the TV:** Turn on the TV. Wait for the first Android TV setup screen (usually the **"Welcome"** or **"Select Language"** screen).
3. **Trigger the Hidden Setup:**
   * Using the connected USB mouse, click on the **Welcome Text** (or the white space on the screen) **6 times rapidly**.
   * *If the TV brand does not support mouse clicks on this screen:* Press the **Back Button** on the TV remote control 6 times repeatedly.
   * A progress spinner will appear, and the TV will display: **"Scan QR code to set up managed device"**.
4. **Connect to WiFi:**
   * The TV will prompt you to select a WiFi network.
   * Connect to the hotel's technician WiFi (or any local stable internet connection).
5. **Scan the QR Code:**
   * If the TV has a built-in camera, point the TV at the QR code on your phone/printout.
   * **If the TV does not have a camera (Standard Case):**
     * Connect a temporary USB webcam to the TV to scan the QR code.
     * **OR (Simplest Method):** Click on the **"Input manually"** or **"Use Code"** option on the screen. Type in your MDM server enrollment token (displayed under your configuration in the Headwind MDM console, e.g., `mdm.yourdomain.com/enroll`).
6. **Automatic Installation & Handover:**
   * The TV will download the Headwind MDM client, set it as the **Device Owner** (System Administrator), and lock down.
   * The client will download your **PAX TV Hospitality** app from your VPS, auto-login using the EMM room variables, and launch your hotel dashboard.
   * Disconnect the USB mouse/webcam. The TV is now ready for the guest!
