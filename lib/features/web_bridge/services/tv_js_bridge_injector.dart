import 'package:webview_flutter/webview_flutter.dart';

class TvJsBridgeInjector {
  /// Injects core JavaScript polyfills, responsive canvas scaling, and TV remote navigation hooks
  static Future<void> injectPageFinishedScripts(WebViewController controller) async {
    await controller.runJavaScript('''
      (function() {
        try {
          // 1. Version override: Update static '6.0' to dynamic backend template version
          var verEl = document.getElementById('v-version');
          if (verEl) {
            var dataStr = localStorage.getItem('cachedHotelData') || (window.tvLoginData && JSON.stringify(window.tvLoginData));
            if (dataStr) {
              var parsed = JSON.parse(dataStr);
              var deviceObj = parsed.device || (parsed.data && parsed.data.device) || parsed;
              var templateObj = parsed.template || (parsed.data && parsed.data.template);
              var ver = (templateObj && templateObj.latest_version) || (deviceObj && (deviceObj.version || deviceObj.Ver)) || '';
              verEl.innerText = ver;
            } else {
              verEl.innerText = '';
            }
          }
        } catch(e) {}

        // 2. Injected TV navigation runtime helpers
        try {
          window.triggerTVBack = function() {
            try {
              if (window.tvAppInstance && typeof window.tvAppInstance.goBack === 'function') {
                return window.tvAppInstance.goBack() === true;
              }
              if (typeof window.onTVBack === 'function') {
                return window.onTVBack() === true;
              }
              if (typeof window.TVNavigation === 'object' && typeof window.TVNavigation.goBack === 'function') {
                window.TVNavigation.goBack();
                return true;
              }
            } catch(e) {}
            return false;
          };

          window.triggerTVHome = function() {
            try {
              if (window.tvAppInstance) {
                if (typeof window.tvAppInstance.stopInfoAutoSlide === 'function') {
                  window.tvAppInstance.stopInfoAutoSlide();
                }
                var wasNotHome = (window.tvAppInstance.currentView !== 'home') ||
                  (window.tvAppInstance.menuStack && window.tvAppInstance.menuStack.length > 0);
                window.tvAppInstance.currentView = 'home';
                window.tvAppInstance.menuStack = [];
                if (window.FlutterBridge && window.FlutterBridge.postMessage) {
                  window.FlutterBridge.postMessage(JSON.stringify({
                    method: 'onViewChanged',
                    args: ['home'],
                    id: 0
                  }));
                }
                if (window.tvAppInstance.menuItems) {
                  window.tvAppInstance.currentMenuList = window.tvAppInstance.menuItems;
                }
                window.tvAppInstance.activeMenuIndex = 0;
                return wasNotHome;
              }
            } catch(e) {}
            return false;
          };

          window.isTVAtHome = function() {
            try {
              if (window.tvAppInstance) {
                return window.tvAppInstance.currentView === 'home' &&
                  (!window.tvAppInstance.menuStack || window.tvAppInstance.menuStack.length === 0);
              }
            } catch(e) {}
            return true;
          };

          // 3. Force dismiss any stuck black loading overlays, ensure responsive canvas scaling
          var fixLayoutAndOverlay = function() {
            try {
              if (!String.prototype.padStart) {
                String.prototype.padStart = function(targetLength, padString) {
                  targetLength = targetLength >> 0;
                  padString = String(typeof padString !== 'undefined' ? padString : ' ');
                  if (this.length > targetLength) return String(this);
                  targetLength = targetLength - this.length;
                  if (targetLength > padString.length) {
                    padString += padString.repeat(targetLength / padString.length);
                  }
                  return padString.slice(0, targetLength) + String(this);
                };
              }

              var stuckOverlays = document.querySelectorAll('.z-50.bg-black, [class*="z-50"][class*="bg-black"]');
              stuckOverlays.forEach(function(el) {
                el.style.display = 'none';
                el.style.opacity = '0';
              });

              var canvas = document.getElementById('tv-canvas') || document.getElementById('app-canvas');
              if (canvas) {
                var w = window.innerWidth || (document.documentElement && document.documentElement.clientWidth) || window.screen.width || 1920;
                var h = window.innerHeight || (document.documentElement && document.documentElement.clientHeight) || window.screen.height || 1080;
                if (w <= 0) w = 1920;
                if (h <= 0) h = 1080;
                var scale = Math.min(w / 1920, h / 1080);
                if (scale > 0) {
                  canvas.style.transform = 'translate(-50%, -50%) scale(' + scale + ')';
                }
              }

              // View watcher for Flutter Demo Badge dynamic positioning
              if (window.tvAppInstance && !window._tvViewWatcherInstalled) {
                window._tvViewWatcherInstalled = true;
                var lastView = window.tvAppInstance.currentView || 'home';
                setInterval(function() {
                  try {
                    if (window.tvAppInstance && window.tvAppInstance.currentView) {
                      var cv = window.tvAppInstance.currentView;
                      if (cv !== lastView) {
                        lastView = cv;
                        if (window.FlutterBridge && window.FlutterBridge.postMessage) {
                          window.FlutterBridge.postMessage(JSON.stringify({
                            method: 'onViewChanged',
                            args: [cv],
                            id: 0
                          }));
                        }
                      }
                    }
                  } catch(err) {}
                }, 150);
              }
            } catch(e) {}
          };

          fixLayoutAndOverlay();
          setTimeout(fixLayoutAndOverlay, 300);
          setTimeout(fixLayoutAndOverlay, 800);
          setTimeout(fixLayoutAndOverlay, 1500);
          setTimeout(fixLayoutAndOverlay, 3000);
        } catch(e) {}
      })();
    ''');
  }

