/**
 * PAX TV Hospitality - webOS Device & Luna Service Adapter
 * Interfaces with LG webOS platform Luna Bus via webOSTV.js
 * Falls back gracefully when running in developer browser mode.
 */

(function (window) {
  'use strict';

  var WebOSDevice = {
    isWebOS: false,
    deviceInfo: {
      deviceId: '',
      macAddress: '00:E0:91:AA:BB:CC',
      ipAddress: '192.168.1.150',
      model: 'LG webOS Smart TV',
      brand: 'LG',
      osVersion: 'webOS 6.0',
      networkState: 'connected'
    },

    init: function () {
      this.isWebOS = typeof window.webOS !== 'undefined' && typeof window.webOS.service !== 'undefined';
      this.deviceInfo.deviceId = window.ApiService ? window.ApiService.getDeviceId() : 'LG-TV-' + Date.now();

      if (this.isWebOS) {
        console.log('[WebOSDevice] Running natively on LG webOS platform');
        this._querySystemInfo();
        this._queryNetworkInfo();
      } else {
        console.log('[WebOSDevice] Running in Web/Emulator Browser Fallback mode');
        this._detectBrowserInfo();
      }
    },

    _detectBrowserInfo: function () {
      var ua = navigator.userAgent;
      if (ua.indexOf('Web0S') !== -1 || ua.indexOf('webOS') !== -1) {
        this.deviceInfo.model = 'LG Smart TV (webOS Web Engine)';
      } else if (ua.indexOf('Chrome') !== -1) {
        this.deviceInfo.model = 'Chrome TV Simulator';
      }
    },

    _querySystemInfo: function () {
      var self = this;
      try {
        window.webOS.service.request('luna://com.webos.service.tv.systemproperty', {
          method: 'getSystemInfo',
          parameters: {
            keys: ['modelName', 'firmwareVersion', 'UHD', 'sdkVersion']
          },
          onSuccess: function (res) {
            if (res.modelName) self.deviceInfo.model = res.modelName;
            if (res.firmwareVersion) self.deviceInfo.osVersion = 'webOS ' + res.firmwareVersion;
            console.log('[WebOSDevice] System info fetched:', res);
          },
          onFailure: function (err) {
            console.warn('[WebOSDevice] Failed to get system info:', err);
          }
        });
      } catch (e) {
        console.warn('[WebOSDevice] Luna systemproperty request failed:', e);
      }
    },

    _queryNetworkInfo: function () {
      var self = this;
      try {
        window.webOS.service.request('luna://com.webos.service.connectionmanager', {
          method: 'getStatus',
          parameters: {},
          onSuccess: function (res) {
            if (res.isInternetConnectionAvailable) {
              self.deviceInfo.networkState = 'connected';
            }
            if (res.wired && res.wired.state === 'connected') {
              self.deviceInfo.ipAddress = res.wired.ipAddress || self.deviceInfo.ipAddress;
              self.deviceInfo.macAddress = res.wired.macAddress || self.deviceInfo.macAddress;
            } else if (res.wifi && res.wifi.state === 'connected') {
              self.deviceInfo.ipAddress = res.wifi.ipAddress || self.deviceInfo.ipAddress;
              self.deviceInfo.macAddress = res.wifi.macAddress || self.deviceInfo.macAddress;
            }
            console.log('[WebOSDevice] Network info fetched:', res);
          },
          onFailure: function (err) {
            console.warn('[WebOSDevice] Failed to get network status:', err);
          }
        });
      } catch (e) {
        console.warn('[WebOSDevice] Luna connectionmanager request failed:', e);
      }
    },

    /**
     * Map common Android package names or aliases to LG webOS App IDs
     */
    mapToWebOsAppId: function (idOrPkg) {
      if (!idOrPkg) return '';
      var cleaned = String(idOrPkg).toLowerCase().trim();
      var appMap = {
        'com.google.android.youtube.tv': 'youtube.leanback.v4',
        'com.google.android.youtube': 'youtube.leanback.v4',
        'youtube': 'youtube.leanback.v4',
        'com.netflix.ninja': 'netflix',
        'com.netflix.mediaclient': 'netflix',
        'netflix': 'netflix',
        'com.amazon.amazonvideo.livingroom': 'amazon',
        'com.amazon.avod.thirdpartyclient': 'amazon',
        'amazon': 'amazon',
        'prime': 'amazon',
        'primevideo': 'amazon',
        'in.startv.hotstar': 'hotstar',
        'hotstar': 'hotstar',
        'disney': 'hotstar',
        'com.graymatrix.did': 'zee5',
        'zee5': 'zee5',
        'com.sony.liv': 'sonyliv',
        'sonyliv': 'sonyliv',
        'com.jio.media.ondemand': 'jiocinema',
        'jiocinema': 'jiocinema',
        'livetv': 'com.webos.app.livetv',
        'live_tv': 'com.webos.app.livetv'
      };
      return appMap[cleaned] || idOrPkg;
    },

    /**
     * Launch OTT application (e.g. YouTube, Netflix) installed on LG webOS
     */
    launchApp: function (appId, params) {
      var targetId = this.mapToWebOsAppId(appId);
      console.log('[WebOSDevice] Requesting app launch for: ' + appId + ' -> ' + targetId);

      if (!this.isWebOS) {
        console.log('[WebOSDevice] Simulating launching app: ' + targetId);
        return;
      }
      try {
        window.webOS.service.request('luna://com.webos.applicationManager', {
          method: 'launch',
          parameters: {
            id: targetId,
            params: params || {}
          },
          onSuccess: function () {
            console.log('[WebOSDevice] App launched successfully: ' + targetId);
          },
          onFailure: function (err) {
            console.warn('[WebOSDevice] Failed to launch app ' + targetId + ':', err);
          }
        });
      } catch (e) {
        console.error('[WebOSDevice] Error requesting application launch:', e);
      }
    },

    /**
     * Launch Native LG Live TV
     */
    launchLiveTv: function () {
      console.log('[WebOSDevice] Launching native Live TV...');
      this.launchApp('com.webos.app.livetv');
    },

    /**
     * Switch Hardware TV Input (HDMI 1, HDMI 2, AV, etc.)
     */
    switchInput: function (portId) {
      console.log('[WebOSDevice] Switching hardware TV input to:', portId);
      var p = (portId || '').toUpperCase().trim();

      if (p.includes('HDMI_1') || p === 'HDMI 1') {
        this.launchApp('com.webos.app.hdmi1');
      } else if (p.includes('HDMI_2') || p === 'HDMI 2') {
        this.launchApp('com.webos.app.hdmi2');
      } else if (p.includes('HDMI_3') || p === 'HDMI 3') {
        this.launchApp('com.webos.app.hdmi3');
      } else if (p.includes('HDMI_4') || p === 'HDMI 4') {
        this.launchApp('com.webos.app.hdmi4');
      } else if (p.includes('TUNER') || p.includes('LIVE') || p.includes('ANTENNA')) {
        this.launchLiveTv();
      } else {
        // Fallback: Luna externalinput service
        try {
          if (this.isWebOS) {
            window.webOS.service.request('luna://com.webos.service.tv.externalinput', {
              method: 'setCurrentInput',
              parameters: { inputId: portId },
              onSuccess: function () {
                console.log('[WebOSDevice] setCurrentInput succeeded for: ' + portId);
              },
              onFailure: function (e) {
                console.warn('[WebOSDevice] setCurrentInput failed, trying app launcher:', e);
                WebOSDevice.launchApp('com.webos.app.hdmi1');
              }
            });
          }
        } catch (_) {
          this.launchApp('com.webos.app.hdmi1');
        }
      }
    },

    /**
     * Query all installed applications from LG webOS applicationManager
     */
    
    /**
     * Check if a single app is installed on webOS TV using getAppLoadStatus
     */
    isAppInstalled: function (appId, callback) {
      var self = this;
      var targetId = self.mapToWebOsAppId(appId);
      if (!self.isWebOS || !window.webOS || !window.webOS.service) {
        if (typeof callback === 'function') callback(false, targetId);
        return;
      }
      try {
        window.webOS.service.request('luna://com.webos.applicationManager', {
          method: 'getAppLoadStatus',
          parameters: { id: targetId },
          onSuccess: function (res) {
            var exists = Boolean(res && (res.exist === true || res.installed === true));
            if (typeof callback === 'function') callback(exists, targetId, res);
          },
          onFailure: function (err) {
            if (typeof callback === 'function') callback(false, targetId, err);
          }
        });
      } catch (e) {
        if (typeof callback === 'function') callback(false, targetId, e);
      }
    },

    /**
     * Filter server configured app list and return ONLY those apps that are actually installed on this webOS TV.
     * Android-only apps (like Google Play Store) are permanently omitted.
     * @param {Array<Object>} appList
     * @returns {Promise<Array<Object>>}
     */
    

    /**
     * Map app to candidate webOS IDs
     */
    getWebOsCandidates: function (idOrPkg) {
      if (!idOrPkg) return [];
      var cleaned = String(idOrPkg).toLowerCase().trim();
      if (cleaned.includes('vending') || cleaned.includes('playstore') || cleaned.includes('play store') || cleaned.includes('google play')) {
        return [];
      }
      var candidateMap = {
        'youtube': ['youtube.leanback.v4', 'youtube', 'com.webos.app.youtube'],
        'com.google.android.youtube.tv': ['youtube.leanback.v4', 'youtube', 'com.webos.app.youtube'],
        'com.google.android.youtube': ['youtube.leanback.v4', 'youtube', 'com.webos.app.youtube'],
        'netflix': ['netflix', 'com.webos.app.netflix'],
        'com.netflix.ninja': ['netflix', 'com.webos.app.netflix'],
        'com.netflix.mediaclient': ['netflix', 'com.webos.app.netflix'],
        'prime': ['amazon', 'com.amazon.app', 'com.webos.app.amazon'],
        'amazon': ['amazon', 'com.amazon.app', 'com.webos.app.amazon'],
        'primevideo': ['amazon', 'com.amazon.app', 'com.webos.app.amazon'],
        'com.amazon.amazonvideo.livingroom': ['amazon', 'com.amazon.app', 'com.webos.app.amazon'],
        'com.amazon.avod.thirdpartyclient': ['amazon', 'com.amazon.app', 'com.webos.app.amazon'],
        'zee5': ['zee5', 'com.zee5.webos', 'com.zee5.app', 'com.graymatrix.did', 'in.zee5.app', 'com.zee5.zee5'],
        'com.graymatrix.did': ['zee5', 'com.zee5.webos', 'com.zee5.app', 'com.graymatrix.did', 'in.zee5.app', 'com.zee5.zee5'],
        'hotstar': ['hotstar', 'in.startv.hotstar', 'com.hotstar.webos', 'com.disney.hotstar'],
        'in.startv.hotstar': ['hotstar', 'in.startv.hotstar', 'com.hotstar.webos', 'com.disney.hotstar'],
        'sonyliv': ['sonyliv', 'com.sony.liv', 'com.sonyliv.webos'],
        'com.sony.liv': ['sonyliv', 'com.sony.liv', 'com.sonyliv.webos'],
        'jiocinema': ['jiocinema', 'com.jio.media.ondemand', 'com.jio.jiocinema'],
        'com.jio.media.ondemand': ['jiocinema', 'com.jio.media.ondemand', 'com.jio.jiocinema'],
        'aha': ['aha', 'com.aha.webos', 'in.aha.video'],
        'sunnxt': ['sunnxt', 'com.sunnxt.webos', 'com.suntv.sunnxt'],
        'mxplayer': ['mxplayer', 'com.mxplayer.webos', 'com.mxtech.videoplayer.ad']
      };

      for (var key in candidateMap) {
        if (cleaned === key || cleaned.includes(key)) {
          return candidateMap[key];
        }
      }
      return [cleaned];
    },

    checkSingleAppInstalled: function (candidates, onResult) {
      if (!Array.isArray(candidates) || candidates.length === 0) {
        return onResult(false, null);
      }
      var self = this;
      var index = 0;

      function testNext() {
        if (index >= candidates.length) {
          return onResult(false, null);
        }
        var currentId = candidates[index];
        index++;

        try {
          window.webOS.service.request('luna://com.webos.applicationManager', {
            method: 'getAppLoadStatus',
            parameters: { appId: currentId, id: currentId },
            onSuccess: function (res) {
              var isInstalled = Boolean(res && (res.exist === true || res.installed === true));
              console.log('[WebOSDevice] Tested ' + currentId + ' -> ' + isInstalled, res);
              if (isInstalled) {
                return onResult(true, currentId);
              } else {
                testNext();
              }
            },
            onFailure: function (err) {
              console.log('[WebOSDevice] Tested ' + currentId + ' -> not installed:', err && err.errorText);
              testNext();
            }
          });
        } catch (e) {
          testNext();
        }
      }

      testNext();
    },

    /**
     * Filter server configured app list and return ONLY those apps that are actually installed on this webOS TV.
     * Android-only apps (like Google Play Store) are permanently omitted.
     * @param {Array<Object>} appList
     * @returns {Promise<Array<Object>>}
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

      if (!self.isWebOS || !window.webOS || !window.webOS.service) {
        return Promise.resolve(candidates);
      }

      var promises = candidates.map(function (app) {
        return new Promise(function (resolve) {
          var candList = self.getWebOsCandidates(app.package_name || app.id);
          if (candList.length === 0) {
            return resolve(null);
          }
          self.checkSingleAppInstalled(candList, function (installed, workingId) {
            if (installed) {
              var cloned = Object.assign({}, app);
              cloned.webos_app_id = workingId;
              cloned.package_name = workingId;
              resolve(cloned);
            } else {
              resolve(null);
            }
          });
        });
      });

      return Promise.all(promises).then(function (results) {
        var verified = results.filter(Boolean);
        console.log('[WebOSDevice] Total verified installed apps on TV: ' + verified.length);
        return verified;
      });
    },

    getInstalledApps: function (callback) {
      if (!this.isWebOS) {
        if (typeof callback === 'function') callback([]);
        return;
      }
      try {
        window.webOS.service.request('luna://com.webos.applicationManager', {
          method: 'listApps',
          parameters: {},
          onSuccess: function (res) {
            var apps = (res && res.apps) ? res.apps : [];
            console.log('[WebOSDevice] Installed webOS apps found: ' + apps.length);
            if (typeof callback === 'function') callback(apps);
          },
          onFailure: function (err) {
            console.warn('[WebOSDevice] listApps query failed:', err);
            if (typeof callback === 'function') callback([]);
          }
        });
      } catch (e) {
        console.warn('[WebOSDevice] listApps exception:', e);
        if (typeof callback === 'function') callback([]);
      }
    },

    /**
     * Exit webOS Application
     */
    exitApp: function () {
      if (typeof window.close === 'function') {
        window.close();
      } else if (window.webOS && typeof window.webOS.platformBack === 'function') {
        window.webOS.platformBack();
      }
    }
  };

  WebOSDevice.init();
  window.WebOSDevice = WebOSDevice;
})(window);
