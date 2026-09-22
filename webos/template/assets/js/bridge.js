(function() {
  "use strict";
  const PENDING_CALLS = /* @__PURE__ */ new Map();
  let CALL_COUNTER = 0;
  function generateCallId() {
    CALL_COUNTER = (CALL_COUNTER + 1) % 1e6;
    return CALL_COUNTER;
  }
  function isFlutterAvailable() {
    return typeof window !== "undefined" && Boolean(window.FlutterBridge && typeof window.FlutterBridge.postMessage === "function");
  }
  function callNative(method, args, timeoutMs) {
    return new Promise((resolve, reject) => {
      try {
        if (!isFlutterAvailable()) {
          return reject(new Error(`FlutterBridge not available (Browser mode: ${method})`));
        }
        const id = generateCallId();
        const timeout = timeoutMs || 1e4;
        const timer = setTimeout(() => {
          try {
            if (PENDING_CALLS.has(id)) {
              PENDING_CALLS.delete(id);
              reject(new Error(`Bridge call '${method}' timed out after ${timeout / 1e3}s`));
            }
          } catch (timerErr) {
            reject(timerErr);
          }
        }, timeout);
        PENDING_CALLS.set(id, {
          resolve: (result) => {
            try {
              clearTimeout(timer);
              resolve(result);
            } catch (resErr) {
              reject(resErr);
            }
          },
          reject: (err) => {
            try {
              clearTimeout(timer);
              reject(err);
            } catch (rejErr) {
              reject(rejErr);
            }
          }
        });
        try {
          const payload = JSON.stringify({
            method,
            args: Array.isArray(args) ? args : args !== void 0 ? [args] : [],
            id
          });
          window.FlutterBridge.postMessage(payload);
        } catch (postErr) {
          clearTimeout(timer);
          PENDING_CALLS.delete(id);
          reject(postErr);
        }
      } catch (outerErr) {
        reject(outerErr);
      }
    });
  }
  window.flutterBridge = {
    /**
     * Check if running inside Flutter Android TV app
     * @returns {boolean}
     */
    isAvailable() {
      try {
        return isFlutterAvailable();
      } catch (e) {
        return false;
      }
    },
    /**
     * Internal callback used by Flutter to resolve pending promises
     * @param {number} id - Request Call ID
     * @param {any} result - Response data
     */
    _resolve(id, result) {
      try {
        const pending = PENDING_CALLS.get(id);
        if (pending) {
          PENDING_CALLS.delete(id);
          pending.resolve(result);
        }
      } catch (e) {
        console.error("[Bridge] Error resolving call id " + id + ":", e);
      }
    },
    /**
     * Internal callback used by Flutter to reject pending promises
     * @param {number} id - Request Call ID
     * @param {string} error - Error message
     */
    _reject(id, error) {
      try {
        const pending = PENDING_CALLS.get(id);
        if (pending) {
          PENDING_CALLS.delete(id);
          pending.reject(new Error(error || "Native bridge call failed"));
        }
      } catch (e) {
        console.error("[Bridge] Error rejecting call id " + id + ":", e);
      }
    },
    // --------------------------------------------------------------------
    // 1. DEVICE PROVISIONING & CONFIGURATION
    // --------------------------------------------------------------------
    /**
     * Identify device hardware information (Serial, IP, Mac, Model, OS)
     * @param {string} [ip] - Optional TV IP address
     * @returns {Promise<Object>} Device hardware metadata
     */
    identifyDevice(ip) {
      try {
        return callNative("identifyDevice", ip ? [ip] : []);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Save full device configuration
     * @param {Object} config - Config payload
     * @returns {Promise<Object>} { success: boolean }
     */
    saveDeviceConfig(config) {
      try {
        return callNative("saveDeviceConfig", [config]);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Save room configuration mapping
     * @param {string} room - Room number (e.g. "101")
     * @param {Object} config - Room config
     * @returns {Promise<Object>} { success: boolean }
     */
    saveRoomConfig(room, config) {
      try {
        return callNative("saveRoomConfig", [room, config]);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Save full configuration payload
     * @param {Object} config - Configuration object
     * @returns {Promise<Object>} { success: boolean }
     */
    saveConfiguration(config) {
      try {
        return callNative("saveConfiguration", [config]);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Get stored device configuration
     * @param {string} [serial] - Device serial
     * @returns {Promise<Object|null>}
     */
    getDeviceConfig(serial) {
      try {
        return callNative("getDeviceConfig", serial ? [serial] : []);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Get stored room configuration
     * @param {string} room - Room number
     * @returns {Promise<Object|null>}
     */
    getRoomConfig(room) {
      try {
        return callNative("getRoomConfig", [room]);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Clear cached configurations on the TV
     * @returns {Promise<Object>} { success: boolean }
     */
    clearConfig() {
      try {
        return callNative("clearConfig", []);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Save weather forecast payload into local device cache/file on TV
     * @param {Object} weatherData - Weather forecast payload
     * @returns {Promise<Object>} { success: boolean }
     */
    saveWeatherData(weatherData) {
      try {
        return callNative("saveWeatherData", [weatherData]);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    // --------------------------------------------------------------------
    // 2. TV CONTROL, APPLICATIONS & HARDWARE PORTS
    // --------------------------------------------------------------------
    /**
     * Launch an Android TV app by package name
     * @param {string} packageName - App package name (e.g. "com.google.android.youtube.tv")
     * @returns {Promise<Object>} { success: boolean }
     */
    launchApp(packageName) {
      try {
        return callNative("launchApp", [packageName]);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Launch HDMI / Hardware TV input by model or port identifier
     * @param {string} model - Port identifier (e.g. "HDMI 1" or "HDMI_1")
     * @returns {Promise<Object>} { success: boolean }
     */
    launchHdmi(model) {
      try {
        return callNative("launchHdmi", [model]);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Launch Live TV / Connected Set-top box port
     * @param {string} [port] - Optional specific port name
     * @returns {Promise<Object>} { success: boolean, port: string }
     */
    launchLiveTv(port) {
      try {
        return callNative("launchLiveTv", port ? [port] : []);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Launch IPTV Stream with configuration
     * @param {string} [packageName] - IPTV package
     * @param {string} [configPath] - Config path (e.g. "iptv/all.json")
     * @returns {Promise<Object>} { success: boolean }
     */
    launchIptv(packageName, configPath) {
      try {
        const args = packageName ? [packageName, configPath || ""] : ["iptv", "iptv/all.json"];
        return callNative("launchIptv", args);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Launch Default Live TV based on saved user preference (HDMI / IPTV / TV App)
     * @param {string} [fallbackPort='HDMI 1']
     * @returns {Promise<Object>}
     */
    async launchDefaultLiveTv(fallbackPort = "HDMI 1") {
      try {
        let pref = localStorage.getItem("last_tv_input_port");
        if (!pref && this.getSelectedLiveTvPort && isFlutterAvailable()) {
          try {
            const res = await this.getSelectedLiveTvPort();
            pref = (res == null ? void 0 : res.selectedPort) || (res == null ? void 0 : res.port);
          } catch (_) {
          }
        }
        const target = pref || fallbackPort;
        console.log("[Bridge] Launching Default Live TV target:", target);
        if (!isFlutterAvailable()) {
          console.log("[Bridge] Browser preview: launchDefaultLiveTv simulated for", target);
          return { success: true, mode: "browser_simulated", target };
        }
        if (target.startsWith("APP:") || target.includes(".") || !target.toUpperCase().startsWith("HDMI") && target.toUpperCase() !== "IPTV") {
          const pkg = target.replace(/^APP:/i, "").trim();
          return await this.launchApp(pkg);
        } else if (target === "IPTV") {
          return await this.launchIptv("iptv", "iptv/all.json");
        } else {
          try {
            return await this.launchHdmi(target);
          } catch (e) {
            return await this.launchLiveTv(target);
          }
        }
      } catch (err) {
        console.warn("[Bridge] launchDefaultLiveTv error:", err);
        return { success: false, error: (err == null ? void 0 : err.message) || String(err) };
      }
    },
    /**
     * Get physically connected Live TV input sources
     * @returns {Promise<Array<Object>>} List of connected ports
     */
    getLiveTvInputs() {
      try {
        return callNative("getLiveTvInputs", []);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Get all available HDMI and hardware input models
     * @returns {Promise<Array<Object>|Object>}
     */
    getHdmiModels() {
      try {
        return callNative("getHdmiModels", []);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Get user's saved/preferred Live TV port
     * @returns {Promise<Object>} { selectedPort: string, port: string }
     */
    getSelectedLiveTvPort() {
      try {
        return callNative("getSelectedLiveTvPort", []);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Save preferred Live TV input port
     * @param {string} port - Port identifier / exact preference value
     * @returns {Promise<Object>} { success: boolean }
     */
    savePortPreference(port) {
      try {
        if (!isFlutterAvailable()) {
          console.log("[Bridge] Browser preview: savePortPreference simulated with value:", port);
          return Promise.resolve({ success: true, mode: "browser_simulated", port });
        }
        return callNative("savePortPreference", [port]);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Alias for savePortPreference
     */
    saveLiveTvPort(port) {
      return this.savePortPreference(port);
    },
    // --------------------------------------------------------------------
    // 3. SYSTEM OPERATIONS, SETTINGS & NETWORK
    // --------------------------------------------------------------------
    /**
     * Open Android System Settings on TV
     * @returns {Promise<Object>} { success: boolean }
     */
    openSettings() {
      try {
        return callNative("openSettings", []);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Alias for openSettings
     */
    openAndroidSettings() {
      return this.openSettings();
    },
    /**
     * Open Android WiFi Settings screen
     * @returns {Promise<Object>} { success: boolean }
     */
    openWifiSettings() {
      try {
        return callNative("openWifiSettings", []);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Launch wireless screen casting on TV
     * @returns {Promise<Object>} { success: boolean }
     */
    launchCast() {
      try {
        return callNative("launchCast", []);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Refresh template data and reload WebView with fresh backend data
     * @returns {Promise<Object>} { success: boolean }
     */
    refreshApp() {
      try {
        return callNative("refreshApp", []);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Check internet connectivity
     * @returns {Promise<boolean>} True if connected
     */
    checkInternet() {
      var _a;
      try {
        return callNative("checkInternet", []);
      } catch (e) {
        return Promise.resolve((_a = navigator == null ? void 0 : navigator.onLine) != null ? _a : true);
      }
    },
    /**
     * Get WiFi signal level and connection details
     * @returns {Promise<Object>} { connected: boolean, level: number, type: string }
     */
    getWifiSignalStrength() {
      try {
        return callNative("getWifiSignalStrength", []);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Set display language on TV
     * @param {string} lang - Language code/file (e.g. "hindi.json")
     * @returns {Promise<Object>} { success: boolean }
     */
    setLanguage(lang) {
      try {
        return callNative("setLanguage", [lang]);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Get supported languages list
     * @returns {Promise<Array<Object>>}
     */
    getLanguages() {
      try {
        return callNative("getLanguages", []);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Get full TV system info
     * @returns {Promise<Object>}
     */
    getSystemInfo() {
      try {
        return callNative("getSystemInfo", []);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Get live flight schedule data for an airport (or hotel's primary/secondary)
     * @param {string} [airportCode] - Optional 3-letter IATA code (e.g. "BOM")
     * @returns {Promise<Object>} { success: boolean, data: Object }
     */
    getFlightData(airportCode) {
      try {
        return callNative("getFlightData", airportCode ? [airportCode] : []);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Force refresh flight data from server/upstream API
     * @param {string} [airportCode] - Optional 3-letter IATA code
     * @returns {Promise<Object>}
     */
    refreshFlightData(airportCode) {
      try {
        return callNative("refreshFlightData", airportCode ? [airportCode] : []);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    // --------------------------------------------------------------------
    // 4. PUBLIC WRAPPER & FALLBACK QUERIES (Hybrid Offline / Online)
    // --------------------------------------------------------------------
    /**
     * Generic native method invoker
     * @param {string} method - Method name
     * @param {Array<any>} [args=[]] - Args
     * @returns {Promise<any>}
     */
    call(method, args) {
      try {
        return callNative(method, args || []);
      } catch (e) {
        return Promise.reject(e);
      }
    },
    /**
     * Get installed applications on the TV
     * Gracefully falls back to admin JSON when outside Flutter
     * @returns {Promise<Array<Object>>}
     */
    async getInstalledApps() {
      try {
        return await callNative("getInstalledApps", []);
      } catch (e) {
        try {
          const resp = await fetch("admin/tv_apps.json?t=" + Date.now());
          if (resp.ok) {
            const data = await resp.json();
            return data.available_tv_apps || data;
          }
        } catch (_) {
        }
        return [];
      }
    },
    /**
     * Alias for getInstalledApps
     */
    async getApps() {
      return this.getInstalledApps();
    },
    /**
     * Get available TV input ports (Real Hardware TV Ports Only)
     * Queries native Flutter Android TV TvInputManager directly
     * @returns {Promise<Array<Object>>}
     */
    async getTvInputs() {
      try {
        return await callNative("getTvInputs", []);
      } catch (e) {
        console.warn("FlutterBridge not available or getTvInputs error:", e);
        return [
          { id: "HDMI_1", label: "HDMI 1", name: "HDMI 1", model: "HDMI_1", type: "HDMI", isConnected: "true" },
          { id: "HDMI_2", label: "HDMI 2", name: "HDMI 2", model: "HDMI_2", type: "HDMI", isConnected: "true" },
          { id: "AV", label: "AV Input", name: "AV Input", model: "AV", type: "AV", isConnected: "true" },
          { id: "TUNER", label: "Live TV (Tuner)", name: "Live TV (Tuner)", model: "TUNER", type: "TUNER", isConnected: "true" }
        ];
      }
    }
  };
  window.AndroidBridge = {
    getPictureList(category) {
      try {
        return window.flutterBridge.getPictureList ? window.flutterBridge.getPictureList(category) : Promise.resolve([]);
      } catch (e) {
        return Promise.resolve([]);
      }
    },
    rotateImage(imagePath, degrees) {
      try {
        return window.flutterBridge.rotateImage ? window.flutterBridge.rotateImage(imagePath, degrees) : Promise.resolve({});
      } catch (e) {
        return Promise.resolve({});
      }
    },
    hideLoading() {
      try {
        if (window.FlutterBridge && window.FlutterBridge.postMessage) {
          window.FlutterBridge.postMessage(JSON.stringify({ method: "hideLoading", args: [], id: 0 }));
        }
      } catch (_) {
      }
    }
  };
  window.Android = {
    openAndroidSettings() {
      try {
        return window.flutterBridge.openSettings();
      } catch (e) {
        return Promise.resolve({ success: false });
      }
    },
    openSettings() {
      try {
        return window.flutterBridge.openSettings();
      } catch (e) {
        return Promise.resolve({ success: false });
      }
    },
    pictureListReady(jsonString) {
      try {
        window.dispatchEvent(new CustomEvent("pictureListReady", { detail: jsonString }));
      } catch (e) {
        console.warn("[Android] pictureListReady error:", e);
      }
    },
    hideLoading() {
      try {
        window.AndroidBridge.hideLoading();
      } catch (_) {
      }
    }
  };
})();
window.TVKeyInjector = {
  triggerBack: function() {
    try {
      this.triggerKey(8, "Backspace");
    } catch (e) {
      console.warn("[TVKeyInjector] triggerBack error:", e);
    }
  },
  triggerNumber: function(digit) {
    try {
      var num = parseInt(digit, 10);
      if (num >= 0 && num <= 9) {
        this.triggerKey(48 + num, digit);
      }
    } catch (e) {
      console.warn("[TVKeyInjector] triggerNumber error:", e);
    }
  },
  triggerKey: function(keyCode, keyName) {
    try {
      var event = new KeyboardEvent("keydown", {
        bubbles: true,
        cancelable: true,
        keyCode,
        which: keyCode,
        key: keyName || ""
      });
      document.dispatchEvent(event);
    } catch (e) {
      console.warn("[TVKeyInjector] triggerKey error:", e);
    }
  }
};
