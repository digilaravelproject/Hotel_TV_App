/**
 * PAX TV Hospitality - Centralized API Service for Samsung Tizen TV
 * Handles Laravel Backend API endpoints:
 * - /api/tv/login
 * - /api/tv/generate-pair-code
 * - /api/tv/pair-status
 * - /api/tv/template/check-version
 */

(function (window) {
  'use strict';

  var STORAGE_KEYS = {
    TOKEN: 'pax_tv_token',
    LOGIN_DATA: 'pax_tv_login_data',
    DEVICE_ID: 'pax_tv_device_id',
    TEMPLATE_VERSION: 'pax_tv_template_version',
    // Universal keys used across Flutter & HTML5 template
    AUTH_TOKEN: 'authToken',
    CACHED_HOTEL_DATA: 'cachedHotelData',
    FLUTTER_DATA: 'tv_login_data'
  };

  var ApiService = {
    baseUrl: 'https://paxtvhospitality.paxtvnetwork.com',
    timeoutMs: 8000,

    /**
     * Get or generate a persistent Device ID
     */
    getDeviceId: function () {
      var id = localStorage.getItem(STORAGE_KEYS.DEVICE_ID);
      if (!id) {
        // Generate pseudo-unique hardware signature for Samsung Tizen TV
        var rand = Math.random().toString(36).substring(2, 10).toUpperCase();
        var time = Date.now().toString(36).toUpperCase();
        id = 'SAMSUNG-TV-' + time + '-' + rand;
        localStorage.setItem(STORAGE_KEYS.DEVICE_ID, id);
      }
      return id;
    },

    /**
     * Stored Bearer Auth Token
     */
    getToken: function () {
      return localStorage.getItem(STORAGE_KEYS.TOKEN) ||
        localStorage.getItem(STORAGE_KEYS.AUTH_TOKEN) ||
        '';
    },

    setToken: function (token) {
      if (token) {
        localStorage.setItem(STORAGE_KEYS.TOKEN, token);
        localStorage.setItem(STORAGE_KEYS.AUTH_TOKEN, token);
        localStorage.setItem('token', token);
      } else {
        localStorage.removeItem(STORAGE_KEYS.TOKEN);
        localStorage.removeItem(STORAGE_KEYS.AUTH_TOKEN);
        localStorage.removeItem('token');
      }
    },

    /**
     * Stored Hotel & Device Data
     */
    getLoginData: function () {
      try {
        var str = localStorage.getItem(STORAGE_KEYS.LOGIN_DATA) ||
          localStorage.getItem(STORAGE_KEYS.FLUTTER_DATA);
        return str ? JSON.parse(str) : null;
      } catch (e) {
        console.error('[ApiService] Error parsing stored login data:', e);
        return null;
      }
    },

    setLoginData: function (data) {
      if (!data) {
        localStorage.removeItem(STORAGE_KEYS.LOGIN_DATA);
        localStorage.removeItem(STORAGE_KEYS.CACHED_HOTEL_DATA);
        localStorage.removeItem(STORAGE_KEYS.FLUTTER_DATA);
        window.tvLoginData = null;
        if (window.parent) window.parent.tvLoginData = null;
        return;
      }
      try {
        var dataStr = JSON.stringify(data);
        localStorage.setItem(STORAGE_KEYS.LOGIN_DATA, dataStr);
        localStorage.setItem(STORAGE_KEYS.FLUTTER_DATA, dataStr);

        // Extract raw hotel payload for template dataService
        var configPayload = (data.data && (data.data.hotel || data.data.device)) ? (data.data || data) : data;
        localStorage.setItem(STORAGE_KEYS.CACHED_HOTEL_DATA, JSON.stringify(configPayload));

        // Set live window variable for instantaneous template consumption
        window.tvLoginData = data;
        if (window.parent) window.parent.tvLoginData = data;
      } catch (e) {
        console.error('[ApiService] Error saving login data:', e);
      }
    },

    getTemplateVersion: function () {
      return localStorage.getItem(STORAGE_KEYS.TEMPLATE_VERSION) || '0.0.0';
    },

    setTemplateVersion: function (ver) {
      if (ver) {
        localStorage.setItem(STORAGE_KEYS.TEMPLATE_VERSION, String(ver));
      }
    },

    isLoggedIn: function () {
      var token = this.getToken();
      var data = this.getLoginData();
      return Boolean(token && data);
    },

    hasValidSession: function () {
      return this.isLoggedIn();
    },

    logout: function () {
      localStorage.removeItem(STORAGE_KEYS.TOKEN);
      localStorage.removeItem(STORAGE_KEYS.AUTH_TOKEN);
      localStorage.removeItem('token');
      localStorage.removeItem(STORAGE_KEYS.LOGIN_DATA);
      localStorage.removeItem(STORAGE_KEYS.CACHED_HOTEL_DATA);
      localStorage.removeItem(STORAGE_KEYS.FLUTTER_DATA);
      localStorage.removeItem(STORAGE_KEYS.TEMPLATE_VERSION);
      window.tvLoginData = null;
      if (window.parent) window.parent.tvLoginData = null;
    },

    /**
     * Core Fetch Wrapper with timeout and headers
     */
    request: function (endpoint, options) {
      options = options || {};
      var url = this.baseUrl + endpoint;
      var method = (options.method || 'GET').toUpperCase();
      var headers = options.headers || {};

      headers['Accept'] = 'application/json';
      if (method === 'POST' || method === 'PUT') {
        headers['Content-Type'] = 'application/json';
      }

      var token = this.getToken();
      if (token && !headers['Authorization']) {
        headers['Authorization'] = 'Bearer ' + token;
      }

      return new Promise(function (resolve) {
        try {
          var xhr = new XMLHttpRequest();
          xhr.open(method, url, true);
          xhr.timeout = 5000;
          for (var h in headers) {
            if (headers.hasOwnProperty(h)) {
              xhr.setRequestHeader(h, headers[h]);
            }
          }
          xhr.onload = function () {
            try {
              var json = JSON.parse(xhr.responseText);
              resolve({
                ok: xhr.status >= 200 && xhr.status < 300,
                status: xhr.status,
                data: json
              });
            } catch (_) {
              resolve({
                ok: xhr.status >= 200 && xhr.status < 300,
                status: xhr.status,
                data: null
              });
            }
          };
          xhr.onerror = function () {
            resolve({ ok: false, status: 0, error: 'Network error' });
          };
          xhr.ontimeout = function () {
            resolve({ ok: false, status: 0, error: 'Request timed out' });
          };
          xhr.send(options.body ? JSON.stringify(options.body) : null);
        } catch (err) {
          resolve({ ok: false, status: 0, error: err.message || 'XHR exception' });
        }
      });
    },

    /**
     * Generate Pair Code for QR Pairing screen
     */
    generatePairCode: function (deviceInfo) {
      deviceInfo = deviceInfo || {};
      var payload = {
        deviceId: deviceInfo.deviceId || this.getDeviceId(),
        macAddress: deviceInfo.macAddress || '4A:2D:A4:DF:D7:89',
        ipAddress: deviceInfo.ipAddress || '192.168.1.100',
        model: deviceInfo.model || 'Samsung Smart TV',
        brand: 'Samsung',
        osVersion: deviceInfo.osVersion || 'Tizen 5.5'
      };

      return this.request('/api/tv/generate-pair-code', {
        method: 'POST',
        body: payload
      });
    },

    /**
     * Check Pair Code Status (polling every 3s)
     */
    checkPairStatus: function (pairCode, deviceId) {
      var payload = {
        pair_code: pairCode,
        deviceId: deviceId || this.getDeviceId()
      };

      return this.request('/api/tv/pair-status', {
        method: 'POST',
        body: payload
      });
    },

    /**
     * Manual Sign in with Remote (License Key + Room No)
     */
    loginWithCredentials: function (licenseKey, roomNo, deviceInfo) {
      deviceInfo = deviceInfo || {};
      var payload = {
        license_key: licenseKey,
        room_no: roomNo,
        deviceId: deviceInfo.deviceId || this.getDeviceId(),
        macAddress: deviceInfo.macAddress || '4A:2D:A4:DF:D7:89',
        ipAddress: deviceInfo.ipAddress || '192.168.1.100',
        model: deviceInfo.model || 'Samsung Smart TV',
        brand: 'Samsung',
        osVersion: deviceInfo.osVersion || 'Tizen 5.5'
      };

      return this.request('/api/tv/login', {
        method: 'POST',
        body: payload
      });
    },

    /**
     * Check Template & Data updates silently
     */
    checkTemplateVersion: function () {
      return this.request('/api/tv/template/check-version', {
        method: 'GET'
      });
    },

    /**
     * Load Fallback local data.json when offline
     */
    loadFallbackData: function () {
      return fetch('assets/data.json')
        .then(function (res) { return res.json(); })
        .catch(function (e) {
          console.error('[ApiService] Failed to load local assets/data.json fallback:', e);
          return null;
        });
    }
  };

  window.ApiService = ApiService;
})(window);
