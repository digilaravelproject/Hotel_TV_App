# Production Guide: Enterprise Android TV Launcher & Kiosk Lockdown (500+ TVs)
## Customized for Hostinger VPS & Headwind MDM Setup

This guide provides a comprehensive, production-ready, step-by-step plan to host, configure, deploy, and manage your custom Android TV Launcher on 500+ TVs using **Headwind MDM** (Free, Open-Source Community Edition) on a **Hostinger VPS**.

---

## 1. Budget & Cost Breakdown

| Item | Provider | Cost | Description |
| :--- | :--- | :--- | :--- |
| **MDM Server Software** | Headwind MDM (Open Source) | **$0 (Free)** | Fully featured MDM panel. No license fee per TV. |
| **VPS Server Hosting** | Hostinger VPS (KVM 2 or KVM 4) | **~$6 - $12 / month** | KVM 2 (2 GB RAM / 1 vCPU / 50 GB NVMe) is recommended. |
| **SSL Domain & Certificate** | Let's Encrypt (Automated) | **$0 (Free)** | Necessary for secure TV-server communications (HTTPS). |

---

## 2. Server Setup (Hostinger VPS Backend)

We will configure your Hostinger VPS, set up the operating system, link your domain, and install the MDM server.

### Step 2.1: Setup Ubuntu OS on Hostinger hPanel
1. Go to the Hostinger website: [Hostinger Portal](https://www.hostinger.com) (or [Hostinger India Portal](https://www.hostinger.in) if in India).
2. Log in to your Hostinger Control Panel: [Hostinger hPanel Dashboard](https://hpanel.hostinger.com).
3. In hPanel, navigate to the **VPS** tab in the main header navigation menu.
4. Select your active VPS server from the list.
5. In the left sidebar under the **Settings** menu, click on **OS Reinstallation** (or select the **Operating System** tab).
6. Select **Ubuntu 22.04 64bit** as your new OS and click the **Reinstall OS** button.
7. Set your new `root` password when prompted and write it down securely.
8. Once the installation completes (takes ~2 minutes), copy the **VPS IP Address** shown in the General Information section (e.g. `185.115.124.50`).

### Step 2.2: Add DNS A Record in Hostinger Domains
If your domain is registered/hosted with Hostinger:
1. Open the [Hostinger hPanel Domain Management](https://hpanel.hostinger.com) portal.
2. Go to **Domains** in the header menu and select your active domain.
3. Click on **DNS / Nameservers** in the left sidebar menu to open the DNS zone editor.
4. Add a new **A Record** with the following details:
   * **Type:** `A`
   * **Name (Host):** `mdm` (This creates the subdomain `mdm.yourdomain.com`)
   * **Points to (IP):** Enter your Hostinger VPS IP address (e.g., `185.115.124.50`)
   * **TTL:** `3600` (Default)
5. Click **Add Record**.

### Step 2.3: Connect to Hostinger VPS
You can connect to your Hostinger VPS using either:
* **Option A: Web Browser Terminal:** In Hostinger VPS panel, click on the **Browser Terminal** button at the top right. This opens a terminal directly in your browser without requiring SSH setup.
* **Option B: Local Terminal SSH:** Open your Mac terminal and run:
  ```bash
  ssh root@your_hostinger_vps_ip
  ```
  *(Enter the root password you created in Step 2.1).*

### Step 2.4: Install and Setup Headwind MDM
Headwind MDM is a self-hosted open-source software. The installer script automates the installation of Tomcat, PostgreSQL, and Let's Encrypt SSL certificates.
* **Official Website:** [Headwind MDM Official Site](https://h-mdm.com)
* **Installation Documentation:** [Headwind MDM Ubuntu Install Docs](https://h-mdm.com/install-headwind-mdm-on-ubuntu-linux/)

Once logged into your Hostinger Ubuntu VPS terminal, run the following commands sequentially to perform the complete setup:

1. **Update system packages:**
   Ensure all OS dependencies are up to date.
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **Download the installer script from Headwind MDM's official repository:**
   ```bash
   wget https://h-mdm.com/files/hmdm-install.sh
   chmod +x hmdm-install.sh
   ```

3. **Run the installation script:**
   ```bash
   sudo ./hmdm-install.sh
   ```

4. **Installer Process & Interactive Prompts:**
   The script will install **OpenJDK (Java)**, **Tomcat (Web Server)**, **PostgreSQL (Database)**, and **Certbot (SSL)**. During installation, it will prompt you for the following inputs:
   * **Language:** Type `en` and press Enter.
   * **Protocol:** Type `https` and press Enter. *(Crucial: Android devices will reject connections from non-secure HTTP MDM servers)*.
   * **Domain Name / IP:** Type your subdomain registered in Step 2.2 (e.g., `mdm.yourdomain.com`).
   * **Install PostgreSQL?** Type `y` (or press Enter). The script will automatically generate the database, credentials, and setup tables.
   * **Database parameters:** Press Enter to accept all default database settings automatically.
   * **Install Tomcat?** Type `y` (or press Enter). This installs Tomcat 9 or Tomcat 10 which runs the MDM Java Web Application (`hmdm.war`).
   * **Configure Let's Encrypt SSL?** Type `y`. Enter your email address when prompted. The installer will automatically run Certbot to fetch and configure the SSL certificates for your domain.

5. **Get Credentials & Access Panel:**
   Once the script completes, it will display the credentials:
   * **Admin Web Panel URL:** `https://mdm.yourdomain.com` (or `https://your_vps_ip:8443` if IP is used)
   * **Default Username:** `admin`
   * **Default Password:** `[Randomly_Generated_Password]` (Printed in the console logs at the end of installation. Make sure to copy this password).

---

## 3. Flutter Application Configurations (Frontend)

To run the application as a permanent Kiosk Home Launcher and prevent users from closing it, we implement four native configurations.

### 3.1: Create Policy Receiver XML
We define a metadata policy for Device Administration permissions.

Create [device_admin_receiver.xml](file:///Users/firozmohammad/DigiEmperor/Hotel/android/app/src/main/res/xml/device_admin_receiver.xml):
```xml
<?xml version="1.0" encoding="utf-8"?>
<device-admin xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-policies>
        <limit-password />
        <watch-login />
        <reset-password />
        <force-lock />
        <wipe-data />
        <expire-password />
        <encrypted-storage />
        <disable-keyguard-features />
    </uses-policies>
</device-admin>
```

### 3.2: Create DeviceAdminReceiver Class
Create the Kotlin file [MyDeviceAdminReceiver.kt](file:///Users/firozmohammad/DigiEmperor/Hotel/android/app/src/main/kotlin/com/digiemperor/hotel/MyDeviceAdminReceiver.kt):
```kotlin
package com.digiemperor.hotel

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.widget.Toast

class MyDeviceAdminReceiver : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Toast.makeText(context, "Device Policy Enabled", Toast.LENGTH_SHORT).show()
    }
}
```

### 3.3: Register categories in AndroidManifest.xml
Modify [AndroidManifest.xml](file:///Users/firozmohammad/DigiEmperor/Hotel/android/app/src/main/AndroidManifest.xml) to declare that this app is a Custom Home Launcher and registers the admin receiver.

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Existing permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-feature android:name="android.software.leanback" android:required="false" />
    <uses-feature android:name="android.hardware.touchscreen" android:required="false" />
    
    <application
        android:label="PAX TV Hospitality"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="true">
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="stateHidden|adjustResize">
            
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme" />
              
            <!-- Register as HOME Launcher -->
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
                <category android:name="android.intent.category.LEANBACK_LAUNCHER"/>
                <category android:name="android.intent.category.HOME"/>
                <category android:name="android.intent.category.DEFAULT"/>
            </intent-filter>
        </activity>

        <meta-data
            android:name="io.flutter.embedding.android.EnableImpeller"
            android:value="false" />
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />

        <!-- Register the Device Admin Receiver -->
        <receiver
            android:name=".MyDeviceAdminReceiver"
            android:label="PAX TV Admin"
            android:permission="android.permission.BIND_DEVICE_ADMIN"
            android:exported="true">
            <meta-data
                android:name="android.app.device_admin"
                android:resource="@xml/device_admin_receiver" />
            <intent-filter>
                <action android:name="android.app.action.DEVICE_ADMIN_ENABLED" />
            </intent-filter>
        </receiver>
    </application>
</manifest>
```

### 3.4: Implement Kiosk Locking in MainActivity.kt
Modify [MainActivity.kt](file:///Users/firozmohammad/DigiEmperor/Hotel/android/app/src/main/kotlin/com/digiemperor/hotel/MainActivity.kt) to lock down the device programmatic functions if the app is configured as the Device Owner.

```kotlin
package com.digiemperor.hotel

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val DEVICE_INFO_CHANNEL = "com.digiemperor.hotel/device_info"
    private val TV_CONTROL_CHANNEL = "com.digiemperor.hotel/tv_control"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setupDeviceOwnerLock()
    }

    private fun setupDeviceOwnerLock() {
        try {
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val adminName = ComponentName(this, MyDeviceAdminReceiver::class.java)

            if (dpm.isDeviceOwnerApp(packageName)) {
                // 1. Permanently bind the Home intent to this activity (Bypasses home app dialogs)
                val intentFilter = IntentFilter(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    addCategory(Intent.CATEGORY_DEFAULT)
                }
                val activityName = ComponentName(this, MainActivity::class.java)
                dpm.addPersistentPreferredActivity(adminName, intentFilter, activityName)

                // 2. Lock app list packages and restrict status bars
                dpm.setLockTaskPackages(adminName, arrayOf(packageName))
                startLockTask() // Launches full Android TV Kiosk mode
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    // Existing native channels and remote key code logic...
}
```

---

## 4. Configuring MDM Web Console Policies (Headwind MDM)

Once your server is running, configure the policies for zero-touch deployment:

1. **Upload App APK:**
   * In the MDM Web Panel, click **Applications** -> **Add**.
   * Upload the `app-release.apk` file generated from `flutter build apk --release`.
   * Set Package Name to `com.digiemperor.hotel`.
2. **Create Launcher Configuration:**
   * Go to **Configurations** -> **Add**.
   * Set configuration name to `Hotel_TV_Default`.
   * Add the uploaded application (`com.digiemperor.hotel`) to the configuration applications list.
   * Under **Application Settings**:
     * Set **Action** to `Install and Run`.
     * Toggle **Run in Kiosk mode** to `ON`.
     * Check **Set as Default Launcher**.
3. **Configure Lockdown Policies:**
   * In the configuration tabs, go to **System Settings**:
     * Set **Factory Reset** to `Disabled` (prevents users/guests from resetting the TV to default).
     * Set **Safe Mode Boot** to `Disabled`.
     * Set **System Bars (Status Bar / Navigation)** to `Hidden`.
     * Set **USB Debugging** to `Disabled`.

---

## 5. Provisioning & Deployment Flow (500+ TVs)

To deploy on 500 TVs without using command lines or ADB:

### Step 5.1: Generate QR Code Profile
1. On the MDM Web Panel, click **Devices** -> **Add**.
2. Input a temporary name (e.g. `Room_101`) and select `Hotel_TV_Default` configuration.
3. This creates a QR code containing provisioning instructions.

### Step 5.2: Technician On-Site Provisioning
1. Turn on a brand new or factory-reset Android TV.
2. On the **first welcome/language selection screen**, tap the Welcome Text (or press **Fast-Forward/Rewind** on the TV remote) **6 times**.
3. The TV will show a message: *"Scan QR code to set up managed device"*.
4. Connect to local WiFi if prompted, and use the TV camera (or connect a USB webcam to the TV) to scan the QR code from the MDM Web Panel.
5. The TV will automatically:
   * Set Headwind MDM as the Device Owner.
   * Connect to your Hostinger backend (`https://mdm.yourdomain.com`).
   * Download and install your custom launcher app (`com.digiemperor.hotel`).
   * Permanently lock itself to the launcher app in kiosk mode.
