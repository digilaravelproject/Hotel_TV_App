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
     * Launch OTT application (e.g. YouTube, Netflix) installed on LG webOS
     */
    launchApp: function (appId, params) {
      if (!this.isWebOS) {
        console.log('[WebOSDevice] Simulating launching app: ' + appId);
        alert('Simulating launch of application: ' + appId + '\n(On real LG TV, this launches the native webOS app)');
        return;
      }
      try {
        window.webOS.service.request('luna://com.webos.applicationManager', {
          method: 'launch',
          parameters: {
            id: appId,
            params: params || {}
          },
          onSuccess: function () {
            console.log('[WebOSDevice] App launched successfully: ' + appId);
          },
          onFailure: function (err) {
            console.warn('[WebOSDevice] Failed to launch app ' + appId + ':', err);
          }
        });
      } catch (e) {
        console.error('[WebOSDevice] Error requesting application launch:', e);
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
