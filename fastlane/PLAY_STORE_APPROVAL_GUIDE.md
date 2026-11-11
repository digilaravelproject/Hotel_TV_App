# Google Play Store 100% Approval & Setup Guide — PAX TV Hospitality (Android TV)

Yeh guide **PAX TV Hospitality** Android TV app (`com.paxtv.hospitality`) ko bina kisi rejection aur 100% Google Play Store approval ke liye banayi gayi hai.

---

## 📺 1. Android TV Banner & Quality Guidelines Fix (CRITICAL)

### Google Play Rejection Reason Solved:
> *"Your banner does not fill the entire banner space. Apps should include the banner in the xhdpi (320 dpi) drawables folder with a size of (320px x 180px) and the icon with a size of (512px x 512px)."*

### Changes Implemented in APK & Store Assets:
1. **APK Drawable Banner (`res/drawable-xhdpi/banner.png`)**:
   - Exact size: **`320px × 180px`** (Aspect ratio 16:9).
   - **Full-Bleed Background**: Background pure 320x180 canvas ko 100% fill karta hai. Zero transparent borders, zero pillarbox/letterbox.
   - All density folders updated:
     - `drawable/banner.png`: `320px × 180px`
     - `drawable-mdpi/banner.png`: `160px × 90px`
     - `drawable-hdpi/banner.png`: `240px × 135px`
     - `drawable-xhdpi/banner.png`: **`320px × 180px`** (Google requirement)
     - `drawable-xxhdpi/banner.png`: `480px × 270px`
     - `drawable-xxxhdpi/banner.png`: `640px × 360px`
2. **App Icon (512x512 px)**:
   - High-res 512x512 32-bit PNG icon generated at `fastlane/metadata/android/en-US/images/icon.png` aur `play_store_512x512.png`.
3. **Play Store TV Banner (1280x720 px)**:
   - Official store listing TV banner placed at `fastlane/metadata/android/en-US/images/tvBanner.png` aur `play_store_tv_banner_1280x720.png`.
4. **Official TV Screenshots (1920x1080 px, 16:9)**:
   - 7 HD 1080p screenshots added in `fastlane/metadata/android/en-US/images/tvScreenshots/`.

---

## 📁 2. Fastlane Folder Structure

```
fastlane/
├── Appfile                                      # Package configuration (com.paxtv.hospitality)
├── Fastfile                                     # Automated build & supply deploy lanes
├── PLAY_STORE_APPROVAL_GUIDE.md                 # Complete Play Console approval guide
└── metadata/
    └── android/
        └── en-US/
            ├── title.txt                        # "PAX TV Hospitality" (19 chars)
            ├── short_description.txt            # Store listing pitch (78 chars)
            ├── full_description.txt             # Comprehensive hotel TV description
            └── images/
                ├── icon.png                     # Exact 512x512 App Icon
                ├── featureGraphic.png           # Exact 1024x500 Feature Graphic
                ├── tvBanner.png                 # Exact 1280x720 Android TV Store Banner
                └── tvScreenshots/               # Exact 1920x1080 (16:9) Android TV Screenshots
                    ├── 1.png (1_our_hospitality_solution.png)
                    ├── 2.png (2_live_tv_entertainment.png)
                    ├── 3.png (3_hotel_information_service.png)
                    ├── 4.png (4_luxury_hotel_room.png)
                    ├── 5.png (5_about_us_guest_services.png)
                    ├── 6.png (6_pair_tv_device.png)
                    └── 7.png (7_register_property.png)
```

---

## 📋 3. Google Play Console Form-by-Form Answers

Jab aap [Google Play Console](https://play.google.com/console) par app create karenge ya App Content fill karenge, to exact yehi options select karein:

### A. App Details
- **App Name**: `PAX TV Hospitality` *(fastlane/metadata/android/en-US/title.txt)*
- **Short Description**: `Smart hotel TV launcher with cloud CMS, guest services, Live TV & streaming.` *(short_description.txt)*
- **Full Description**: *(fastlane/metadata/android/en-US/full_description.txt se copy karein)*

### B. App Category & Store Listing
- **App or Game**: **App**
- **Category**: **`Entertainment`** *(ya `Hospitality` / `Business`)*
- **Tags**: `Hospitality`, `TV Launcher`, `Streaming`, `Smart TV`, `Hotel Services`
- **Store Contact Email**: `support@paxtvlauncher.com`
- **Website URL**: `https://paxtvlauncher.com/`

### C. App Access (Google Reviewer Demo Instructions) ⚠️ CRITICAL
Google TV app testers app launch karke pairing screen dekhte hain. Google reviewers ke liye demo mode instructions provide karein taaki 100% approval mile:
- Play Console menu mein **"App Content" -> "App Access"** open karein.
- Select: **"All or some functionality is restricted"**
- Click **"Add new instruction"**:
  - **Name / Title**: `Hotel TV Demo Reviewer Access`
  - **Username / Login**: `Try Free Demo` (No credentials required)
  - **Instructions**: *"On the startup screen, navigate with the remote D-Pad to the 3rd tab labeled 'Try Free Demo' and press Enter / Select. The app instantly activates demo mode and loads the full in-room hotel guest launcher, TV channels, and interactive services without requiring active hardware licensing."*

### D. Android TV Specific Declaration
- **Target Form Factors**: Check **`Android TV`**.
- **Leanback Launcher**: Verified (`android:banner="@drawable/banner"`, `android:icon="@mipmap/ic_launcher"`, and `LEANBACK_LAUNCHER` intent declared in `AndroidManifest.xml`).
- **DPad Navigation**: App fully navigable via standard TV remote control (Arrow Keys + Enter + Back).

### E. Financial Features Declaration
- Sawal: *"Does your app provide any financial features?"*
- Select: **`No, my app does not provide any financial features`**
- *(Yeh in-room hotel display software hai, koi banking ya personal finance operations nahi karta)*.

### F. Content Rating Questionnaire
- Category: **Utility, Productivity, Communication or Other** (ya Entertainment)
- Violence / Blood: **No**
- Sexuality / Nudity: **No**
- Offensive Language: **No**
- Controlled Substance: **No**
- Gambling: **No**
- Physical Location Sharing with other users: **No**
- Digital Purchases: **No** (Direct in-app billing nahi hai; enterprise B2B licensing web portal se hoti hai).
- 👉 **Result**: Rating **Everyone (3+)** / **PEGI 3** aayegi (100% safe).

### G. Target Audience & Content
- Target age: **18 and over**
- Appeal to children: **No**

### H. Data Safety Section
- **Does your app collect or share user data?**: **Yes**
- **Data Encrypted in Transit?**: **Yes** (All API and cloud traffic uses HTTPS/TLS).
- **Can users request data deletion?**: **Yes** (via email support).
- **Data Types**:
  - *Device or other IDs*: TV Device pairing identifier (for cloud screen linking).
  - Data is NOT sold to 3rd party brokers and is solely used for app functionality.

### I. Privacy Policy
- **Privacy Policy URL**: `https://paxtvlauncher.com/privacy-policy`

---

## 🚀 4. Fastlane Deployment Commands

Fastlane CLI se build aur deploy karne ke liye:

### A. Metadata & Screenshots Upload:
```bash
bundle exec fastlane android upload_metadata
```

### B. Build and Upload Release Bundle to Internal Testing:
```bash
bundle exec fastlane android deploy_internal
```

### C. Build and Upload Release Bundle to Production:
```bash
bundle exec fastlane android deploy_production
```

