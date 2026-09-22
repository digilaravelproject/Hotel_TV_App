/**
 * ============================================================================
 * Hotel TV - Native Flutter Bridge Interface (bridge.js)
 * ============================================================================
 * 
 * Provides a robust, bidirectional JavaScript-to-Dart communication bridge
 * for the Hotel Android TV application and web template.
 * 
 * Communication Flow:
 *  - JS to Dart: window.FlutterBridge.postMessage(JSON.stringify({ method, args, id }))
 *  - Dart to JS: window.flutterBridge._resolve(id, result) OR window.flutterBridge._reject(id, error)
 * 
 * Features:
 *  - Automated unique call ID management
 *  - Request timeout and garbage collection
 *  - Graceful fallback for non-Flutter / Desktop Browser testing
 *  - 100% try-catch defensive programming
 * ============================================================================
 */

(function () {
    'use strict';

    // Internal Pending Calls Map & Call ID Generator
    const PENDING_CALLS = new Map();
    let CALL_COUNTER = 0;

    /**
     * Generate an incremental unique integer ID for bridge requests
     * @returns {number}
     */
    function generateCallId() {
        CALL_COUNTER = (CALL_COUNTER + 1) % 1000000;
        return CALL_COUNTER;
    }

    /**
     * Check if FlutterBridge JavaScriptChannel is available
     * @returns {boolean}
     */
    function isFlutterAvailable() {
        return typeof window !== 'undefined' &&
            Boolean(window.FlutterBridge && typeof window.FlutterBridge.postMessage === 'function');
    }

    /**
     * Core Native Method Invocation Handler
     * @param {string} method - Flutter Bridge method name
     * @param {Array<any>} [args=[]] - Arguments array
     * @param {number} [timeoutMs=10000] - Request timeout in milliseconds
     * @returns {Promise<any>}
     */
    function callNative(method, args, timeoutMs) {
        return new Promise((resolve, reject) => {
            if (!isFlutterAvailable()) {
                return reject(new Error(`FlutterBridge not available (Browser mode: ${method})`));
            }

            const id = generateCallId();
            const timeout = timeoutMs || 10000;

            const timer = setTimeout(() => {
                if (PENDING_CALLS.has(id)) {
                    PENDING_CALLS.delete(id);
                    reject(new Error(`Bridge call '${method}' timed out after ${timeout / 1000}s`));
                }
            }, timeout);

            PENDING_CALLS.set(id, {
                resolve: (result) => {
                    clearTimeout(timer);
                    resolve(result);
                },
                reject: (err) => {
                    clearTimeout(timer);
                    reject(err);
                }
            });

            try {
                const payload = JSON.stringify({
                    method: method,
                    args: Array.isArray(args) ? args : (args !== undefined ? [args] : []),
                    id: id
                });
                window.FlutterBridge.postMessage(payload);
            } catch (postErr) {
                clearTimeout(timer);
                PENDING_CALLS.delete(id);
                reject(postErr);
            }
        });
    }

    // ========================================================================
    // MAIN FLUTTER BRIDGE API
    // ========================================================================
    window.flutterBridge = {

        /**
         * Check if running inside Flutter Android TV app
         * @returns {boolean}
         */
        isAvailable() {
            return isFlutterAvailable();
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
                    pending.reject(new Error(error || 'Native bridge call failed'));
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
            return callNative('identifyDevice', ip ? [ip] : []);
        },

        /**
         * Save full device configuration
         * @param {Object} config - Config payload
         * @returns {Promise<Object>} { success: boolean }
         */
        saveDeviceConfig(config) {
            return callNative('saveDeviceConfig', [config]);
        },

        /**
         * Save room configuration mapping
         * @param {string} room - Room number (e.g. "101")
         * @param {Object} config - Room config
         * @returns {Promise<Object>} { success: boolean }
         */
        saveRoomConfig(room, config) {
            return callNative('saveRoomConfig', [room, config]);
        },

        /**
         * Save full configuration payload
         * @param {Object} config - Configuration object
         * @returns {Promise<Object>} { success: boolean }
         */
        saveConfiguration(config) {
            return callNative('saveConfiguration', [config]);
        },

        /**
         * Get stored device configuration
         * @param {string} [serial] - Device serial
         * @returns {Promise<Object|null>}
         */
        getDeviceConfig(serial) {
            return callNative('getDeviceConfig', serial ? [serial] : []);
        },

        /**
         * Get stored room configuration
         * @param {string} room - Room number
         * @returns {Promise<Object|null>}
         */
        getRoomConfig(room) {
            return callNative('getRoomConfig', [room]);
        },

        /**
         * Clear cached configurations on the TV
         * @returns {Promise<Object>} { success: boolean }
         */
        clearConfig() {
            return callNative('clearConfig', []);
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
            return callNative('launchApp', [packageName]);
        },

        /**
         * Launch HDMI / Hardware TV input by model or port identifier
         * @param {string} model - Port identifier (e.g. "HDMI 1" or "HDMI_1")
         * @returns {Promise<Object>} { success: boolean }
         */
        launchHdmi(model) {
            return callNative('launchHdmi', [model]);
        },

        /**
         * Launch Live TV / Connected Set-top box port
         * @param {string} [port] - Optional specific port name
         * @returns {Promise<Object>} { success: boolean, port: string }
         */
        launchLiveTv(port) {
            return callNative('launchLiveTv', port ? [port] : []);
        },

        /**
         * Launch IPTV Stream with configuration
         * @param {string} packageName - IPTV package
         * @param {string} [configPath] - Config path (e.g. "iptv/all.json")
         * @returns {Promise<Object>} { success: boolean }
         */
        launchIptv(packageName, configPath) {
            return callNative('launchIptv', [packageName, configPath]);
        },

        /**
         * Get physically connected Live TV input sources
         * @returns {Promise<Array<Object>>} List of connected ports
         */
        getLiveTvInputs() {
            return callNative('getLiveTvInputs', []);
        },

        /**
         * Get all available HDMI and hardware input models
         * @returns {Promise<Array<Object>|Object>}
         */
        getHdmiModels() {
            return callNative('getHdmiModels', []);
        },

        /**
         * Get user's saved/preferred Live TV port
         * @returns {Promise<Object>} { selectedPort: string, port: string }
         */
        getSelectedLiveTvPort() {
            return callNative('getSelectedLiveTvPort', []);
        },

        /**
         * Save preferred Live TV input port
         * @param {string} port - Port ID (e.g. "HDMI_1")
         * @returns {Promise<Object>} { success: boolean }
         */
        savePortPreference(port) {
            return callNative('savePortPreference', [port]);
        },

        /**
         * Alias for savePortPreference
         */
        saveLiveTvPort(port) {
            return callNative('saveLiveTvPort', [port]);
        },

        // --------------------------------------------------------------------
        // 3. SYSTEM OPERATIONS, SETTINGS & NETWORK
        // --------------------------------------------------------------------

        /**
         * Open Android System Settings on TV
         * @returns {Promise<Object>} { success: boolean }
         */
        openSettings() {
            return callNative('openSettings', []);
        },

        /**
         * Alias for openSettings
         */
        openAndroidSettings() {
            return callNative('openAndroidSettings', []);
        },

        /**
         * Open Android WiFi Settings screen
         * @returns {Promise<Object>} { success: boolean }
         */
        openWifiSettings() {
            return callNative('openWifiSettings', []);
        },

        /**
         * Launch wireless screen casting on TV
         * @returns {Promise<Object>} { success: boolean }
         */
        launchCast() {
            return callNative('launchCast', []);
        },

        /**
         * Refresh template data and reload WebView with fresh backend data
         * @returns {Promise<Object>} { success: boolean }
         */
        refreshApp() {
            return callNative('refreshApp', []);
        },

        /**
         * Check internet connectivity
         * @returns {Promise<boolean>} True if connected
         */
        checkInternet() {
            return callNative('checkInternet', []);
        },

        /**
         * Get WiFi signal level and connection details
         * @returns {Promise<Object>} { connected: boolean, level: number, type: string }
         */
        getWifiSignalStrength() {
            return callNative('getWifiSignalStrength', []);
        },

        /**
         * Set display language on TV
         * @param {string} lang - Language code/file (e.g. "hindi.json")
         * @returns {Promise<Object>} { success: boolean }
         */
        setLanguage(lang) {
            return callNative('setLanguage', [lang]);
        },

        /**
         * Get supported languages list
         * @returns {Promise<Array<Object>>}
         */
        getLanguages() {
            return callNative('getLanguages', []);
        },

        /**
         * Get full TV system info
         * @returns {Promise<Object>}
         */
        getSystemInfo() {
            return callNative('getSystemInfo', []);
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
            return callNative(method, args || []);
        },

        /**
         * Get installed applications on the TV
         * Gracefully falls back to admin JSON when outside Flutter
         * @returns {Promise<Array<Object>>}
         */
        async getInstalledApps() {
            try {
                return await callNative('getInstalledApps', []);
            } catch (e) {
                try {
                    const resp = await fetch('admin/tv_apps.json?t=' + Date.now());
                    if (resp.ok) {
                        const data = await resp.json();
                        return data.available_tv_apps || data;
                    }
                } catch (_) { }
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
                return await callNative('getTvInputs', []);
            } catch (e) {
                console.warn('FlutterBridge not available or getTvInputs error:', e);
                return [
                    { id: 'HDMI_1', label: 'HDMI 1', name: 'HDMI 1', model: 'HDMI_1', type: 'HDMI', isConnected: 'true' },
                    { id: 'HDMI_2', label: 'HDMI 2', name: 'HDMI 2', model: 'HDMI_2', type: 'HDMI', isConnected: 'true' },
                    { id: 'AV', label: 'AV Input', name: 'AV Input', model: 'AV', type: 'AV', isConnected: 'true' },
                    { id: 'TUNER', label: 'Live TV (Tuner)', name: 'Live TV (Tuner)', model: 'TUNER', type: 'TUNER', isConnected: 'true' }
                ];
            }
        }
    };

    // ========================================================================
    // BACKWARD COMPATIBILITY LAYERS (Legacy Gallery & Older Modules)
    // ========================================================================

    window.AndroidBridge = {
        getPictureList(category) {
            return window.flutterBridge.getPictureList ? window.flutterBridge.getPictureList(category) : Promise.resolve([]);
        },
        rotateImage(imagePath, degrees) {
            return window.flutterBridge.rotateImage ? window.flutterBridge.rotateImage(imagePath, degrees) : Promise.resolve({});
        },
        hideLoading() {
            if (window.FlutterBridge && window.FlutterBridge.postMessage) {
                try {
                    window.FlutterBridge.postMessage(JSON.stringify({ method: 'hideLoading', args: [], id: 0 }));
                } catch (_) { }
            }
        }
    };

    window.Android = {
        openAndroidSettings() {
            return window.flutterBridge.openSettings();
        },
        openSettings() {
            return window.flutterBridge.openSettings();
        },
        pictureListReady(jsonString) {
            window.dispatchEvent(new CustomEvent('pictureListReady', { detail: jsonString }));
        },
        hideLoading() {
            window.AndroidBridge.hideLoading();
        }
    };

})();

// ============================================================================
// GLOBAL TV REMOTE KEY INJECTOR
// ============================================================================
window.TVKeyInjector = {
    triggerBack: function () {
        this.triggerKey(8, 'Backspace');
    },
    triggerNumber: function (digit) {
        var num = parseInt(digit, 10);
        if (num >= 0 && num <= 9) {
            this.triggerKey(48 + num, digit);
        }
    },
    triggerKey: function (keyCode, keyName) {
        var event = new KeyboardEvent('keydown', {
            bubbles: true,
            cancelable: true,
            keyCode: keyCode,
            which: keyCode,
            key: keyName || ''
        });
        document.dispatchEvent(event);
    }
};