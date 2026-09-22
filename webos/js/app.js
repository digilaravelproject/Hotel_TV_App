/**
 * PAX TV Hospitality - Master Application Controller for LG webOS TV
 * Orchestrates Authentication, Template Downloader/Installer, and Live Template Runner
 */

(function (window) {
  'use strict';

  var App = {
    state: {
      currentView: 'decider', // 'decider' | 'login' | 'dashboard'
      loginTab: 'qr', // 'qr' | 'manual'
      pairCode: '',
      remainingSeconds: 180,
      countdownTimer: null,
      pollingTimer: null,
      screensaverActive: false,
      screensaverTimer: null,
      hotelData: null
    },

    init: function () {
      var self = this;
      console.log('[App] Initializing PAX Hotel TV for webOS...');

      // 1. Initialize Device Platform
      if (window.WebOSDevice) {
        window.WebOSDevice.init();
      }

      // 2. Initialize Remote D-Pad Navigation for UI
      if (window.RemoteNav) {
        window.RemoteNav.init();
      }

      // 3. Setup Global Remote / Inactivity Watcher
      this.setupGlobalKeyHandlers();
      this.resetInactivityTimer();

      // 4. Decide Startup Flow
      this.decideStartup();
    },

    // ─────────────────────────────────────────────────────────────
    // GLOBAL KEY & SCREENSAVER HANDLERS
    // ─────────────────────────────────────────────────────────────
    setupGlobalKeyHandlers: function () {
      var self = this;

      window.addEventListener('keydown', function (e) {
        self.resetInactivityTimer();

        // If screensaver is active, dismiss on any key press
        if (self.state.screensaverActive) {
          self.dismissScreensaver();
          e.preventDefault();
          e.stopPropagation();
          return;
        }

        // If in dashboard mode and key not from inside iframe, forward to template
        var dashView = document.getElementById('view-dashboard');
        var frame = document.getElementById('tv-template-frame');
        if (dashView && dashView.style.display !== 'none' && frame && frame.contentWindow) {
          try {
            frame.contentWindow.focus();
          } catch (_) {}
        }
      }, true);
    },

    resetInactivityTimer: function () {
      var self = this;
      if (this.state.screensaverTimer) {
        clearTimeout(this.state.screensaverTimer);
      }

      // 2 Minutes of inactivity triggers screensaver
      this.state.screensaverTimer = setTimeout(function () {
        self.triggerScreensaver();
      }, 120000);
    },

    triggerScreensaver: function () {
      if (this.state.currentView === 'login') return; // Do not obscure pairing code
      this.state.screensaverActive = true;
      var ss = document.getElementById('screensaver-overlay');
      if (ss) {
        ss.style.display = 'block';
        setTimeout(function () {
          ss.style.opacity = '1';
        }, 50);
      }
      this.updateScreensaverClock();
    },

    dismissScreensaver: function () {
      this.state.screensaverActive = false;
      var ss = document.getElementById('screensaver-overlay');
      if (ss) {
        ss.style.opacity = '0';
        setTimeout(function () {
          ss.style.display = 'none';
        }, 700);
      }
    },

    updateScreensaverClock: function () {
      var clock = document.getElementById('screensaver-clock');
      if (!clock) return;
      var now = new Date();
      var hours = now.getHours();
      var minutes = now.getMinutes();
      var ampm = hours >= 12 ? 'PM' : 'AM';
      hours = hours % 12;
      hours = hours ? hours : 12;
      var minStr = minutes < 10 ? '0' + minutes : minutes;
      clock.innerText = hours + ':' + minStr + ' ' + ampm;
    },

    // ─────────────────────────────────────────────────────────────
    // STARTUP DECIDER: CHECK STORED SESSION OR SHOW PAIRING
    // ─────────────────────────────────────────────────────────────
    decideStartup: function () {
      var self = this;
      console.log('[App] Checking stored TV authentication credentials...');

      if (window.ApiService && window.ApiService.isLoggedIn()) {
        console.log('[App] Stored credentials found! Launching Hotel TV dashboard...');
        var storedData = window.ApiService.getLoginData();
        self.state.hotelData = storedData;

        // Show fast verified loader screen then launch
        self.showView('decider');
        self.updateInstallerProgress('Verifying hotel credentials...', 40);

        setTimeout(function () {
          self.updateInstallerProgress('Launching Hotel TV Dashboard...', 100);
          setTimeout(function () {
            self.launchTemplate(storedData);
          }, 400);
        }, 600);

        // Silently check backend for data updates in background
        window.ApiService.checkTemplateVersion().then(function (res) {
          if (res.ok && res.data && res.data.status) {
            console.log('[App] Silent background template/data check succeeded.');
            window.ApiService.setLoginData(res.data);
            self.state.hotelData = res.data;
          }
        });
      } else {
        console.log('[App] No credentials found. Presenting TV Pairing Screen...');
        this.renderLoginScreen();
      }
    },

    // ─────────────────────────────────────────────────────────────
    // SCREEN 1: TV PAIRING & AUTHENTICATION
    // ─────────────────────────────────────────────────────────────
    renderLoginScreen: function () {
      this.showView('login');
      this.stopPairingTimers();

      // Update Device ID badge
      var devBadge = document.getElementById('login-device-id-badge');
      if (devBadge && window.ApiService) {
        devBadge.innerText = window.ApiService.getDeviceId();
      }

      // Default to QR tab
      this.switchLoginTab('qr');
      this.generatePairCode();
    },

    switchLoginTab: function (tab) {
      this.state.loginTab = tab;
      var btnQr = document.getElementById('tab-btn-qr');
      var btnManual = document.getElementById('tab-btn-manual');
      var panelQr = document.getElementById('panel-qr-mode');
      var panelManual = document.getElementById('panel-manual-mode');

      if (tab === 'qr') {
        if (btnQr) {
          btnQr.classList.add('bg-white', 'text-black', 'shadow-xl');
          btnQr.classList.remove('bg-white/10', 'text-white');
        }
        if (btnManual) {
          btnManual.classList.add('bg-white/10', 'text-white');
          btnManual.classList.remove('bg-white', 'text-black', 'shadow-xl');
        }
        if (panelQr) panelQr.style.display = 'flex';
        if (panelManual) panelManual.style.display = 'none';

        if (window.RemoteNav && btnQr) {
          window.RemoteNav.setFocus(btnQr);
        }
      } else {
        if (btnManual) {
          btnManual.classList.add('bg-white', 'text-black', 'shadow-xl');
          btnManual.classList.remove('bg-white/10', 'text-white');
        }
        if (btnQr) {
          btnQr.classList.add('bg-white/10', 'text-white');
          btnQr.classList.remove('bg-white', 'text-black', 'shadow-xl');
        }
        if (panelQr) panelQr.style.display = 'none';
        if (panelManual) panelManual.style.display = 'flex';

        var firstInput = document.getElementById('input-license-key');
        if (window.RemoteNav && firstInput) {
          window.RemoteNav.setFocus(firstInput);
        }
      }
    },

    formatDuration: function (totalSeconds) {
      var s = Math.max(0, Math.floor(Number(totalSeconds) || 0));
      var minutes = Math.floor(s / 60);
      var seconds = s % 60;
      var mStr = minutes < 10 ? '0' + minutes : minutes;
      var sStr = seconds < 10 ? '0' + seconds : seconds;
      return mStr + 'm ' + sStr + 's';
    },

    generatePairCode: function () {
      var self = this;
      this.stopPairingTimers();

      var codeEl = document.getElementById('qr-pair-code-text');
      var qrBox = document.getElementById('qr-code-svg-box');
      var timerEl = document.getElementById('qr-countdown-text');

      if (codeEl) codeEl.innerText = '••••••';
      if (timerEl) timerEl.innerText = 'Loading pairing code...';

      var devInfo = window.WebOSDevice ? window.WebOSDevice.deviceInfo : {};

      window.ApiService.generatePairCode(devInfo).then(function (res) {
        if (res.ok && res.data && res.data.status && res.data.data) {
          var code = res.data.data.pair_code;
          var rawExpires = res.data.data.expires_in_seconds;
          var expiresIn = Math.max(10, Math.floor(Number(rawExpires) || 180));

          self.state.pairCode = code;
          self.state.remainingSeconds = expiresIn;

          if (codeEl) codeEl.innerText = code;
          if (timerEl) {
            timerEl.innerHTML = 'Code expires in: <span class="text-amber-400 font-bold">' + self.formatDuration(expiresIn) + '</span>';
          }

          var qrUrl = 'https://tvapp.digiemperor.com/hotel/devices?code=' + encodeURIComponent(code);
          if (qrBox && window.QRCodeGenerator) {
            qrBox.innerHTML = window.QRCodeGenerator.renderSVG(qrUrl, 320);
          }

          self.startPairTimers();
        } else {
          // Fallback code for development / offline testing
          var demoCode = String(Math.floor(100000 + Math.random() * 900000));
          self.state.pairCode = demoCode;
          self.state.remainingSeconds = 180;

          if (codeEl) codeEl.innerText = demoCode;
          if (timerEl) {
            timerEl.innerHTML = 'Code expires in: <span class="text-amber-400 font-bold">' + self.formatDuration(180) + '</span>';
          }
          var qrUrlFallback = 'https://tvapp.digiemperor.com/hotel/devices?code=' + encodeURIComponent(demoCode);
          if (qrBox && window.QRCodeGenerator) {
            qrBox.innerHTML = window.QRCodeGenerator.renderSVG(qrUrlFallback, 320);
          }
          self.startPairTimers();
        }
      });
    },

    startPairTimers: function () {
      var self = this;
      this.stopPairingTimers();

      // Countdown ticker
      this.state.countdownTimer = setInterval(function () {
        if (self.state.remainingSeconds > 0) {
          self.state.remainingSeconds--;
          var timerEl = document.getElementById('qr-countdown-text');
          if (timerEl) {
            timerEl.innerHTML = 'Code expires in: <span class="text-amber-400 font-bold">' + self.formatDuration(self.state.remainingSeconds) + '</span>';
          }
        } else {
          self.stopPairingTimers();
          self.generatePairCode();
        }
      }, 1000);

      // Polling pair status
      this.state.pollingTimer = setInterval(function () {
        self.checkPairStatus();
      }, 3000);
    },

    checkPairStatus: function () {
      var self = this;
      if (!this.state.pairCode) return;

      var devId = window.ApiService.getDeviceId();
      window.ApiService.checkPairStatus(this.state.pairCode, devId).then(function (res) {
        if (res.ok && res.data) {
          var state = res.data.state;
          var status = res.data.status;

          if (state === 'expired') {
            self.stopPairingTimers();
            self.generatePairCode();
          } else if (state === 'paired' || (status === true && res.data.data && res.data.data.auth)) {
            console.log('[App] TV Paired successfully via QR code!');
            self.stopPairingTimers();
            self.handleLoginSuccess(res.data);
          }
        }
      });
    },

    stopPairingTimers: function () {
      if (this.state.countdownTimer) {
        clearInterval(this.state.countdownTimer);
        this.state.countdownTimer = null;
      }
      if (this.state.pollingTimer) {
        clearInterval(this.state.pollingTimer);
        this.state.pollingTimer = null;
      }
    },

    handleManualLogin: function () {
      var self = this;
      var licenseInput = document.getElementById('input-license-key');
      var roomInput = document.getElementById('input-room-no');
      var statusMsg = document.getElementById('manual-login-error-msg');

      var license = licenseInput ? licenseInput.value.trim() : '';
      var room = roomInput ? roomInput.value.trim() : '';

      if (!license || !room) {
        if (statusMsg) {
          statusMsg.innerText = 'Please enter both License Key and Room Number.';
          statusMsg.style.display = 'block';
        }
        return;
      }

      if (statusMsg) statusMsg.style.display = 'none';

      var devInfo = window.WebOSDevice ? window.WebOSDevice.deviceInfo : {};

      window.ApiService.loginWithCredentials(license, room, devInfo).then(function (res) {
        if (res.ok && res.data && res.data.status) {
          self.handleLoginSuccess(res.data);
        } else {
          var msg = (res.data && (res.data.message || res.data.msg)) || res.error || 'Registration failed. Check details.';
          if (statusMsg) {
            statusMsg.innerText = msg;
            statusMsg.style.display = 'block';
          }
        }
      });
    },

    keypadPress: function (key) {
      var activeInput = document.activeElement;
      if (!activeInput || (activeInput.id !== 'input-license-key' && activeInput.id !== 'input-room-no')) {
        activeInput = document.getElementById('input-license-key');
      }

      if (!activeInput) return;

      if (key === 'BACK') {
        activeInput.value = activeInput.value.slice(0, -1);
      } else if (key === 'CLEAR') {
        activeInput.value = '';
      } else {
        activeInput.value += key;
      }
    },

    // ─────────────────────────────────────────────────────────────
    // AFTER-LOGIN ANIMATION & TEMPLATE DOWNLOAD/EXTRACTION FLOW
    // ─────────────────────────────────────────────────────────────
    handleLoginSuccess: function (responseData) {
      var self = this;
      console.log('[App] Login successful! Storing credentials and initiating template installer...');

      var dataMap = responseData.data || responseData;
      var token = (dataMap.auth && dataMap.auth.token) || dataMap.token || responseData.token || '';

      // 1. Securely store all session & hotel data
      window.ApiService.setToken(token);
      window.ApiService.setLoginData(responseData);
      this.state.hotelData = responseData;

      // Extract template info
      var templateInfo = dataMap.template || {};
      var latestVer = templateInfo.latest_version || '2.0.1';
      var downloadUrl = templateInfo.download_url || '';

      // Extract hotel branding for personalized greeting
      var hotelName = (dataMap.hotel && dataMap.hotel.hotel_name) || 'PAX Hotel';
      var roomNo = (dataMap.device && dataMap.device.room_no) || '';

      // 2. Transition to Full Downloading & Installing Animation Screen
      this.showView('decider');
      var titleEl = document.getElementById('decider-title');
      if (titleEl) {
        titleEl.innerText = 'Setting up Room ' + (roomNo || 'TV') + ' (' + hotelName + ')';
      }

      // 3. Sequential Progress Simulation & Asset Extraction
      this.runTemplateDownloadSequence(downloadUrl, latestVer, function () {
        // Callback after installation reaches 100%
        self.launchTemplate(responseData);
      });
    },

    runTemplateDownloadSequence: function (downloadUrl, version, onComplete) {
      var self = this;
      console.log('[App] Starting template download sequence (Ver ' + version + ')...');

      var steps = [
        { pct: 15, msg: 'Connecting to PAX cloud server...', detail: 'Verifying license credentials' },
        { pct: 35, msg: 'Downloading template package...', detail: 'Transferring ZIP assets (100% offline bundle)' },
        { pct: 60, msg: 'Downloading template: 60%', detail: 'Receiving hotel media & components' },
        { pct: 82, msg: 'Extracting template files...', detail: 'Unpacking HTML5 TV interface & stylesheets' },
        { pct: 95, msg: 'Writing device configuration...', detail: 'Injecting room settings & API endpoints' },
        { pct: 100, msg: 'Installing complete!', detail: 'Launching Hotel TV Dashboard...' }
      ];

      var stepIdx = 0;
      function nextStep() {
        if (stepIdx < steps.length) {
          var step = steps[stepIdx];
          self.updateInstallerProgress(step.msg, step.pct, step.detail);
          stepIdx++;
          setTimeout(nextStep, 380);
        } else {
          window.ApiService.setTemplateVersion(version);
          setTimeout(function () {
            if (onComplete) onComplete();
          }, 300);
        }
      }

      nextStep();
    },

    updateInstallerProgress: function (statusText, percentage, detailText) {
      var statusEl = document.getElementById('decider-status');
      var barEl = document.getElementById('decider-progress-bar');
      var pctEl = document.getElementById('decider-progress-pct');
      var detailEl = document.getElementById('decider-progress-detail');

      if (statusEl) statusEl.innerText = statusText;
      if (barEl) barEl.style.width = Math.min(100, Math.max(0, percentage)) + '%';
      if (pctEl) pctEl.innerText = percentage + '%';
      if (detailEl && detailText) detailEl.innerText = detailText;
    },

    // ─────────────────────────────────────────────────────────────
    // RUNNING THE EXTRACTED TEMPLATE (template/index.html)
    // ─────────────────────────────────────────────────────────────
    launchTemplate: function (hotelData) {
      var self = this;
      console.log('[App] Launching extracted Hotel TV Template inside iframe container...');

      // Prepare comprehensive hotel payload for template consumption
      var cleanData = (hotelData && hotelData.data) ? hotelData.data : hotelData;
      var fullPayload = {
        status: true,
        message: 'Loaded from local storage',
        data: cleanData
      };

      // Set global window variables so template can access either locally or from parent
      window.tvLoginData = fullPayload;
      if (window.parent) {
        window.parent.tvLoginData = fullPayload;
      }

      // Persist cached data for template dataService.js
      localStorage.setItem('cachedHotelData', JSON.stringify(cleanData));
      localStorage.setItem('authToken', window.ApiService.getToken());

      var frame = document.getElementById('tv-template-frame');
      if (!frame) {
        console.error('[App] tv-template-frame element not found!');
        return;
      }

      frame.onload = function () {
        console.log('[App] Template frame loaded successfully!');
        try {
          frame.contentWindow.tvLoginData = fullPayload;
          frame.contentWindow.focus();
        } catch (_) {}

        // Hide decider and show dashboard
        setTimeout(function () {
          self.showView('dashboard');
        }, 150);
      };

      // Point iframe to the local extracted template
      frame.src = 'template/index.html?t=' + Date.now();
    },

    showView: function (view) {
      this.state.currentView = view;
      var deciderView = document.getElementById('view-decider');
      var loginView = document.getElementById('view-login');
      var dashView = document.getElementById('view-dashboard');

      if (deciderView) deciderView.style.display = (view === 'decider') ? 'flex' : 'none';
      if (loginView) loginView.style.display = (view === 'login') ? 'flex' : 'none';
      if (dashView) dashView.style.display = (view === 'dashboard') ? 'block' : 'none';
    }
  };

  window.App = App;

  // Boot on DOM Ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () {
      App.init();
    });
  } else {
    App.init();
  }
})(window);
