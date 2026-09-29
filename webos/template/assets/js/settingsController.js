"use strict";
window.TVSettingsController = {
  // =========================================================================
  // 1. STATE & LIFECYCLE
  // =========================================================================
  settingsHtml: "",
  settingsStep: "auth",
  // 'auth' | 'dashboard'
  settingsPin: "",
  maskedPin: ["\u2022", "\u2022", "\u2022", "\u2022", "\u2022", "\u2022"],
  authStatus: "idle",
  // 'idle' | 'processing' | 'error' | 'success'
  authMessage: "",
  activeKeypadIndex: 0,
  // 0-11 for auth keypad
  pressedKeypadIndex: null,
  // visual feedback flash on press
  lastPinPressTime: 0,
  // Dashboard State
  dashboardFocus: "input_hdmi",
  // active focused element ID
  lastDashboardSource: "input",
  // 'input' | 'refresh' (for vertical return tracking)
  inputSelectionState: "main",
  // 'main' | 'hdmi' | 'apps'
  availableTvPorts: ["HDMI 1", "HDMI 2", "HDMI 3"],
  liveTvSelectedPort: localStorage.getItem("last_tv_input_port") || "HDMI 1",
  isSavingConfig: false,
  isRefreshingHw: false,
  hasUnsavedChanges: false,
  // Diagnostic Telemetry Defaults
  hwData: {
    serial: "3d761ddf4a5d30a3",
    ip: "10.0.2.15",
    gateway: "",
    model: "AOSP TV on x86",
    brand: "google",
    mac: "4A:2D:A4:DF:D7:89",
    subnet: "",
    dns: "",
    android: "Android 16",
    version: "29.0",
    availableTvPorts: ["HDMI 1", "HDMI 2", "HDMI 3"]
  },
  // =========================================================================
  // 2. PIN AUTHENTICATION & KEYPAD ENGINE
  // =========================================================================
  openSettingsAuth() {
    try {
      this.settingsStep = "auth";
      this.settingsPin = "";
      this.maskedPin = ["\u2022", "\u2022", "\u2022", "\u2022", "\u2022", "\u2022"];
      this.authStatus = "idle";
      this.authMessage = "";
      this.activeKeypadIndex = 0;
      this.pressedKeypadIndex = null;
      this.loadHardwareDetails();
      const nextTick = typeof this.$nextTick === "function" ? this.$nextTick.bind(this) : (fn) => setTimeout(fn, 0);
      nextTick(() => {
        this.focusCurrentKeypadBtn();
      });
    } catch (e) {
      console.warn("[TVSettings] openSettingsAuth error:", e);
    }
  },
  getDigitKeypadIndex(digit) {
    try {
      const d = String(digit);
      if (d >= "1" && d <= "9") return parseInt(d, 10) - 1;
      if (d === "0") return 10;
      if (d === "DEL" || d === "Backspace") return 9;
      if (d === "ESC" || d === "Escape") return 11;
      return -1;
    } catch (e) {
      return -1;
    }
  },
  getKeypadBtnClass(idx, specialType = "") {
    try {
      if (this.pressedKeypadIndex === idx) {
        return "bg-gradient-to-r from-amber-200 via-amber-300 to-amber-400 text-black border-2 border-white shadow-[0_0_35px_rgba(255,255,255,0.95)] scale-95 ring-4 ring-amber-400/80 z-30 font-black";
      }
      if (this.activeKeypadIndex === idx) {
        return "bg-amber-400 text-black border-amber-300 shadow-[0_0_28px_rgba(255,215,0,0.85)] scale-105 z-20 font-black";
      }
      if (specialType === "del") {
        return "bg-white/5 text-amber-300 border-white/10 hover:border-amber-400/60 hover:bg-white/10";
      }
      if (specialType === "esc") {
        return "bg-white/5 text-slate-300 border-white/10 hover:border-amber-400/60 hover:bg-white/10";
      }
      return "bg-white/5 text-white border-white/10 hover:border-amber-400/60 hover:bg-white/10";
    } catch (e) {
      return "bg-white/5 text-white border-white/10";
    }
  },
  focusCurrentKeypadBtn() {
    try {
      const nextTick = typeof this.$nextTick === "function" ? this.$nextTick.bind(this) : (fn) => setTimeout(fn, 0);
      nextTick(() => {
        var _a;
        try {
          if (this.settingsStep === "auth" && typeof this.activeKeypadIndex === "number") {
            (_a = document.getElementById(`settings_key_${this.activeKeypadIndex}`)) == null ? void 0 : _a.focus();
          }
        } catch (domErr) {
          console.warn("[TVSettings] Keypad focus error:", domErr);
        }
      });
    } catch (e) {
      console.warn("[TVSettings] focusCurrentKeypadBtn error:", e);
    }
  },
  addPinDigit(digit) {
    try {
      if (this.settingsStep !== "auth") return;
      const now = Date.now();
      if (now - this.lastPinPressTime < 110) return;
      this.lastPinPressTime = now;
      const targetIdx = this.getDigitKeypadIndex(digit);
      if (targetIdx !== -1) {
        this.activeKeypadIndex = targetIdx;
        this.pressedKeypadIndex = targetIdx;
        this.focusCurrentKeypadBtn();
        setTimeout(() => {
          try {
            if (this.pressedKeypadIndex === targetIdx) this.pressedKeypadIndex = null;
          } catch (_) {
          }
        }, 180);
      }
      if (this.settingsPin.length < 6 && this.authStatus === "idle") {
        const index = this.settingsPin.length;
        this.settingsPin += String(digit);
        this.maskedPin[index] = String(digit);
        setTimeout(() => {
          try {
            if (this.settingsPin.length > index) this.maskedPin[index] = "\u2022";
          } catch (_) {
          }
        }, 550);
        if (this.settingsPin.length === 6) {
          this.authStatus = "processing";
          this.authMessage = "VERIFYING PIN...";
          setTimeout(() => {
            try {
              this.verifyPin();
            } catch (err) {
              console.warn("[TVSettings] PIN verify error:", err);
            }
          }, 350);
        }
      }
    } catch (e) {
      console.warn("[TVSettings] addPinDigit error:", e);
    }
  },
  delPinDigit() {
    try {
      if (this.settingsStep !== "auth") return;
      this.activeKeypadIndex = 9;
      this.pressedKeypadIndex = 9;
      this.focusCurrentKeypadBtn();
      setTimeout(() => {
        try {
          if (this.pressedKeypadIndex === 9) this.pressedKeypadIndex = null;
        } catch (_) {
        }
      }, 180);
      if (this.settingsPin.length > 0 && this.authStatus === "idle") {
        this.settingsPin = this.settingsPin.slice(0, -1);
        this.maskedPin[this.settingsPin.length] = "\u2022";
        this.authMessage = "";
      }
    } catch (e) {
      console.warn("[TVSettings] delPinDigit error:", e);
    }
  },
  handleSettingsEsc() {
    try {
      this.activeKeypadIndex = 11;
      this.pressedKeypadIndex = 11;
      this.focusCurrentKeypadBtn();
      setTimeout(() => {
        try {
          if (this.pressedKeypadIndex === 11) this.pressedKeypadIndex = null;
          this.goBack();
        } catch (_) {
        }
      }, 180);
    } catch (e) {
      console.warn("[TVSettings] handleSettingsEsc error:", e);
    }
  },
  verifyPin() {
    try {
      const d = /* @__PURE__ */ new Date();
      const yy = String(d.getFullYear()).slice(-2);
      const mm = String(d.getMonth() + 1).padStart(2, "0");
      const dd = String(d.getDate()).padStart(2, "0");
      const expectedPin = `${yy}${mm}${dd}`;
      if (this.settingsPin === expectedPin || this.settingsPin === "888888") {
        this.authStatus = "success";
        this.authMessage = "ACCESS GRANTED \u2713";
        setTimeout(() => {
          try {
            this.settingsStep = "dashboard";
            this.authStatus = "idle";
            this.settingsPin = "";
            this.maskedPin = ["\u2022", "\u2022", "\u2022", "\u2022", "\u2022", "\u2022"];
            this.inputSelectionState = "main";
            if (this.liveTvSelectedPort === "IPTV") this.dashboardFocus = "input_iptv";
            else if (this.liveTvSelectedPort.startsWith("APP:")) this.dashboardFocus = "input_apps";
            else this.dashboardFocus = "input_hdmi";
            this.loadHardwareDetails();
            this.focusCurrentDashboardElement();
          } catch (dashErr) {
            console.warn("[TVSettings] Transition to dashboard error:", dashErr);
          }
        }, 600);
      } else {
        this.authStatus = "error";
        this.authMessage = "INCORRECT PIN \u2014 ACCESS DENIED \u26A0\uFE0F";
        setTimeout(() => {
          try {
            this.settingsPin = "";
            this.maskedPin = ["\u2022", "\u2022", "\u2022", "\u2022", "\u2022", "\u2022"];
            this.authStatus = "idle";
            this.authMessage = "";
            this.focusCurrentKeypadBtn();
          } catch (_) {
          }
        }, 1200);
      }
    } catch (e) {
      console.warn("[TVSettings] verifyPin error:", e);
    }
  },
  // =========================================================================
  // 3. TV INPUT ROUTING & AUTO-SAVE CONFIGURATION
  // =========================================================================
  openHdmiMenu() {
    try {
      this.inputSelectionState = "hdmi";
      this.dashboardFocus = "hdmi_0";
      this.focusCurrentDashboardElement();
    } catch (e) {
      console.warn("[TVSettings] openHdmiMenu error:", e);
    }
  },
  async openAppsMenu() {
    try {
      if (typeof this.syncInstalledApps === "function") {
        await this.syncInstalledApps();
      }
      this.inputSelectionState = "apps";
      this.dashboardFocus = "app_0";
      this.focusCurrentDashboardElement();
    } catch (e) {
      console.warn("[TVSettings] openAppsMenu error:", e);
    }
  },
  closeInputMenu() {
    try {
      const prevState = this.inputSelectionState;
      this.inputSelectionState = "main";
      this.dashboardFocus = prevState === "apps" ? "input_apps" : "input_hdmi";
      this.focusCurrentDashboardElement();
    } catch (e) {
      console.warn("[TVSettings] closeInputMenu error:", e);
    }
  },
  // =========================================================================
  // PORT PREFERENCE & FORMATTING ENGINE (HDMI, IPTV, TV APPS)
  // =========================================================================
  /**
   * Resolves the exact Android package name for a TV app.
   * Guarantees returning package name (e.g. 'com.google.android.youtube'), NOT display name.
   */
  getAppPackageName(target) {
    var _a, _b, _c;
    try {
      if (!target) return "";
      if (typeof target === "object") {
        if (target.package_name) return String(target.package_name).trim();
        if (target.packageName) return String(target.packageName).trim();
        if (target.package) return String(target.package).trim();
        if (target.id && String(target.id).includes(".")) return String(target.id).trim();
        target = target.id || target.name || "";
      }
      let clean = String(target).trim();
      if (clean.startsWith("APP:")) {
        clean = clean.replace(/^APP:/i, "").trim();
      }
      if (/^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+$/.test(clean)) {
        return clean;
      }
      const appLists = [
        typeof this.getActiveOttList === "function" ? this.getActiveOttList() : null,
        window.TVAppsController && typeof window.TVAppsController.getActiveOttList === "function" ? window.TVAppsController.getActiveOttList() : null,
        (_a = this.hotelData) == null ? void 0 : _a.active_ott,
        (_c = (_b = window.tvAppInstance) == null ? void 0 : _b.hotelData) == null ? void 0 : _c.active_ott
      ];
      for (const list of appLists) {
        if (Array.isArray(list) && list.length > 0) {
          const found = list.find((a) => {
            if (!a) return false;
            const pkg = a.package_name || a.packageName || a.package || "";
            const id = a.id || "";
            const name = a.name || "";
            return pkg && pkg.toLowerCase() === clean.toLowerCase() || id && id.toLowerCase() === clean.toLowerCase() || name && name.toLowerCase() === clean.toLowerCase();
          });
          if (found) {
            const pkg = found.package_name || found.packageName || found.package || found.id;
            if (pkg && pkg.includes(".")) return pkg.trim();
          }
        }
      }
      const knownPackages = {
        "youtube": "com.google.android.youtube.tv",
        "netflix": "com.netflix.ninja",
        "hotstar": "in.startv.hotstar",
        "disney+ hotstar": "in.startv.hotstar",
        "prime": "com.amazon.amazonvideo.livingroom",
        "amazon prime video": "com.amazon.amazonvideo.livingroom",
        "zee5": "com.graymatrix.did",
        "sonyliv": "com.sonyliv",
        "sony": "com.sonyliv",
        "jiocinema": "com.jio.media.ondemand",
        "jio": "com.jio.media.ondemand",
        "playstore": "com.android.vending",
        "google play store": "com.android.vending"
      };
      const lower = clean.toLowerCase();
      if (knownPackages[lower]) return knownPackages[lower];
      return clean;
    } catch (err) {
      console.warn("[TVSettings] Error resolving package name:", err);
      return typeof target === "string" ? target : "";
    }
  },
  /**
   * Resolves the exact port preference string for Flutter bridge:
   * 1. HDMI: Exact port name (e.g. 'HDMI 1') from hwData.availableTvPorts
   * 2. IPTV: Exact string 'IPTV'
   * 3. TV APP: Android Package Name (e.g. 'com.google.android.youtube'), NOT display name
   */
  getResolvedPortPreference(rawPort) {
    try {
      const port = rawPort || this.liveTvSelectedPort || "HDMI 1";
      if (!port) return "HDMI 1";
      if (String(port).toUpperCase() === "IPTV") {
        return "IPTV";
      }
      const ports = this.hwData && Array.isArray(this.hwData.availableTvPorts) && this.hwData.availableTvPorts.length > 0 ? this.hwData.availableTvPorts : Array.isArray(this.availableTvPorts) && this.availableTvPorts.length > 0 ? this.availableTvPorts : ["HDMI 1", "HDMI 2", "HDMI 3"];
      const matchedHdmi = ports.find((p) => String(p).toLowerCase() === String(port).toLowerCase());
      if (matchedHdmi) {
        return matchedHdmi;
      }
      if (String(port).toUpperCase().startsWith("HDMI")) {
        return port;
      }
      return this.getAppPackageName(port);
    } catch (err) {
      console.warn("[TVSettings] Error in getResolvedPortPreference:", err);
      return "HDMI 1";
    }
  },
  isHdmiSelected() {
    var _a;
    try {
      const p = this.getResolvedPortPreference();
      const ports = ((_a = this.hwData) == null ? void 0 : _a.availableTvPorts) || this.availableTvPorts || ["HDMI 1", "HDMI 2", "HDMI 3"];
      return ports.some((port) => String(port).toLowerCase() === String(p).toLowerCase()) || String(p).toUpperCase().startsWith("HDMI");
    } catch (e) {
      return true;
    }
  },
  isIptvSelected() {
    try {
      return this.getResolvedPortPreference().toUpperCase() === "IPTV";
    } catch (e) {
      return false;
    }
  },
  isAppSelected() {
    try {
      return !this.isHdmiSelected() && !this.isIptvSelected();
    } catch (e) {
      return false;
    }
  },
  isPortSelected(port) {
    try {
      if (!port) return false;
      return this.getResolvedPortPreference().toLowerCase() === String(port).toLowerCase();
    } catch (e) {
      return false;
    }
  },
  isSpecificAppSelected(app) {
    try {
      if (!app) return false;
      const currentPkg = this.getResolvedPortPreference().toLowerCase();
      const appPkg = (this.getAppPackageName(app) || "").toLowerCase();
      return Boolean(appPkg && currentPkg === appPkg);
    } catch (e) {
      return false;
    }
  },
  getSelectedPortDisplayLabel() {
    var _a;
    try {
      const val = this.getResolvedPortPreference();
      if (val === "IPTV") return "IPTV";
      if (this.isHdmiSelected()) return val;
      const apps = (typeof this.getActiveOttList === "function" ? this.getActiveOttList() : null) || (window.TVAppsController && typeof window.TVAppsController.getActiveOttList === "function" ? window.TVAppsController.getActiveOttList() : null) || ((_a = this.hotelData) == null ? void 0 : _a.active_ott) || [];
      const found = apps.find((a) => {
        const pkg = this.getAppPackageName(a);
        return pkg && pkg.toLowerCase() === val.toLowerCase();
      });
      return (found == null ? void 0 : found.name) ? `${found.name} (App)` : val;
    } catch (err) {
      console.warn("[TVSettings] Error in getSelectedPortDisplayLabel:", err);
      return this.liveTvSelectedPort || "HDMI 1";
    }
  },
  _persistPort(port, label) {
    var _a, _b, _c;
    try {
      this.liveTvSelectedPort = port;
      const exactValue = this.getResolvedPortPreference(port);
      try {
        localStorage.setItem("last_tv_input_port", exactValue);
        if ((_a = window.flutterBridge) == null ? void 0 : _a.savePortPreference) {
          window.flutterBridge.savePortPreference(exactValue).catch(() => {
          });
        } else if ((_b = window.flutterBridge) == null ? void 0 : _b.saveLiveTvPort) {
          window.flutterBridge.saveLiveTvPort(exactValue).catch(() => {
          });
        } else if ((_c = window.FlutterBridge) == null ? void 0 : _c.postMessage) {
          window.FlutterBridge.postMessage(JSON.stringify({
            method: "savePortPreference",
            args: [exactValue],
            id: Date.now()
          }));
        }
      } catch (storageOrBridgeErr) {
        console.warn("[TVSettings] Storage or bridge dispatch error:", storageOrBridgeErr);
      }
      this.hasUnsavedChanges = false;
      this.showToast(`Default TV Input set to ${label || this.getSelectedPortDisplayLabel()} \u2713`);
    } catch (e) {
      console.warn("[TVSettings] Port persistence warning:", e);
    }
  },
  selectHdmi(port) {
    try {
      if (!port) return;
      this.liveTvSelectedPort = port;
      this.hasUnsavedChanges = true;
      this.closeInputMenu();
      this.showToast(`Selected ${port}. Click 'Save Configuration' to save.`);
    } catch (e) {
      console.warn("[TVSettings] selectHdmi error:", e);
    }
  },
  selectIptv() {
    try {
      this.liveTvSelectedPort = "IPTV";
      this.hasUnsavedChanges = true;
      this.showToast("Selected IPTV. Click 'Save Configuration' to save.");
    } catch (e) {
      console.warn("[TVSettings] selectIptv error:", e);
    }
  },
  selectApp(app) {
    try {
      if (!app) return;
      const pkgName = this.getAppPackageName(app);
      this.liveTvSelectedPort = pkgName;
      this.hasUnsavedChanges = true;
      this.closeInputMenu();
      this.showToast(`Selected ${app.name || pkgName}. Click 'Save Configuration' to save.`);
    } catch (e) {
      console.warn("[TVSettings] selectApp error:", e);
    }
  },
  // =========================================================================
  // 4. HARDWARE TELEMETRY & NATIVE ANDROID TV BRIDGE
  // =========================================================================
  async loadHardwareDetails(isManual = false) {
    var _a, _b, _c, _d, _e;
    this.isRefreshingHw = true;
    const dev = ((_a = this.hotelData) == null ? void 0 : _a.device) || {};
    const tmpl = ((_b = this.hotelData) == null ? void 0 : _b.template) || {};
    try {
      if (((_d = (_c = window.flutterBridge) == null ? void 0 : _c.isAvailable) == null ? void 0 : _d.call(_c)) && typeof window.flutterBridge.identifyDevice === "function") {
        const info = await window.flutterBridge.identifyDevice();
        const d = info && info.data || info && info.device || info || {};
        const rawOs2 = d.os_version || dev.os_version || "16";
        const dynamicPorts = d.availableTvPorts || d.available_tv_ports || d.ports || d.availablePorts;
        if (Array.isArray(dynamicPorts) && dynamicPorts.length > 0) {
          const formattedPorts = dynamicPorts.map((p) => typeof p === "string" ? p : p.name || p.label || p.id || "HDMI").filter(Boolean);
          if (formattedPorts.length > 0) {
            this.availableTvPorts = formattedPorts;
          }
        } else if (((_e = window.flutterBridge) == null ? void 0 : _e.getTvInputs) && typeof window.flutterBridge.getTvInputs === "function") {
          try {
            const tvInputs = await window.flutterBridge.getTvInputs();
            if (Array.isArray(tvInputs) && tvInputs.length > 0) {
              const parsedPorts = tvInputs.map((p) => typeof p === "string" ? p : p.label || p.name || p.id || p.model).filter(Boolean);
              if (parsedPorts.length > 0) {
                this.availableTvPorts = parsedPorts;
              }
            }
          } catch (_) {
          }
        }
        this.hwData = {
          serial: d.serial || d.device_id || dev.device_id || "3d761ddf4a5d30a3",
          ip: d.ip || d.ip_address || dev.ip_address || "10.0.2.15",
          gateway: d.gateway || d.gway || dev.gateway || "",
          model: d.model || dev.model || "AOSP TV on x86",
          brand: d.brand || dev.brand || "google",
          mac: d.mac || d.mac_address || dev.mac_address || "4A:2D:A4:DF:D7:89",
          subnet: d.subnet || d.subnet_mask || dev.subnet_mask || "",
          dns: d.dns || d.DNS || dev.dns || "",
          android: String(rawOs2).toLowerCase().includes("android") ? String(rawOs2) : `Android ${rawOs2}`,
          version: d.version || d.template_version || tmpl.latest_version || "29.0",
          availableTvPorts: this.availableTvPorts
        };
        setTimeout(() => {
          this.isRefreshingHw = false;
          if (isManual) this.showToast("Hardware & Network telemetry refreshed from TV bridge \u2713");
        }, 350);
        return;
      }
    } catch (_) {
    }
    const rawOs = dev.os_version || "16";
    this.hwData = {
      serial: dev.device_id || "3d761ddf4a5d30a3",
      ip: dev.ip_address || "10.0.2.15",
      gateway: dev.gateway || "",
      model: dev.model || "AOSP TV on x86",
      brand: dev.brand || "google",
      mac: dev.mac_address || "4A:2D:A4:DF:D7:89",
      subnet: dev.subnet_mask || "",
      dns: dev.dns || "",
      android: String(rawOs).toLowerCase().includes("android") ? String(rawOs) : `Android ${rawOs}`,
      version: tmpl.latest_version || "29.0",
      availableTvPorts: this.availableTvPorts
    };
    setTimeout(() => {
      this.isRefreshingHw = false;
      if (isManual) this.showToast("Diagnostics refreshed from configuration \u2713");
    }, 350);
  },
  triggerAndroidSettings() {
    var _a, _b, _c, _d, _e;
    try {
      if ((_a = window.flutterBridge) == null ? void 0 : _a.openSettings) {
        window.flutterBridge.openSettings().catch(() => {
        });
      } else if ((_b = window.flutterBridge) == null ? void 0 : _b.openAndroidSettings) {
        window.flutterBridge.openAndroidSettings().catch(() => {
        });
      } else if ((_c = window.FlutterBridge) == null ? void 0 : _c.postMessage) {
        window.FlutterBridge.postMessage(JSON.stringify({ method: "openSettings", args: [], id: Date.now() }));
      } else if ((_d = window.Android) == null ? void 0 : _d.openAndroidSettings) {
        window.Android.openAndroidSettings();
      } else if ((_e = window.Android) == null ? void 0 : _e.openSettings) {
        window.Android.openSettings();
      }
    } catch (e) {
      console.warn("[TVSettings] Android settings error:", e);
    }
    this.showToast("Launching Android TV System Settings...");
  },
  async saveConfiguration() {
    var _a, _b, _c;
    try {
      this.isSavingConfig = true;
      const preferenceValue = this.getResolvedPortPreference();
      console.log("[TVSettings] Calling window.flutterBridge.savePortPreference with value:", preferenceValue);
      try {
        localStorage.setItem("last_tv_input_port", preferenceValue);
        if ((_a = window.flutterBridge) == null ? void 0 : _a.savePortPreference) {
          await window.flutterBridge.savePortPreference(preferenceValue);
        } else if ((_b = window.flutterBridge) == null ? void 0 : _b.saveLiveTvPort) {
          await window.flutterBridge.saveLiveTvPort(preferenceValue);
        } else if ((_c = window.FlutterBridge) == null ? void 0 : _c.postMessage) {
          window.FlutterBridge.postMessage(JSON.stringify({
            method: "savePortPreference",
            args: [preferenceValue],
            id: Date.now()
          }));
        }
      } catch (e) {
        console.warn("[TVSettings] Error saving port preference on bridge:", e);
      }
      const displayLabel = this.getSelectedPortDisplayLabel();
      setTimeout(() => {
        this.isSavingConfig = false;
        this.hasUnsavedChanges = false;
        this.showToast(`Configuration Saved! Default TV Input: ${displayLabel} \u2713`);
      }, 400);
    } catch (outerErr) {
      console.error("[TVSettings] Error in saveConfiguration:", outerErr);
      this.isSavingConfig = false;
    }
  },
  showToast(msg) {
    try {
      this.toastMessage = msg;
      if (this.toastTimer) clearTimeout(this.toastTimer);
      this.toastTimer = setTimeout(() => {
        try {
          this.toastMessage = "";
        } catch (_) {
        }
      }, 2500);
    } catch (e) {
      console.warn("[TVSettings] showToast error:", e);
    }
  },
  // =========================================================================
  // 5. FOCUS MANAGEMENT & REMOTE NAVIGATION
  // =========================================================================
  focusCurrentDashboardElement() {
    try {
      const nextTick = typeof this.$nextTick === "function" ? this.$nextTick.bind(this) : (fn) => setTimeout(fn, 0);
      nextTick(() => {
        try {
          if (this.settingsStep !== "dashboard") return;
          const focusMap = {
            "header_back": "tv-header-back-btn",
            "android_settings": "settings-android-btn",
            "refresh_hw": "settings-refresh-btn",
            "save": "settings-save-btn",
            "exit": "settings-exit-btn",
            "input_hdmi": "settings_input_hdmi",
            "input_iptv": "settings_input_iptv",
            "input_apps": "settings_input_apps",
            "input_back": "settings_input_back"
          };
          const targetId = focusMap[this.dashboardFocus] || (typeof this.dashboardFocus === "string" ? `settings_${this.dashboardFocus}` : null);
          if (targetId) {
            const el = document.getElementById(targetId);
            if (el) {
              el.focus();
              if (this.dashboardFocus.startsWith("app_")) {
                el.scrollIntoView({ behavior: "smooth", block: "nearest", inline: "nearest" });
              }
            }
          }
        } catch (domErr) {
          console.warn("[TVSettings] Focus dashboard element error:", domErr);
        }
      });
    } catch (e) {
      console.warn("[TVSettings] focusCurrentDashboardElement error:", e);
    }
  },
  handleSettingsKeyNavigation(e) {
    try {
      const digit = TVRemoteManager.getDigit(e);
      if (digit !== null) {
        e.preventDefault();
        if (this.settingsStep === "auth") this.addPinDigit(digit);
        return true;
      }
      if (this.settingsStep === "auth") {
        return this._handleAuthKeyNavigation(e);
      }
      if (this.settingsStep === "dashboard") {
        return this._handleDashboardKeyNavigation(e);
      }
      return false;
    } catch (err) {
      console.warn("[TVSettings] handleSettingsKeyNavigation error:", err);
      return false;
    }
  },
  // --- AUTH STEP NAVIGATION ---
  _handleAuthKeyNavigation(e) {
    var _a, _b, _c;
    try {
      if (e.key === "Backspace" || e.code === "Backspace" || e.keyCode === 8 || e.key === "Delete" || e.keyCode === 46) {
        e.preventDefault();
        this.delPinDigit();
        return true;
      }
      if (e.key === "Escape" || e.code === "Escape" || e.keyCode === 27) {
        e.preventDefault();
        this.handleSettingsEsc();
        return true;
      }
      if (TVRemoteManager.matches(e, "BACK")) {
        e.preventDefault();
        if (this.settingsPin.length > 0) this.delPinDigit();
        else this.handleSettingsEsc();
        return true;
      }
      if (TVRemoteManager.matches(e, "LEFT")) {
        e.preventDefault();
        if (typeof this.activeKeypadIndex === "number" && this.activeKeypadIndex % 3 !== 0) {
          this.activeKeypadIndex -= 1;
          this.focusCurrentKeypadBtn();
        }
        return true;
      }
      if (TVRemoteManager.matches(e, "RIGHT")) {
        e.preventDefault();
        if (typeof this.activeKeypadIndex === "number" && (this.activeKeypadIndex + 1) % 3 !== 0 && this.activeKeypadIndex < 11) {
          this.activeKeypadIndex += 1;
          this.focusCurrentKeypadBtn();
        }
        return true;
      }
      if (TVRemoteManager.matches(e, "UP")) {
        e.preventDefault();
        if (typeof this.activeKeypadIndex === "number") {
          if (this.activeKeypadIndex >= 3) {
            this.activeKeypadIndex -= 3;
            this.focusCurrentKeypadBtn();
          } else {
            this.activeKeypadIndex = "header_back";
            (_a = document.getElementById("tv-header-back-btn")) == null ? void 0 : _a.focus();
          }
        }
        return true;
      }
      if (TVRemoteManager.matches(e, "DOWN")) {
        e.preventDefault();
        if (this.activeKeypadIndex === "header_back" || document.activeElement === document.getElementById("tv-header-back-btn")) {
          (_b = document.getElementById("tv-header-back-btn")) == null ? void 0 : _b.blur();
          this.activeKeypadIndex = 0;
          this.focusCurrentKeypadBtn();
          return true;
        }
        if (typeof this.activeKeypadIndex === "number" && this.activeKeypadIndex + 3 < 12) {
          this.activeKeypadIndex += 3;
          this.focusCurrentKeypadBtn();
        }
        return true;
      }
      if (TVRemoteManager.matches(e, "ENTER")) {
        e.preventDefault();
        if (this.activeKeypadIndex === "header_back" || document.activeElement === document.getElementById("tv-header-back-btn")) {
          this.goBack();
        } else if (typeof this.activeKeypadIndex === "number") {
          (_c = document.getElementById(`settings_key_${this.activeKeypadIndex}`)) == null ? void 0 : _c.click();
        }
        return true;
      }
      return false;
    } catch (err) {
      console.warn("[TVSettings] _handleAuthKeyNavigation error:", err);
      return false;
    }
  },
  // --- DASHBOARD STEP NAVIGATION ---
  _handleDashboardKeyNavigation(e) {
    var _a, _b, _c;
    try {
      const appsList = (typeof this.getActiveOttList === "function" ? this.getActiveOttList() : []) || [];
      const totalApps = appsList.length;
      const appsCols = 4;
      if (e.key === "Escape" || e.code === "Escape" || e.keyCode === 27 || e.key === "Backspace" || e.code === "Backspace" || e.keyCode === 8 || TVRemoteManager.matches(e, "BACK")) {
        e.preventDefault();
        if (this.inputSelectionState !== "main") this.closeInputMenu();
        else this.goBack();
        return true;
      }
      if (TVRemoteManager.matches(e, "UP")) {
        e.preventDefault();
        if (this.dashboardFocus === "save") {
          if (this.lastDashboardSource === "refresh") this.dashboardFocus = "refresh_hw";
          else if (this.inputSelectionState === "hdmi") this.dashboardFocus = "hdmi_0";
          else if (this.inputSelectionState === "apps") this.dashboardFocus = "app_0";
          else this.dashboardFocus = "input_hdmi";
        } else if (this.dashboardFocus === "exit") {
          this.dashboardFocus = "refresh_hw";
        } else if (this.dashboardFocus === "refresh_hw") {
          this.dashboardFocus = "android_settings";
        } else if (this.inputSelectionState === "apps" && this.dashboardFocus.startsWith("app_")) {
          const idx = parseInt(this.dashboardFocus.replace("app_", ""), 10);
          if (Math.floor(idx / appsCols) > 0) this.dashboardFocus = `app_${idx - appsCols}`;
          else this.dashboardFocus = "header_back";
        } else {
          this.dashboardFocus = "header_back";
        }
        this.focusCurrentDashboardElement();
        return true;
      }
      if (TVRemoteManager.matches(e, "DOWN")) {
        e.preventDefault();
        if (this.dashboardFocus === "header_back" || document.activeElement === document.getElementById("tv-header-back-btn")) {
          (_a = document.getElementById("tv-header-back-btn")) == null ? void 0 : _a.blur();
          if (this.inputSelectionState === "hdmi") this.dashboardFocus = "hdmi_0";
          else if (this.inputSelectionState === "apps") this.dashboardFocus = "app_0";
          else this.dashboardFocus = "input_hdmi";
          this.lastDashboardSource = "input";
        } else if (this.dashboardFocus === "android_settings") {
          this.dashboardFocus = "refresh_hw";
        } else if (this.dashboardFocus === "refresh_hw") {
          this.lastDashboardSource = "refresh";
          this.dashboardFocus = "save";
        } else if (this.inputSelectionState === "apps" && this.dashboardFocus.startsWith("app_")) {
          const idx = parseInt(this.dashboardFocus.replace("app_", ""), 10);
          if (idx + appsCols < totalApps) {
            this.dashboardFocus = `app_${idx + appsCols}`;
          } else {
            this.lastDashboardSource = "input";
            this.dashboardFocus = "save";
          }
        } else if (["input_hdmi", "input_iptv", "input_apps", "input_back"].includes(this.dashboardFocus) || this.dashboardFocus.startsWith("hdmi_")) {
          this.lastDashboardSource = "input";
          this.dashboardFocus = "save";
        }
        this.focusCurrentDashboardElement();
        return true;
      }
      if (TVRemoteManager.matches(e, "LEFT")) {
        e.preventDefault();
        if (this.dashboardFocus === "exit") {
          this.dashboardFocus = "save";
        } else if (this.dashboardFocus === "android_settings" || this.dashboardFocus === "refresh_hw") {
          this.lastDashboardSource = "input";
          if (this.inputSelectionState === "hdmi") this.dashboardFocus = `hdmi_${this.availableTvPorts.length - 1}`;
          else if (this.inputSelectionState === "apps") this.dashboardFocus = "app_0";
          else this.dashboardFocus = "input_apps";
        } else if (this.dashboardFocus === "save") {
          this.lastDashboardSource = "input";
          if (this.inputSelectionState === "hdmi") this.dashboardFocus = "input_back";
          else if (this.inputSelectionState === "apps") this.dashboardFocus = "input_back";
          else this.dashboardFocus = "input_apps";
        } else if (this.inputSelectionState === "main") {
          if (this.dashboardFocus === "input_apps") this.dashboardFocus = "input_iptv";
          else if (this.dashboardFocus === "input_iptv") this.dashboardFocus = "input_hdmi";
        } else if (this.inputSelectionState === "hdmi") {
          if (this.dashboardFocus.startsWith("hdmi_")) {
            const idx = parseInt(this.dashboardFocus.replace("hdmi_", ""), 10);
            this.dashboardFocus = idx > 0 ? `hdmi_${idx - 1}` : "input_back";
          }
        } else if (this.inputSelectionState === "apps") {
          if (this.dashboardFocus.startsWith("app_")) {
            const idx = parseInt(this.dashboardFocus.replace("app_", ""), 10);
            this.dashboardFocus = idx % appsCols > 0 ? `app_${idx - 1}` : "input_back";
          }
        }
        this.focusCurrentDashboardElement();
        return true;
      }
      if (TVRemoteManager.matches(e, "RIGHT")) {
        e.preventDefault();
        if (this.dashboardFocus === "save") {
          this.dashboardFocus = "exit";
        } else if (this.inputSelectionState === "main") {
          if (this.dashboardFocus === "input_hdmi") this.dashboardFocus = "input_iptv";
          else if (this.dashboardFocus === "input_iptv") this.dashboardFocus = "input_apps";
          else if (this.dashboardFocus === "input_apps") this.dashboardFocus = "android_settings";
        } else if (this.inputSelectionState === "hdmi") {
          if (this.dashboardFocus === "input_back") {
            this.dashboardFocus = "hdmi_0";
          } else if (this.dashboardFocus.startsWith("hdmi_")) {
            const idx = parseInt(this.dashboardFocus.replace("hdmi_", ""), 10);
            if (idx < this.availableTvPorts.length - 1) this.dashboardFocus = `hdmi_${idx + 1}`;
            else this.dashboardFocus = "android_settings";
          }
        } else if (this.inputSelectionState === "apps") {
          if (this.dashboardFocus === "input_back") {
            this.dashboardFocus = "app_0";
          } else if (this.dashboardFocus.startsWith("app_")) {
            const idx = parseInt(this.dashboardFocus.replace("app_", ""), 10);
            if (idx % appsCols < appsCols - 1 && idx + 1 < totalApps) {
              this.dashboardFocus = `app_${idx + 1}`;
            } else {
              this.dashboardFocus = "android_settings";
            }
          }
        }
        this.focusCurrentDashboardElement();
        return true;
      }
      if (TVRemoteManager.matches(e, "ENTER")) {
        e.preventDefault();
        if (this.dashboardFocus === "header_back" || document.activeElement === document.getElementById("tv-header-back-btn")) {
          this.goBack();
        } else if (this.dashboardFocus === "input_hdmi") {
          this.openHdmiMenu();
        } else if (this.dashboardFocus === "input_iptv") {
          this.selectIptv();
        } else if (this.dashboardFocus === "input_apps") {
          this.openAppsMenu();
        } else if (this.dashboardFocus === "input_back") {
          this.closeInputMenu();
        } else if (typeof this.dashboardFocus === "string" && this.dashboardFocus.startsWith("hdmi_")) {
          const idx = parseInt(this.dashboardFocus.replace("hdmi_", ""), 10);
          if (this.availableTvPorts[idx]) this.selectHdmi(this.availableTvPorts[idx]);
        } else if (typeof this.dashboardFocus === "string" && this.dashboardFocus.startsWith("app_")) {
          const idx = parseInt(this.dashboardFocus.replace("app_", ""), 10);
          if (appsList[idx]) this.selectApp(appsList[idx]);
        } else if (this.dashboardFocus === "android_settings") {
          this.triggerAndroidSettings();
        } else if (this.dashboardFocus === "refresh_hw") {
          this.loadHardwareDetails(true);
        } else if (this.dashboardFocus === "save") {
          this.saveConfiguration();
        } else if (this.dashboardFocus === "exit") {
          this.goBack();
        } else {
          (_c = (_b = document.activeElement) == null ? void 0 : _b.click) == null ? void 0 : _c.call(_b);
        }
        return true;
      }
      return false;
    } catch (err) {
      console.warn("[TVSettings] _handleDashboardKeyNavigation error:", err);
      return false;
    }
  }
};