  /// Checks if JavaScript layer can navigate back within sub-view / sub-menu
  static Future<bool> handleJsBack(WebViewController controller) async {
    try {
      final Object? result = await controller.runJavaScriptReturningResult('''
        (function() {
          try {
            if (window.tvAppInstance) {
              if (window.tvAppInstance.currentView !== 'home') {
                if (typeof window.tvAppInstance.stopInfoAutoSlide === 'function') {
                  window.tvAppInstance.stopInfoAutoSlide();
                }
                window.tvAppInstance.currentView = 'home';
                window.tvAppInstance.menuStack = [];
                if (window.tvAppInstance.menuItems) {
                  window.tvAppInstance.currentMenuList = window.tvAppInstance.menuItems;
                }
                window.tvAppInstance.activeMenuIndex = 0;
                return true;
              }
              if (window.tvAppInstance.menuStack && window.tvAppInstance.menuStack.length > 0) {
                window.tvAppInstance.menuStack.pop();
                return true;
              }
              return false;
            }
            if (typeof window.triggerTVBack === 'function') {
              var r = window.triggerTVBack();
              if (r === true || r === 1 || r === 'true') return true;
            }
          } catch (e) {}
          return false;
        })();
      ''');
      return result == true || result == 'true' || result == 1 || result == '1';
    } catch (_) {
      return false;
    }
  }

  /// Checks if TV is currently at the Home view
  static Future<bool> isAtHome(WebViewController controller) async {
    try {
      final Object? result = await controller.runJavaScriptReturningResult('''
        (function() {
          try {
            if (window.tvAppInstance) {
              var isSubView = (window.tvAppInstance.currentView !== 'home');
              var isSubMenu = (window.tvAppInstance.menuStack && window.tvAppInstance.menuStack.length > 0);
              if (isSubView || isSubMenu) {
                if (typeof window.tvAppInstance.stopInfoAutoSlide === 'function') {
                  window.tvAppInstance.stopInfoAutoSlide();
                }
                window.tvAppInstance.currentView = 'home';
                window.tvAppInstance.menuStack = [];
                if (window.tvAppInstance.menuItems) {
                  window.tvAppInstance.currentMenuList = window.tvAppInstance.menuItems;
                }
                window.tvAppInstance.activeMenuIndex = 0;
                return false;
              }
              return true;
            }
            if (typeof window.isTVAtHome === 'function') {
              return window.isTVAtHome();
            }
          } catch (e) {}
          return true;
        })();
      ''');
      return result == true || result == 'true' || result == 1 || result == '1';
    } catch (_) {
      return true;
    }
  }
}
