/**
 * PAX TV Hospitality - Samsung Tizen TV Device Adapter
 * Interfaces with Samsung Tizen TV platform APIs.
 * Replaces webos-device.js — provides the same WebOSDevice-compatible interface.
 */

(function (window) {
  'use strict';

  var TizenDevice = {
    isTizen: false,
    deviceInfo: {
      deviceId: '',
      macAddress: '00:E0:91:AA:BB:CC',
      ipAddress: '192.168.1.150',
      model: 'Samsung Smart TV',
      brand: 'Samsung',
      osVersion: 'Tizen 5.5',
      networkState: 'connected'
    },

    init: function () {
      this.isTizen = typeof window.tizen !== 'undefined';
      this.deviceInfo.deviceId = window.ApiService ? window.ApiService.getDeviceId() : 'SAMSUNG-TV-' + Date.now();

      if (this.isTizen) {
        console.log('[TizenDevice] Running natively on Samsung Tizen platform');
        this._registerKeys();
        this._querySystemInfo();
        this._queryNetworkInfo();
      } else {
        console.log('[TizenDevice] Running in Web/Emulator Browser Fallback mode');
        this._detectBrowserInfo();
      }
    },

    /**
     * Register TV remote keys so Tizen forwards them to the app
     */
    _registerKeys: function () {
      try {
        var inputDevice = tizen.tvinputdevice;
        var keysToRegister = [
          'ColorF0Red', 'ColorF1Green', 'ColorF2Yellow', 'ColorF3Blue',
          'MediaPlay', 'MediaPause', 'MediaStop', 'MediaFastForward', 'MediaRewind',
          'ChannelUp', 'ChannelDown',
          '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'
        ];
        keysToRegister.forEach(function (key) {
          try { inputDevice.registerKey(key); } catch (_) {}
        });
        console.log('[TizenDevice] Remote keys registered');
      } catch (e) {
        console.warn('[TizenDevice] Key registration failed:', e);
      }
    },

    _detectBrowserInfo: function () {
      var ua = navigator.userAgent;
      if (ua.indexOf('Tizen') !== -1 || ua.indexOf('SMART-TV') !== -1 || ua.indexOf('SmartTV') !== -1) {
        this.deviceInfo.model = 'Samsung Smart TV (Tizen Web Engine)';
      } else if (ua.indexOf('Chrome') !== -1) {
        this.deviceInfo.model = 'Chrome TV Simulator';
      }
    },

    _querySystemInfo: function () {
      var self = this;
      try {
        tizen.systeminfo.getPropertyValue('BUILD', function (build) {
          if (build.model) self.deviceInfo.model = build.model;
          if (build.manufacturer) self.deviceInfo.brand = build.manufacturer;
          console.log('[TizenDevice] Build info:', build.model, build.manufacturer);
        }, function (err) {
          console.warn('[TizenDevice] Failed to get BUILD info:', err);
        });
      } catch (e) {
        console.warn('[TizenDevice] systeminfo BUILD request failed:', e);
      }

      try {
        tizen.systeminfo.getPropertyValue('DEVICE_ORIENTATION', function (orient) {
          console.log('[TizenDevice] Orientation:', orient.status);
        }, function () {});
      } catch (_) {}
    },

    _queryNetworkInfo: function () {
      var self = this;
      try {
        tizen.systeminfo.getPropertyValue('WIFI_NETWORK', function (wifi) {
          if (wifi.status === 'ON') {
            self.deviceInfo.networkState = 'connected';
            if (wifi.ipAddress) self.deviceInfo.ipAddress = wifi.ipAddress;
            if (wifi.macAddress) self.deviceInfo.macAddress = wifi.macAddress;
            console.log('[TizenDevice] WiFi connected, IP:', wifi.ipAddress);
          }
        }, function (err) {
          console.warn('[TizenDevice] WiFi info failed:', err);
        });
      } catch (e) {
        console.warn('[TizenDevice] WiFi query failed:', e);
      }

      try {
        tizen.systeminfo.getPropertyValue('ETHERNET_NETWORK', function (eth) {
          if (eth.status === 'ON') {
            self.deviceInfo.networkState = 'connected';
            if (eth.ipAddress) self.deviceInfo.ipAddress = eth.ipAddress;
            if (eth.macAddress) self.deviceInfo.macAddress = eth.macAddress;
            console.log('[TizenDevice] Ethernet connected, IP:', eth.ipAddress);
          }
        }, function () {});
      } catch (_) {}
    },

    /**
     * Map common Android package names or aliases to Samsung Tizen App IDs
     */
    mapToTizenAppId: function (idOrPkg) {
      if (!idOrPkg) return '';
      var cleaned = String(idOrPkg).toLowerCase().trim();
      var appMap = {
        'com.google.android.youtube.tv': '111299001912',
        'com.google.android.youtube': '111299001912',
        'youtube': '111299001912',
        'com.netflix.ninja': '3201907018807',
        'com.netflix.mediaclient': '3201907018807',
        'netflix': '3201907018807',
        'com.amazon.amazonvideo.livingroom': '3201910019365',
        'com.amazon.avod.thirdpartyclient': '3201910019365',
        'amazon': '3201910019365',
        'prime': '3201910019365',
        'primevideo': '3201910019365',
        'in.startv.hotstar': '3201907018784',
        'hotstar': '3201907018784',
        'disney': '3201907018784',
        'com.graymatrix.did': '3201806016498',
        'zee5': '3201806016498',
        'com.sony.liv': '3201909019758',
        'sonyliv': '3201909019758',
        'com.jio.media.ondemand': '3201909019845',
        'jiocinema': '3201909019845',
        'livetv': 'org.tizen.tv.livetv',
        'live_tv': 'org.tizen.tv.livetv'
      };
      return appMap[cleaned] || idOrPkg;
    },

    /**
     * Launch OTT application (e.g. YouTube, Netflix) installed on Samsung Tizen
     */
    launchApp: function (appId, params) {
      var targetId = this.mapToTizenAppId(appId);
      console.log('[TizenDevice] Requesting app launch for: ' + appId + ' -> ' + targetId);

      if (!this.isTizen) {
        console.log('[TizenDevice] Simulating launching app: ' + targetId);
        return;
      }
      try {
        var appControl = new tizen.ApplicationControl(
          'http://tizen.org/appcontrol/operation/default',
          null, null, null, []
        );
        tizen.application.launchAppControl(
          appControl,
          targetId,
          function () {
            console.log('[TizenDevice] App launched successfully: ' + targetId);
          },
          function (err) {
            console.warn('[TizenDevice] Failed to launch app ' + targetId + ':', err);
          }
        );
      } catch (e) {
        console.error('[TizenDevice] Error requesting application launch:', e);
        // Fallback: try simple launch
        try {
          tizen.application.launch(targetId);
        } catch (e2) {
          console.error('[TizenDevice] Fallback launch also failed:', e2);
        }
      }
    },

    /**
     * Launch Native Samsung Live TV
     */
    launchLiveTv: function () {
      console.log('[TizenDevice] Launching native Live TV...');
      this.launchApp('org.tizen.tv.livetv');
    },

    /**
     * Switch Hardware TV Input (HDMI 1, HDMI 2, AV, etc.)
     */
    switchInput: function (portId) {
      console.log('[TizenDevice] Switching hardware TV input to:', portId);
      var p = (portId || '').toUpperCase().trim();

      if (p.includes('HDMI') || p.includes('AV') || p.includes('TUNER')) {
        // On Tizen, input switching can be done by launching the source app
        try {
          if (this.isTizen) {
            tizen.application.launch('org.tizen.tv.source');
          }
        } catch (e) {
          console.warn('[TizenDevice] Cannot switch input:', e);
        }
      } else if (p.includes('LIVE') || p.includes('ANTENNA')) {
        this.launchLiveTv();
      }
    },

    /**
     * Check if a single app is installed on Tizen TV
     */
    isAppInstalled: function (appId, callback) {
      var self = this;
      var targetId = self.mapToTizenAppId(appId);
      if (!self.isTizen) {
        if (typeof callback === 'function') callback(false, targetId);
        return;
      }
      try {
        tizen.application.getAppInfo(targetId);
        if (typeof callback === 'function') callback(true, targetId);
      } catch (e) {
        if (typeof callback === 'function') callback(false, targetId, e);
      }
    },

    /**
     * Map app to candidate Tizen IDs
     */
    getTizenCandidates: function (idOrPkg) {
      if (!idOrPkg) return [];
      var cleaned = String(idOrPkg).toLowerCase().trim();
      if (cleaned.includes('vending') || cleaned.includes('playstore') || cleaned.includes('play store') || cleaned.includes('google play')) {
        return [];
      }
      var mapped = this.mapToTizenAppId(cleaned);
      return mapped !== cleaned ? [mapped] : [cleaned];
    },

    /**
     * Filter server configured app list and return ONLY installed apps.
     * Android-only apps (like Google Play Store) are permanently omitted.
     */
    checkInstalledApps: function (appList) {
      var self = this;
      if (!Array.isArray(appList) || appList.length === 0) {
        return Promise.resolve([]);
      }

      var candidates = appList.filter(function (app) {
        var pkg = (app.package_name || app.id || '').toLowerCase();
        var name = (app.name || '').toLowerCase();
        return !pkg.includes('vending') && !pkg.includes('playstore') && !name.includes('play store');
      });

      if (!self.isTizen) {
        return Promise.resolve(candidates);
      }

      var verified = [];
      candidates.forEach(function (app) {
        var tizenId = self.mapToTizenAppId(app.package_name || app.id);
        try {
          tizen.application.getAppInfo(tizenId);
          var cloned = Object.assign({}, app);
          cloned.tizen_app_id = tizenId;
          cloned.package_name = tizenId;
          verified.push(cloned);
        } catch (_) {
          // App not installed, skip
        }
      });

      console.log('[TizenDevice] Total verified installed apps on TV: ' + verified.length);
      return Promise.resolve(verified);
    },

    getInstalledApps: function (callback) {
      if (!this.isTizen) {
        if (typeof callback === 'function') callback([]);
        return;
      }
      try {
        tizen.application.getAppsInfo(
          function (apps) {
            console.log('[TizenDevice] Installed Tizen apps found: ' + apps.length);
            if (typeof callback === 'function') callback(apps);
          },
          function (err) {
            console.warn('[TizenDevice] getAppsInfo failed:', err);
            if (typeof callback === 'function') callback([]);
          }
        );
      } catch (e) {
        console.warn('[TizenDevice] getAppsInfo exception:', e);
        if (typeof callback === 'function') callback([]);
      }
    },

    /**
     * Exit Tizen Application
     */
    exitApp: function () {
      try {
        tizen.application.getCurrentApplication().exit();
      } catch (e) {
        console.warn('[TizenDevice] Exit failed:', e);
        if (typeof window.close === 'function') {
          window.close();
        }
      }
    }
  };

  TizenDevice.init();

  // Expose as both TizenDevice AND WebOSDevice for compatibility
  // (app.js references window.WebOSDevice)
  window.TizenDevice = TizenDevice;
  window.WebOSDevice = TizenDevice;
})(window);
