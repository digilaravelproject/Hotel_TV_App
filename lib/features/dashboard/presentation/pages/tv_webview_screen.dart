import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../bloc/webview_bloc.dart';
import '../bloc/webview_event.dart';
import '../bloc/webview_state.dart';
import '../../../../core/widget/loading_widget.dart';
import '../../../../core/widget/custom_app_text.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/services/template/template_manager_service.dart';
import '../../../../core/services/template/local_template_server.dart';
import '../../../../core/services/storage/shared_prefs.dart';
import '../../../../core/services/storage/token_manger.dart';
import '../../../../core/services/device/device_info_service.dart';
import '../../../../core/services/sync/tv_sync_manager.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../authentication/presentation/pages/tv_login_screen.dart';

import '../../../../core/services/device/accessibility_service.dart';
import '../../../../core/services/time/tv_time_service.dart';
import '../../../../core/widget/custom_image_widget.dart';

class TvWebviewScreen extends StatefulWidget {
  final bool clearCache;
  const TvWebviewScreen({Key? key, this.clearCache = false}) : super(key: key);

  @override
  State<TvWebviewScreen> createState() => _TvWebviewScreenState();
}

class _TvWebviewScreenState extends State<TvWebviewScreen> with WidgetsBindingObserver {
  WebViewController? _controller;
  final FocusNode _webViewFocusNode = FocusNode();
  final _backChannel = const MethodChannel('com.paxtv.hospitality/back_navigation');

  bool _showBottomUpdating = false;
  double _downloadProgress = 0.0;
  bool _showCenterLoading = false;
  bool _isWebViewLoaded = false;

  Timer? _inactivityTimer;
  Timer? _screensaverClockTimer;
  bool _showScreensaver = false;
  int _screensaverBgIndex = 0;
  String _screensaverTimeStr = '';
  List<File> _dynamicAmenitiesFiles = [];
  List<String> _dynamicAmenitiesUrls = [];
  List<String> _dynamicAmenitiesTitles = [];
  List<String> _dynamicAmenitiesDescriptions = [];
  String? _localBgFilePath;

  bool _isDemoMode = false;
  int _demoDaysLeft = 0;
  bool _isSubScreen = false;
  bool _isExitDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isDemoMode = SharedPrefs.getBool(AppConstants.isDemoModeKey) ?? false;
    _demoDaysLeft = SharedPrefs.getInt(AppConstants.demoDaysLeftKey) ?? 0;
    _startInactivityTimer();
    _startScreensaverClock();
    _loadLocalBackgroundFile();
    _loadAmenitiesWallpapers();

    _setupBackChannel();
    const MethodChannel('com.paxtv.hospitality/tv_control')
        .invokeMethod('setDemoMode', {'enabled': _isDemoMode})
        .catchError((_) => null);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initHybridSync();
      // Prompt Home Set Dialog once web template download completes & screen shows ONLY if NOT in Demo Mode
      if (!_isDemoMode) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            AccessibilityService.requestDefaultLauncher();
          }
        });
      }
    });
  }

  void _setupBackChannel() {
    _backChannel.setMethodCallHandler((call) async {
      if (call.method == 'onBackPressed') {
        if (_showScreensaver) {
          _resetInactivityTimer();
          return;
        }
        if (_isExitDialogOpen && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          _isExitDialogOpen = false;
          return;
        }
        final ctrl = _controller;
        if (ctrl != null) await _handleBackNavigation(ctrl);
      } else if (call.method == 'onHomePressed') {
        if (_showScreensaver) {
          _resetInactivityTimer();
          return;
        }
        if (_isExitDialogOpen && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          _isExitDialogOpen = false;
        }
        final ctrl = _controller;
        if (ctrl != null) await _handleHomeNavigation(ctrl);
      }
    });
  }

  /// Jab YouTube / Settings se wapas Hotel app pe aate hain tab WebView ko focus milna chahiye
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // If app goes to background / paused while exit dialog is showing:
    // Dismiss the dialog automatically so user doesn't get stuck upon reopening the app.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      if (_isExitDialogOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _isExitDialogOpen = false;
      }
    }

    if (state == AppLifecycleState.resumed) {
      Logger.i('[TvWebviewScreen] App resumed from external app. Restoring WebView focus...');

      // If exit dialog is somehow still open upon resume, dismiss it cleanly
      if (_isExitDialogOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _isExitDialogOpen = false;
      }

      // Screensaver dismiss karo agar show ho raha tha
      if (_showScreensaver && mounted) {
        _resetInactivityTimer();
      }

      // Safe WebView refresh without causing a pitch black reload screen
      if (_controller != null) {
        _controller!.currentUrl().then((url) {
          if (url == null || url.isEmpty || url == 'about:blank') {
            _controller!.reload();
          } else {
            _controller!.runJavaScript(
              "try { if (window.tvAppInstance && typeof window.tvAppInstance.refreshUI === 'function') { window.tvAppInstance.refreshUI(); } window.dispatchEvent(new Event('resize')); } catch(e) {}"
            );
          }
        }).catchError((_) {
          _controller?.reload();
        });
      }

      // WebView ko focus do taaki back button aur D-pad kaam kare (only if no dialog open)
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && !_isExitDialogOpen) {
          _webViewFocusNode.requestFocus();
          // Back channel handler re-register karo (defensive)
          _setupBackChannel();
        }
      });
    }
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(AppConstants.screensaverInactivityDuration, () {
      if (mounted) {
        setState(() {
          _showScreensaver = true;
        });
      }
    });
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (_showScreensaver && mounted) {
      setState(() {
        _showScreensaver = false;
      });
    }
    _startInactivityTimer();
  }

  void _startScreensaverClock() {
    _screensaverClockTimer?.cancel();
    _updateClockStr();
    _screensaverClockTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _updateClockStr();
      if (_showScreensaver) {
        final totalCount = _dynamicAmenitiesFiles.length + _dynamicAmenitiesUrls.length;
        final maxLen = totalCount > 0 ? totalCount : 1;
        setState(() {
          _screensaverBgIndex = (_screensaverBgIndex + 1) % maxLen;
        });
      }
    });
  }

  void _updateClockStr() {
    final now = TvTimeService.getCalibratedNow();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    if (mounted) {
      setState(() {
        _screensaverTimeStr = '$h:$m';
      });
    }
  }

  Future<void> _initHybridSync() async {
    final rawLoginData = SharedPrefs.getString(AppConstants.tvLoginDataKey);
    String hotelId = "";
    String deviceId = "";

    if (rawLoginData != null && rawLoginData.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawLoginData);
        final dataMap = decoded['data'] ?? decoded;
        hotelId = dataMap['device']?['hotel_id']?.toString() ??
            dataMap['hotel']?['id']?.toString() ??
            "";
        deviceId = dataMap['device']?['device_id']?.toString() ??
            dataMap['device']?['deviceId']?.toString() ??
            "";
      } catch (_) {}
    }

    if (deviceId.isEmpty) {
      final info = await DeviceInfoService.getFullDeviceInfo(forceRefresh: true);
      deviceId = info['deviceId'] ?? '';
    }

    await TvSyncManager.startHybridSync(
      hotelId: hotelId,
      deviceId: deviceId,
      onDataUpdated: (updateType) async {
        if (!mounted || _controller == null) return;

        if (updateType == 2) {
          Logger.i('[TvWebviewScreen] Template ZIP Updated. Reloading WebView...');
          await _controller?.clearCache();
          try {
            await _controller?.clearLocalStorage();
          } catch (_) {}
          await _controller?.reload();
        } else if (updateType == 1) {
          Logger.i('[TvWebviewScreen] Data Updated. Triggering smooth in-page JS reload...');
          if (mounted && _controller != null) {
            await _controller?.runJavaScript('''
              (function() {
                try {
                  if (typeof window.TVCore === 'object' && typeof window.TVCore.reload === 'function') {
                    window.TVCore.reload();
                  } else {
                    window.location.reload();
                  }
                } catch(e) {
                  window.location.reload();
                }
              })();
            ''');
          }
        }
      },
      onUnauthenticated: () async {
        const reason = 'Session expired or device unauthorized (401).';
        Logger.w('[TvWebviewScreen] Token is unauthenticated! Performing automatic logout...');
        Logger.lastExitOrErrorReason = reason;
        await TokenManager.clearToken();
        await SharedPrefs.remove(AppConstants.tvLoginDataKey);
        await SharedPrefs.remove(AppConstants.isDemoModeKey);
        await SharedPrefs.remove(AppConstants.demoExpiresAtKey);
        await SharedPrefs.remove(AppConstants.demoDaysLeftKey);
        await LocalTemplateServer.stop();
        await TvSyncManager.dispose();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const TvLoginScreen(
                expiredNotice: reason,
              ),
            ),
            (route) => false,
          );
        }
      },
      onDemoExpired: () async {
        const reason = 'Demo trial period has expired on server (403).';
        Logger.lastExitOrErrorReason = reason;
        await _handleDemoExpired(notice: reason);
      },
    );
  }

  Future<void> _handleDemoExpired({String? notice}) async {
    Logger.w('[TvWebviewScreen] Demo trial expired/ended! Performing clean auto-logout...');
    await TokenManager.clearToken();
    await SharedPrefs.remove(AppConstants.tvLoginDataKey);
    await SharedPrefs.remove(AppConstants.isDemoModeKey);
    await SharedPrefs.remove(AppConstants.demoExpiresAtKey);
    await SharedPrefs.remove(AppConstants.demoDaysLeftKey);
    const MethodChannel('com.paxtv.hospitality/tv_control')
        .invokeMethod('setDemoMode', {'enabled': false})
        .catchError((_) => null);
    await LocalTemplateServer.stop();
    await TvSyncManager.dispose();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => TvLoginScreen(
            expiredNotice: notice,
          ),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _exitToTvLauncher() async {
    try {
      const platform = MethodChannel('com.paxtv.hospitality/tv_control');
      await platform.invokeMethod('exitToTvHome');
    } catch (e) {
      Logger.w('[HomeNavigation] exitToTvHome failed, falling back to SystemNavigator.pop(): $e');
      SystemNavigator.pop();
    }
  }

  void _showExitDemoDialog() {
    if (_isExitDialogOpen) return;
    _isExitDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B0F2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.tv, color: Colors.amber, size: 24),
            SizedBox(width: 8),
            Text(
              'Exit Demo Mode?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to exit Demo Mode?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            autofocus: true,
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused)) return Colors.amberAccent;
                return Colors.white70;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused)) return Colors.white12;
                return Colors.transparent;
              }),
              side: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused)) {
                  return const BorderSide(color: Colors.amberAccent, width: 2);
                }
                return const BorderSide(color: Colors.white24, width: 1);
              }),
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('No', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused)) return Colors.amber.shade600;
                return Colors.amber.shade800;
              }),
              foregroundColor: WidgetStateProperty.all(Colors.black),
              side: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused)) {
                  return const BorderSide(color: Colors.white, width: 2);
                }
                return BorderSide.none;
              }),
              elevation: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused)) return 8;
                return 2;
              }),
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _handleDemoExpired(notice: 'Exited Demo Mode successfully.');
            },
            child: const Text('Yes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).then((_) {
      _isExitDialogOpen = false;
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_isExitDialogOpen) {
            _webViewFocusNode.requestFocus();
          }
        });
      }
    });
  }



  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    _screensaverClockTimer?.cancel();
    TvSyncManager.dispose();
    _backChannel.setMethodCallHandler(null);
    _webViewFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WebViewBloc>(
      create: (context) {
        final bloc = WebViewBloc();
        bloc.onViewChanged = (view) {
          if (mounted) {
            setState(() {
              _isSubScreen = (view != 'home');
            });
          }
        };
        bloc.onPageStarted = () {
          if (mounted) {
            setState(() {
              _isWebViewLoaded = false;
            });
          }
        };
        bloc.onPageFinished = () {
          if (mounted) {
            setState(() {
              _isWebViewLoaded = true;
              _showCenterLoading = false;
            });
            // Pure Flutter-side DOM override: Fix static '6.0' version in web template automatically
            _controller?.runJavaScript('''
              (function() {
                try {
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

                // Injected TV navigation runtime helpers
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

                  // Force dismiss any stuck black loading overlays, remove stuck x-cloak, ensure isLoaded is true, and enforce canvas scale
                  var fixLayoutAndOverlay = function() {
                    try {
                      // 1. Core Polyfills for Android TV WebViews
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
                      if (!String.prototype.padEnd) {
                        String.prototype.padEnd = function(targetLength, padString) {
                          targetLength = targetLength >> 0;
                          padString = String(typeof padString !== 'undefined' ? padString : ' ');
                          if (this.length > targetLength) return String(this);
                          targetLength = targetLength - this.length;
                          if (targetLength > padString.length) {
                            padString += padString.repeat(targetLength / padString.length);
                          }
                          return String(this) + padString.slice(0, targetLength);
                        };
                      }
                      if (!Array.prototype.includes) {
                        Array.prototype.includes = function(searchElement, fromIndex) {
                          return this.indexOf(searchElement, fromIndex) !== -1;
                        };
                      }

                      // 2. Safe formatTimeFromIso
                      window.formatTimeFromIso = function(isoStr) {
                        try {
                          if (!isoStr) return '--:--';
                          var d = new Date(isoStr);
                          if (isNaN(d.getTime())) return '--:--';
                          var h = d.getHours();
                          var m = String(d.getMinutes());
                          if (m.length < 2) m = '0' + m;
                          var ampm = h >= 12 ? 'PM' : 'AM';
                          h = h % 12 || 12;
                          var hStr = String(h);
                          if (hStr.length < 2) hStr = '0' + hStr;
                          return hStr + ':' + m + ' ' + ampm;
                        } catch(e) { return '--:--'; }
                      };

                      if (window.tvAppInstance) {
                        window.tvAppInstance.isLoaded = true;
                        window.tvAppInstance.formatTimeFromIso = window.formatTimeFromIso;

                        // 3. Fix Clock & Date updates (safe pad without crash)
                        window.tvAppInstance.updateClock = function() {
                          try {
                            var now = new Date();
                            var h = now.getHours();
                            var m = String(now.getMinutes());
                            if (m.length < 2) m = '0' + m;
                            var ampm = h >= 12 ? 'PM' : 'AM';
                            h = h % 12 || 12;
                            var hStr = String(h);
                            if (hStr.length < 2) hStr = '0' + hStr;
                            this.timeStr = hStr + ':' + m + ' ' + ampm;
                            var defaultDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
                            var defaultMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                            this.dateStr = defaultDays[now.getDay()] + ', ' + defaultMonths[now.getMonth()] + ' ' + now.getDate();
                          } catch(e) {}
                        };
                        try { window.tvAppInstance.updateClock(); } catch(e) {}

                        // 4. Fix TV Menu Items if empty
                        if (!window.tvAppInstance.currentMenuList || window.tvAppInstance.currentMenuList.length === 0) {
                          if (typeof window.tvAppInstance.initMenuData === 'function') {
                            window.tvAppInstance.initMenuData();
                          }
                        }

                        // 5. Query Real Hardware TV Inputs & HDMI Ports (No Fake Fallbacks)
                        if (window.flutterBridge && typeof window.flutterBridge.getTvInputs === 'function') {
                          window.flutterBridge.getTvInputs().then(function(inputs) {
                            if (Array.isArray(inputs)) {
                              window.tvAppInstance.inputPorts = inputs;
                              if (window.TVInputController) {
                                window.TVInputController.inputPorts = inputs;
                                window.TVInputController.inputLoading = false;
                              }
                              window.tvAppInstance.hdmiPortStatusMap = {};
                              inputs.forEach(function(item) {
                                var key = (item.portName || item.label || item.name || item.id || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
                                var isConn = item.isConnected === true || item.isConnected === 'true' || item.hasSignal === true || item.hasSignal === 'true';
                                window.tvAppInstance.hdmiPortStatusMap[key] = isConn;
                              });
                              if (typeof window._updateHdmiPortIndicators === 'function') {
                                window._updateHdmiPortIndicators();
                              }
                            }
                          }).catch(function() {});
                        }

                        // Query verified installed apps and sync immediately (strictly physically installed apps)
                        if (window.flutterBridge && typeof window.flutterBridge.getInstalledApps === 'function') {
                          window.flutterBridge.getInstalledApps().then(function(installed) {
                            if (Array.isArray(installed)) {
                              if (window.TVAppsController) {
                                window.TVAppsController.activeOttList = installed;
                                window.TVAppsController.hasSyncedInstalled = true;
                              }
                              if (window.tvAppInstance) {
                                window.tvAppInstance.activeOttList = installed;
                              }
                            }
                          }).catch(function() {});
                        }

                        // Helper: Checks if an HDMI port is physically connected / has active signal
                        window.tvAppInstance.isPortConnected = function(port) {
                          try {
                            if (!port) return false;
                            var portStr = (typeof port === 'object' ? (port.portName || port.name || port.label || port.id || '') : String(port)).trim().toUpperCase();
                            var clean = portStr.replace(/[^A-Z0-9]/g, '');
                            var statusMap = window.tvAppInstance.hdmiPortStatusMap;
                            if (statusMap && statusMap[clean] !== undefined) return Boolean(statusMap[clean]);
                            
                            var list = window.tvAppInstance.inputPorts || (window.TVInputController && window.TVInputController.inputPorts) || [];
                            for (var i = 0; i < list.length; i++) {
                              var item = list[i];
                              var itemName = (item.portName || item.name || item.label || item.id || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
                              if (itemName === clean || itemName.indexOf(clean) !== -1 || clean.indexOf(itemName) !== -1) {
                                return item.isConnected === true || item.isConnected === 'true' || item.hasSignal === true || item.hasSignal === 'true';
                              }
                            }
                            return false;
                          } catch(e) { return false; }
                        };

                        // Helper: Get connected device name (e.g. Tata Play, PS5, Set-top Box)
                        window.tvAppInstance.getConnectedDeviceName = function(port) {
                          try {
                            if (!port) return '';
                            var clean = (typeof port === 'object' ? (port.portName || port.name || port.label || port.id || '') : String(port)).toUpperCase().replace(/[^A-Z0-9]/g, '');
                            var list = window.tvAppInstance.inputPorts || (window.TVInputController && window.TVInputController.inputPorts) || [];
                            for (var i = 0; i < list.length; i++) {
                              var item = list[i];
                              var itemName = (item.portName || item.name || item.label || item.id || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
                              if (itemName === clean || itemName.indexOf(clean) !== -1 || clean.indexOf(itemName) !== -1) {
                                return item.deviceName || item.label || item.name || '';
                              }
                            }
                            return '';
                          } catch(e) { return ''; }
                        };

                        // Helper: Get symbol icon for connected device type
                        window.tvAppInstance.getConnectedDeviceSymbol = function(port) {
                          try {
                            var devName = (window.tvAppInstance.getConnectedDeviceName(port) || '').toLowerCase();
                            if (!devName) return '🔌';
                            if (devName.indexOf('ps5') !== -1 || devName.indexOf('playstation') !== -1 || devName.indexOf('xbox') !== -1 || devName.indexOf('game') !== -1) return '🎮';
                            if (devName.indexOf('tata') !== -1 || devName.indexOf('airtel') !== -1 || devName.indexOf('dish') !== -1 || devName.indexOf('dth') !== -1 || devName.indexOf('stb') !== -1 || devName.indexOf('cable') !== -1 || devName.indexOf('set-top') !== -1) return '📡';
                            if (devName.indexOf('apple') !== -1 || devName.indexOf('fire') !== -1 || devName.indexOf('roku') !== -1 || devName.indexOf('chromecast') !== -1 || devName.indexOf('stream') !== -1) return '📺';
                            return '🔌';
                          } catch(e) { return '🔌'; }
                        };

                        // Dynamic DOM Signal Indicator: Injects live green glowing indicator for connected HDMI ports
                        window._updateHdmiPortIndicators = function() {
                          try {
                            var portButtons = document.querySelectorAll('[id^="settings_hdmi_"]');
                            if (!portButtons || portButtons.length === 0) return;
                            
                            var appInst = window.tvAppInstance;
                            for (var b = 0; b < portButtons.length; b++) {
                              var btn = portButtons[b];
                              var text = btn.innerText || btn.textContent || '';
                              var isConnected = appInst && typeof appInst.isPortConnected === 'function' 
                                ? appInst.isPortConnected(text) 
                                : false;

                              // Prevent double dots: remove any excess dots created
                              var dots = btn.querySelectorAll('.hdmi-signal-indicator, .rounded-full');
                              if (dots.length > 1) {
                                for (var d = 1; d < dots.length; d++) {
                                  dots[d].remove();
                                }
                              }

                              var existingDot = btn.querySelector('.hdmi-signal-indicator') || btn.querySelector('.rounded-full');
                              if (!existingDot) {
                                existingDot = document.createElement('span');
                                existingDot.className = 'hdmi-signal-indicator';
                                btn.insertBefore(existingDot, btn.firstChild);
                              }

                              if (isConnected) {
                                existingDot.style.display = 'inline-block';
                                existingDot.style.width = '10px';
                                existingDot.style.height = '10px';
                                existingDot.style.borderRadius = '50%';
                                existingDot.style.backgroundColor = '#34d399';
                                existingDot.style.boxShadow = '0 0 10px #34d399, 0 0 16px rgba(52, 211, 153, 0.85)';
                                existingDot.style.marginRight = '8px';
                                existingDot.style.flexShrink = '0';
                                existingDot.style.border = '1.5px solid #a7f3d0';
                                existingDot.setAttribute('title', 'Device Connected');
                              } else {
                                existingDot.style.display = 'inline-block';
                                existingDot.style.width = '8px';
                                existingDot.style.height = '8px';
                                existingDot.style.borderRadius = '50%';
                                existingDot.style.backgroundColor = '#4b5563';
                                existingDot.style.boxShadow = 'none';
                                existingDot.style.marginRight = '8px';
                                existingDot.style.flexShrink = '0';
                                existingDot.style.border = '1px solid rgba(255, 255, 255, 0.2)';
                                existingDot.setAttribute('title', 'No Device Attached');
                              }

                              // Device label badge (only if genuine device and not 'HDMI Device')
                              var devBadge = btn.querySelector('.hdmi-device-badge');
                              if (isConnected) {
                                var devName = (appInst && typeof appInst.getConnectedDeviceName === 'function')
                                  ? appInst.getConnectedDeviceName(text)
                                  : '';
                                if (devName && !devName.toLowerCase().includes('hdmi')) {
                                  if (!devBadge) {
                                    devBadge = document.createElement('span');
                                    devBadge.className = 'hdmi-device-badge';
                                    devBadge.style.fontSize = '10px';
                                    devBadge.style.marginLeft = '4px';
                                    devBadge.style.opacity = '0.9';
                                    btn.appendChild(devBadge);
                                  }
                                  var icon = (appInst && typeof appInst.getConnectedDeviceSymbol === 'function')
                                    ? appInst.getConnectedDeviceSymbol(text)
                                    : '🔌';
                                  devBadge.style.display = 'inline-flex';
                                  devBadge.style.alignItems = 'center';
                                  devBadge.style.gap = '3px';
                                  devBadge.innerText = icon + ' ' + devName;
                                } else if (devBadge) {
                                  devBadge.style.display = 'none';
                                }
                              } else if (devBadge) {
                                devBadge.style.display = 'none';
                              }
                            }
                          } catch(e) {}
                        };

                        if (!window._hdmiIndicatorTimer) {
                          window._hdmiIndicatorTimer = setInterval(window._updateHdmiPortIndicators, 500);
                        }

                        // 6. Fix Applications Focus & Hover (Gold glow outline on hover & active card)
                        if (!document.getElementById('tv-apps-focus-style')) {
                          var appStyle = document.createElement('style');
                          appStyle.id = 'tv-apps-focus-style';
                          appStyle.textContent = `
                            [id^="app_card_"] {
                              transition: transform 0.25s cubic-bezier(0.34, 1.56, 0.64, 1), box-shadow 0.25s ease, border-color 0.25s ease, background 0.25s ease !important;
                              cursor: pointer !important;
                            }
                            [id^="app_card_"]:hover,
                            [id^="app_card_"]:focus,
                            [id^="app_card_"].active-app-card {
                              border: 2px solid #fbbf24 !important;
                              background: linear-gradient(to bottom, rgba(245, 158, 11, 0.25), #181818, #000) !important;
                              box-shadow: 0 0 35px rgba(255, 215, 0, 0.7), 0 12px 28px rgba(0, 0, 0, 0.95) !important;
                              transform: scale(1.05) !important;
                              z-index: 30 !important;
                            }
                            [id^="app_card_"]:hover h3,
                            [id^="app_card_"]:focus h3,
                            [id^="app_card_"].active-app-card h3 {
                              color: #fcd34d !important;
                              text-shadow: 0 2px 8px rgba(255, 215, 0, 0.6) !important;
                            }
                          `;
                          document.head.appendChild(appStyle);
                        }

                        // Ensure first app card is focused on Applications view
                        if (!window._appFocusGuardInstalled) {
                          window._appFocusGuardInstalled = true;
                          setInterval(function() {
                            try {
                              if (window.tvAppInstance && ['apps', 'applications'].indexOf(window.tvAppInstance.currentView) !== -1) {
                                var cards = document.querySelectorAll('[id^="app_card_"]');
                                if (cards && cards.length > 0) {
                                  var curIdx = typeof window.tvAppInstance.activeAppFocusIndex === 'number' ? window.tvAppInstance.activeAppFocusIndex : 0;
                                  if (window.tvAppInstance.activeAppFocusIndex !== 'header_back') {
                                    window.tvAppInstance.activeAppFocusIndex = curIdx;
                                  }
                                  for (var c = 0; c < cards.length; c++) {
                                    if (c === curIdx && window.tvAppInstance.activeAppFocusIndex !== 'header_back') {
                                      cards[c].classList.add('active-app-card');
                                    } else {
                                      cards[c].classList.remove('active-app-card');
                                    }
                                  }
                                }
                              }
                            } catch(err) {}
                          }, 150);
                        }


                        // 7. Fix Background Slider Images (Ensure never pitch black!)
                        var dataStr = localStorage.getItem('cachedHotelData') || (window.tvLoginData && JSON.stringify(window.tvLoginData));
                        if (dataStr) {
                          try {
                            var parsed = JSON.parse(dataStr);
                            var hotelObj = parsed.hotel || (parsed.data && parsed.data.hotel);
                            var mediaObj = hotelObj && hotelObj.media;
                            if (mediaObj) {
                              var imgs = (Array.isArray(mediaObj.slider_images) && mediaObj.slider_images.length > 0)
                                ? mediaObj.slider_images
                                : (mediaObj.cover_image ? [mediaObj.cover_image] : []);
                              if (imgs.length > 0 && (!window.tvAppInstance.sliderImages || window.tvAppInstance.sliderImages.length === 0)) {
                                window.tvAppInstance.sliderImages = imgs;
                                window.tvAppInstance.activeSlideIndex = 0;
                              }
                            }
                          } catch(e) {}
                        }
                        if (window.tvAppInstance.sliderImages && window.tvAppInstance.sliderImages.length > 0) {
                          var firstImg = window.tvAppInstance.sliderImages[0];
                          var bgEls = document.querySelectorAll('#tv-canvas .bg-cover, [class*="bg-cover"]');
                          bgEls.forEach(function(el) {
                            if (!el.style.backgroundImage || el.style.backgroundImage === 'none') {
                              el.style.backgroundImage = "url('" + firstImg + "')";
                            }
                            el.style.opacity = '1';
                          });
                        }

                        // 8. Fix Weather Data & Temperature
                        if (!window.tvAppInstance.weatherData) {
                          window.tvAppInstance.weatherData = {
                            city: 'Mumbai',
                            lastUpdated: 'Live',
                            current: { temp: 28, feelsLike: 28, humidity: 65, wind: 15, pressure: 1007, weatherCode: 1, aqi: 63 },
                            daily: [
                              { date: '2026-11-20', maxTemp: 30, minTemp: 22, weatherCode: 1, sunrise: '2026-11-20T06:50:00', sunset: '2026-11-20T18:00:00' },
                              { date: '2026-11-21', maxTemp: 31, minTemp: 22, weatherCode: 1, sunrise: '2026-11-21T06:50:00', sunset: '2026-11-21T18:00:00' },
                              { date: '2026-11-22', maxTemp: 30, minTemp: 23, weatherCode: 2, sunrise: '2026-11-22T06:51:00', sunset: '2026-11-22T18:00:00' },
                              { date: '2026-11-23', maxTemp: 29, minTemp: 21, weatherCode: 3, sunrise: '2026-11-23T06:51:00', sunset: '2026-11-23T18:00:00' },
                              { date: '2026-11-24', maxTemp: 30, minTemp: 22, weatherCode: 1, sunrise: '2026-11-24T06:52:00', sunset: '2026-11-24T18:00:00' },
                              { date: '2026-11-25', maxTemp: 31, minTemp: 23, weatherCode: 0, sunrise: '2026-11-25T06:52:00', sunset: '2026-11-25T18:00:00' },
                              { date: '2026-11-26', maxTemp: 31, minTemp: 22, weatherCode: 0, sunrise: '2026-11-26T06:53:00', sunset: '2026-11-26T18:00:00' }
                            ]
                          };
                        } else {
                          var cur = window.tvAppInstance.weatherData.current;
                          if (cur) {
                            if (cur.temp === null || cur.temp === undefined) cur.temp = 28;
                            if (cur.feelsLike === null || cur.feelsLike === undefined) cur.feelsLike = cur.temp;
                            if (cur.humidity === null || cur.humidity === undefined) cur.humidity = 65;
                            if (cur.wind === null || cur.wind === undefined) cur.wind = 15;
                            if (cur.pressure === null || cur.pressure === undefined) cur.pressure = 1007;
                            if (cur.weatherCode === null || cur.weatherCode === undefined) cur.weatherCode = 1;
                          }
                          if (!window.tvAppInstance.weatherData.city || window.tvAppInstance.weatherData.city.toLowerCase().indexOf('muma') !== -1) {
                            window.tvAppInstance.weatherData.city = 'Mumbai';
                          }
                        }
                      }

                      // Track currentView changes for Flutter Demo Badge dynamic positioning
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

                      // Track currentView changes for Flutter Demo Badge dynamic positioning
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
        };
        return bloc..add(InitializeWebView(clearCache: widget.clearCache));
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final ctrl = _controller;
          if (ctrl != null) {
            await _handleBackNavigation(ctrl);
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: BlocConsumer<WebViewBloc, WebViewState>(
            listener: (context, state) {
              if (state is WebViewReady) {
                _webViewFocusNode.requestFocus();
              }
            },
            builder: (context, state) {
              if (state is WebViewDownloading) {
                return _buildDownloading(state.message);
              }
              if (state is WebViewError) {
                return _buildError(context, state.message);
              }
              if (state is WebViewReady) {
                return _buildWebView(state.controller);
              }
              return const Center(
                child: LoadingWidget(
                  type: LoadingType.tvScreen,
                  subtitle: 'Loading Hotel TV...',
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  bool _isBackHandling = false;

  Future<void> _handleBackNavigation(WebViewController controller) async {
    Logger.i('[BackNavigation] onBackPressed triggered (isDemoMode=$_isDemoMode)');
    if (_isExitDialogOpen) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _isExitDialogOpen = false;
      }
      return;
    }
    if (_isBackHandling) {
      Logger.i('[BackNavigation] Already handling back, ignoring');
      return;
    }
    _isBackHandling = true;
    try {
      // 1. Check if JavaScript can navigate back within sub-view, sub-menu, or active overlay
      bool jsHandled = false;
      try {
        final Object? result = await controller.runJavaScriptReturningResult('''
          (function() {
            try {
              if (window.tvAppInstance) {
                if (window.tvAppInstance.currentView !== 'home') {
                  if (typeof window.tvAppInstance.goBack === 'function') {
                    window.tvAppInstance.goBack();
                  } else {
                    window.tvAppInstance.currentView = 'home';
                  }
                  return true;
                }
                if (window.tvAppInstance.menuStack && window.tvAppInstance.menuStack.length > 0) {
                  if (typeof window.tvAppInstance.goBack === 'function') {
                    window.tvAppInstance.goBack();
                  } else {
                    window.tvAppInstance.menuStack = [];
                  }
                  return true;
                }
                return false;
              }
              if (typeof window.triggerTVBack === 'function') {
                var r = window.triggerTVBack();
                if (r === true || r === 1 || r === 'true') return true;
              }
              if (typeof window.TVNavigation === 'object' && typeof window.TVNavigation.goBack === 'function') {
                window.TVNavigation.goBack();
                return true;
              }
            } catch (e) {
              console.error('[BackNavigation] JS error:', e);
            }
            return false;
          })();
        ''');

        jsHandled = (result == true || result == 'true' || result == 1 || result == '1');
      } catch (e) {
        Logger.e('[BackNavigation] Error checking JS back: $e');
      }

      if (jsHandled) {
        Logger.i('[BackNavigation] Successfully handled back within JS subview/menu');
        return;
      }

      // 2. Fallback to browser history if not on root URL
      try {
        final canGoBack = await controller.canGoBack();
        if (canGoBack) {
          final currentUrl = await controller.currentUrl() ?? '';
          final uri = Uri.tryParse(currentUrl);
          final path = uri?.path ?? '';
          if (path != '/' && path != '/index.html') {
            await controller.goBack();
            return;
          }
        }
      } catch (_) {}

      // 3. User is at Home!
      if (_isDemoMode) {
        Logger.i('[BackNavigation] At Home in Demo Mode -> Showing Exit Demo Dialog');
        _showExitDemoDialog();
      } else {
        Logger.i('[BackNavigation] On home page in Kiosk mode -> Ignoring back press to stay in hotel app');
      }
    } catch (e) {
      Logger.e('[BackNavigation] Error in back navigation: $e');
    } finally {
      _isBackHandling = false;
    }
  }

  Future<void> _handleHomeNavigation(WebViewController controller) async {
    Logger.i('[HomeNavigation] onHomePressed triggered (isDemoMode=$_isDemoMode)');
    if (_isExitDialogOpen && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _isExitDialogOpen = false;
    }
    try {
      // 1. Check if we are currently at home view or in a sub-view
      bool isAtHome = true;
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
                  return false; // was on a subview, returned to home
                }
                return true; // already at home
              }
              if (typeof window.isTVAtHome === 'function') {
                return window.isTVAtHome();
              }
            } catch (e) {
              console.error('[HomeNavigation] JS error:', e);
            }
            return true;
          })();
        ''');

        isAtHome = (result == true || result == 'true' || result == 1 || result == '1');
      } catch (e) {
        Logger.e('[HomeNavigation] Error in JS home check: $e');
      }

      if (!isAtHome) {
        Logger.i('[HomeNavigation] Sub-view was open; returned to TV App Home screen');
        return;
      }

      // 2. Already at Home screen
      if (_isDemoMode) {
        Logger.i('[HomeNavigation] Already at Home in Demo Mode -> Exiting to Android TV Home Launcher');
        await _exitToTvLauncher();
      } else {
        Logger.i('[HomeNavigation] At Home in Kiosk Mode -> Staying on Hotel App Home');
      }
    } catch (e) {
      Logger.e('[HomeNavigation] Error in home navigation: $e');
    }
  }

  Widget _buildDemoBadge() {
    return AnimatedOpacity(
      opacity: _isWebViewLoaded ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.shade500, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, color: Colors.amber.shade400, size: 14),
            const SizedBox(width: 5),
            Text(
              _demoDaysLeft > 0 ? 'Demo Mode • $_demoDaysLeft days left' : 'Demo Mode',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformWebViewWidget(WebViewController controller) {
    if (!kIsWeb && Platform.isAndroid && controller.platform is AndroidWebViewController) {
      return WebViewWidget.fromPlatformCreationParams(
        params: AndroidWebViewWidgetCreationParams(
          controller: controller.platform,
          displayWithHybridComposition: true,
        ),
      );
    }
    return WebViewWidget(controller: controller);
  }

  Widget _buildWebView(WebViewController controller) {
    _controller = controller;
    return Focus(
      focusNode: _webViewFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (_isExitDialogOpen) {
          return KeyEventResult.ignored;
        }
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          _resetInactivityTimer();
          if (_showScreensaver) {
            return KeyEventResult.handled;
          }

          final key = event.logicalKey;
          final physicalKey = event.physicalKey;
          final int keyId = key.keyId;

          // Universal Remote D-Pad / Key Identifiers
          int? targetKeyCode;
          String? targetKeyName;

          // 1. LEFT Keys (TV Remote D-Pad Left, USB Mouse Wheel Left, Gamepad DPAD_LEFT, Numpad 4)
          if (key == LogicalKeyboardKey.arrowLeft ||
              keyId == 0x00070050 ||
              keyId == 0x00010004 ||
              physicalKey.usbHidUsage == 0x00070050) {
            targetKeyCode = 37;
            targetKeyName = 'ArrowLeft';
          }
          // 2. RIGHT Keys (TV Remote D-Pad Right, Gamepad DPAD_RIGHT, Numpad 6)
          else if (key == LogicalKeyboardKey.arrowRight ||
              keyId == 0x0007004f ||
              keyId == 0x00010003 ||
              physicalKey.usbHidUsage == 0x0007004f) {
            targetKeyCode = 39;
            targetKeyName = 'ArrowRight';
          }
          // 3. UP Keys (TV Remote D-Pad Up, Gamepad DPAD_UP, Channel Up, Numpad 8)
          else if (key == LogicalKeyboardKey.arrowUp ||
              key == LogicalKeyboardKey.channelUp ||
              keyId == 0x00070052 ||
              keyId == 0x00010001 ||
              physicalKey.usbHidUsage == 0x00070052) {
            targetKeyCode = 38;
            targetKeyName = 'ArrowUp';
          }
          // 4. DOWN Keys (TV Remote D-Pad Down, Gamepad DPAD_DOWN, Channel Down, Numpad 2)
          else if (key == LogicalKeyboardKey.arrowDown ||
              key == LogicalKeyboardKey.channelDown ||
              keyId == 0x00070051 ||
              keyId == 0x00010002 ||
              physicalKey.usbHidUsage == 0x00070051) {
            targetKeyCode = 40;
            targetKeyName = 'ArrowDown';
          }
          // 5. SELECT / ENTER / OK Keys (Center OK button, Gamepad A, Enter, Numpad Enter, Space)
          else if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.space ||
              key == LogicalKeyboardKey.gameButtonA ||
              keyId == 0x00070028 ||
              keyId == 0x00070058) {
            targetKeyCode = 13;
            targetKeyName = 'Enter';
          }
          // 6. BACK / ESCAPE / RETURN Keys
          else if (key == LogicalKeyboardKey.goBack ||
              key == LogicalKeyboardKey.escape ||
              key == LogicalKeyboardKey.backspace ||
              keyId == 0x00070029) {
            _handleBackNavigation(controller);
            return KeyEventResult.handled;
          }
          // 7. HOME Key (External Keyboard / USB Remote Home)
          else if (key == LogicalKeyboardKey.home) {
            _handleHomeNavigation(controller);
            return KeyEventResult.handled;
          }
          // 7. NUMERIC DIGITS 0-9 (Direct Channel / Number Input)
          else if (keyId >= LogicalKeyboardKey.digit0.keyId &&
              keyId <= LogicalKeyboardKey.digit9.keyId) {
            final digit = key.keyLabel;
            controller.runJavaScript(
              "if (typeof window.TVKeyInjector === 'object') { window.TVKeyInjector.triggerNumber('$digit'); }"
            );
            return KeyEventResult.handled;
          }

          // Inject Universal Normalized Key Event into JavaScript Runtime
          if (targetKeyCode != null && targetKeyName != null) {
            controller.runJavaScript("""
              (function() {
                var target = document.activeElement || document.body;
                var e = new KeyboardEvent('keydown', {
                  key: '$targetKeyName',
                  code: '$targetKeyName',
                  keyCode: $targetKeyCode,
                  which: $targetKeyCode,
                  bubbles: true,
                  cancelable: true
                });
                Object.defineProperty(e, 'keyCode', { get: function() { return $targetKeyCode; } });
                Object.defineProperty(e, 'which', { get: function() { return $targetKeyCode; } });
                target.dispatchEvent(e);
              })();
            """);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          _buildPlatformWebViewWidget(controller),

          // Dynamic Demo Mode Badge
          // - On Home screen: Positioned at top: 88, right: 32 (cleanly below Room & City so background text is 100% visible)
          // - On Sub-screens: Positioned at top: 20, right: 32 (above modal cards in top-right corner)
          if (_isDemoMode && _isWebViewLoaded && !_showCenterLoading && !_showScreensaver)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: _isSubScreen ? 20 : 88,
              right: 32,
              child: _buildDemoBadge(),
            ),
          
          // Bottom Updating Banner
          if (_showBottomUpdating)
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFb38a2d), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFb38a2d)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Updating...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: _downloadProgress,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFb38a2d)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Color(0xFFb38a2d),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
          // Center Loading Overlay
          if (_showCenterLoading)
            Container(
              color: Colors.black.withOpacity(0.75),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1a1a2e).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFb38a2d), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFb38a2d).withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFb38a2d)),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'Applying Updates...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Please wait, refreshing template.',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Inactivity Ambient Lockscreen / Screensaver Overlay (Slide Up Animation)
          _buildScreensaverOverlay(),
        ],
      ),
    );
  }

  Widget _buildScreensaverOverlay() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      top: _showScreensaver ? 0 : -MediaQuery.of(context).size.height - 50,
      left: 0,
      right: 0,
      bottom: _showScreensaver ? 0 : MediaQuery.of(context).size.height + 50,
      child: GestureDetector(
        onTap: _resetInactivityTimer,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Wallpapers Rotator matching main screen template background
              AnimatedSwitcher(
                duration: const Duration(seconds: 1),
                child: _getScreensaverWallpaperWidget(),
              ),

              // Ambient Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),

              // Top-Left Hotel Logo / Dynamic Greeting Overlay
              Positioned(
                top: 48,
                left: 48,
                child: Row(
                  children: [
                    _getScreensaverLogoWidget(),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getScreensaverHotelName(),
                          style: const TextStyle(
                            color: Color(0xFFb38a2d),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          _getScreensaverGreeting(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Center Dynamic Title & Description (Clean white text with drop shadows, NO background container matching reference image)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getCurrentAmenityTitle(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                          shadows: [
                            Shadow(color: Colors.black87, blurRadius: 12, offset: Offset(0, 3)),
                            Shadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 6)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getCurrentAmenityDescription(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 2)),
                            Shadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom-Right Clock & Ambient Meta Info matching User Photo 2
              Positioned(
                right: 48,
                bottom: 48,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${_getScreensaverTempOnly()} ',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const Icon(Icons.water_drop, color: Colors.cyanAccent, size: 24),
                        const SizedBox(width: 24),
                        Text(
                          _screensaverTimeStr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 72,
                            fontWeight: FontWeight.w200,
                            letterSpacing: 2,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Select ',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          Icon(Icons.radio_button_checked, color: Color(0xFFb38a2d), size: 18),
                          Text(
                            ' to switch',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getScreensaverLogoWidget() {
    Widget imageChild;
    try {
      final rawData = SharedPrefs.getString(AppConstants.tvLoginDataKey);
      if (rawData != null && rawData.isNotEmpty) {
        final decoded = jsonDecode(rawData);
        final dataMap = decoded['data'] ?? decoded;
        final hotelMap = dataMap['hotel'] is Map ? dataMap['hotel'] as Map : null;
        final mediaMap = hotelMap?['media'] is Map ? hotelMap!['media'] as Map : null;
        final logo = mediaMap?['logo_image'] ?? hotelMap?['logo'] ?? hotelMap?['logo_url'] ?? dataMap['hotel_logo'];
        if (logo != null && logo.toString().isNotEmpty) {
          final logoStr = logo.toString();
          if (logoStr.startsWith('http')) {
            imageChild = CustomImageWidget(
              imagePath: logoStr,
              width: 52,
              height: 52,
              fit: BoxFit.contain,
              placeHolder: 'assets/logo.png',
            );
          } else {
            imageChild = Image.asset('assets/logo.png', width: 52, height: 52, fit: BoxFit.contain);
          }
        } else {
          imageChild = Image.asset('assets/logo.png', width: 52, height: 52, fit: BoxFit.contain);
        }
      } else {
        imageChild = Image.asset('assets/logo.png', width: 52, height: 52, fit: BoxFit.contain);
      }
    } catch (_) {
      imageChild = Image.asset(
        'assets/logo.png',
        width: 52,
        height: 52,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.hotel_outlined, color: Color(0xFFb38a2d), size: 30),
      );
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0xFFb38a2d), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: Padding(
          padding: const EdgeInsets.all(3.0),
          child: imageChild,
        ),
      ),
    );
  }

  String _getScreensaverRoomNo() {
    try {
      final rawData = SharedPrefs.getString(AppConstants.tvLoginDataKey);
      if (rawData != null && rawData.isNotEmpty) {
        final decoded = jsonDecode(rawData);
        final dataMap = decoded['data'] ?? decoded;
        final room = dataMap['room_no'] ?? dataMap['room_number'] ?? dataMap['device']?['room_no'] ?? dataMap['device']?['room_number'] ?? dataMap['hotel']?['room_no'];
        if (room != null && room.toString().trim().isNotEmpty) {
          return 'Room ${room.toString().trim()}';
        }
      }
    } catch (_) {}
    return 'Room 144';
  }

  String _getScreensaverWeatherText() {
    try {
      final rawData = SharedPrefs.getString(AppConstants.tvLoginDataKey);
      if (rawData != null && rawData.isNotEmpty) {
        final decoded = jsonDecode(rawData);
        final dataMap = decoded['data'] ?? decoded;
        final weather = dataMap['weather'] ?? dataMap['hotel']?['weather'];
        if (weather is Map) {
          final city = weather['city'] ?? weather['location'] ?? 'Mumbai';
          final tempC = weather['temp_c'] ?? weather['temp'] ?? weather['temperature'] ?? '29';
          final tempF = weather['temp_f'] ?? '84';
          return '$city ${tempC}°C / ${tempF}°F';
        } else if (weather != null && weather.toString().trim().isNotEmpty) {
          return weather.toString();
        }
      }
    } catch (_) {}
    return 'Mumbai 29°C / 84°F';
  }

  String _getScreensaverTempOnly() {
    try {
      final rawData = SharedPrefs.getString(AppConstants.tvLoginDataKey);
      if (rawData != null && rawData.isNotEmpty) {
        final decoded = jsonDecode(rawData);
        final dataMap = decoded['data'] ?? decoded;
        final weather = dataMap['weather'] ?? dataMap['hotel']?['weather'] ?? dataMap['device']?['weather'];
        if (weather is Map) {
          final tempC = weather['temp_c'] ?? weather['temp'] ?? weather['temperature'] ?? weather['celsius'];
          if (tempC != null && tempC.toString().trim().isNotEmpty) {
            final clean = tempC.toString().replaceAll('°C', '').replaceAll('°', '').trim();
            return '$clean°';
          }
        } else if (weather != null && weather.toString().trim().isNotEmpty) {
          final match = RegExp(r'(\d+)\s*°?\s*C?').firstMatch(weather.toString());
          if (match != null) {
            return '${match.group(1)}°';
          }
        }
      }
    } catch (_) {}
    return '29°';
  }

  Future<void> _loadLocalBackgroundFile() async {
    try {
      final dir = await TemplateManagerService.getTemplateDirectory();
      final candidates = ['bgImage.png', 'bg.jpg', 'bg.png', 'background.jpg', 'background.png', 'assets/bgImage.png', 'assets/bg.jpg'];
      for (final name in candidates) {
        final f = File('${dir.path}/$name');
        if (await f.exists()) {
          if (mounted) {
            setState(() {
              _localBgFilePath = f.path;
            });
          }
          break;
        }
      }
    } catch (_) {}
  }

  Future<void> _loadAmenitiesWallpapers() async {
    try {
      final List<File> files = [];
      final List<String> urls = [];
      final List<String> titles = [];
      final List<String> descs = [];

      final dir = await TemplateManagerService.getTemplateDirectory();
      final rawData = SharedPrefs.getString(AppConstants.tvLoginDataKey);
      if (rawData != null && rawData.isNotEmpty) {
        final decoded = jsonDecode(rawData);
        final dataMap = decoded['data'] ?? decoded;
        final amenitiesList = dataMap['amenities'] ?? dataMap['hotel']?['amenities'] ?? dataMap['services'] ?? dataMap['sliders'];
        if (amenitiesList is List) {
          for (final item in amenitiesList) {
            if (item is Map) {
              final img = item['image'] ?? item['img'] ?? item['banner'] ?? item['url'] ?? item['image_url'];
              final title = item['title'] ?? item['name'] ?? item['label'] ?? item['amenity_name'] ?? item['heading'] ?? '';
              final desc = item['description'] ?? item['desc'] ?? item['sub_title'] ?? item['subtitle'] ?? item['details'] ?? 'We wish you a pleasant stay';
              if (img != null && img.toString().isNotEmpty) {
                final imgStr = img.toString();
                final titleStr = title.toString().trim();
                final descStr = desc.toString().trim();
                if (imgStr.startsWith('http')) {
                  urls.add(imgStr);
                  titles.add(titleStr);
                  descs.add(descStr);
                } else if (imgStr.startsWith('cached_media/')) {
                  final localF = File('${dir.path}/$imgStr');
                  if (localF.existsSync()) {
                    files.add(localF);
                    titles.add(titleStr);
                    descs.add(descStr);
                  }
                }
              }
            }
          }
        }
      }

      final cacheDir = Directory('${dir.path}/cached_media');
      if (await cacheDir.exists()) {
        final list = await cacheDir.list().toList();
        for (final entity in list) {
          if (entity is File) {
            final name = entity.path.toLowerCase();
            if ((name.contains('amenity') || name.contains('banner') || name.contains('slider') || name.endsWith('.webp') || name.endsWith('.jpg') || name.endsWith('.png')) && !files.any((f) => f.path == entity.path)) {
              files.add(entity);
              titles.add('');
              descs.add('We wish you a pleasant stay');
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _dynamicAmenitiesFiles = files;
          _dynamicAmenitiesUrls = urls;
          _dynamicAmenitiesTitles = titles;
          _dynamicAmenitiesDescriptions = descs;
        });
      }
    } catch (e) {
      Logger.w('[TvWebviewScreen] Failed to load amenities wallpapers: $e');
    }
  }

  String _getCurrentAmenityTitle() {
    if (_dynamicAmenitiesTitles.isNotEmpty) {
      final idx = _screensaverBgIndex % _dynamicAmenitiesTitles.length;
      final title = _dynamicAmenitiesTitles[idx];
      if (title.trim().isNotEmpty) {
        return title.trim();
      }
    }
    return 'Welcome Guest!';
  }

  String _getCurrentAmenityDescription() {
    if (_dynamicAmenitiesDescriptions.isNotEmpty) {
      final idx = _screensaverBgIndex % _dynamicAmenitiesDescriptions.length;
      final desc = _dynamicAmenitiesDescriptions[idx];
      if (desc.trim().isNotEmpty) {
        return desc.trim();
      }
    }
    return 'We wish you a pleasant stay';
  }

  Widget _getScreensaverWallpaperWidget() {
    // 1. Dynamic downloaded hotel amenities files (e.g. amenity_*.webp)
    if (_dynamicAmenitiesFiles.isNotEmpty) {
      final file = _dynamicAmenitiesFiles[_screensaverBgIndex % _dynamicAmenitiesFiles.length];
      return Image.file(
        file,
        key: ValueKey(file.path + '$_screensaverBgIndex'),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0F172A)),
      );
    }

    // 2. Dynamic hotel amenities URLs from API
    if (_dynamicAmenitiesUrls.isNotEmpty) {
      final url = _dynamicAmenitiesUrls[_screensaverBgIndex % _dynamicAmenitiesUrls.length];
      return Image.network(
        url,
        key: ValueKey(url + '$_screensaverBgIndex'),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0F172A)),
      );
    }

    // 3. Fallback to main template background image (bgImage.png)
    if (_localBgFilePath != null && File(_localBgFilePath!).existsSync()) {
      return Image.file(
        File(_localBgFilePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    // 4. Default Dark Gradient (NO static stock images!)
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF020617)],
        ),
      ),
    );
  }

  String _getScreensaverHotelName() {
    try {
      final rawData = SharedPrefs.getString(AppConstants.tvLoginDataKey);
      if (rawData != null && rawData.isNotEmpty) {
        final decoded = jsonDecode(rawData);
        final dataMap = decoded['data'] ?? decoded;
        final name = dataMap['hotel']?['name'] ?? dataMap['hotel_name'] ?? dataMap['device']?['hotel_name'] ?? dataMap['hotel']?['hotel_name'];
        if (name != null && name.toString().trim().isNotEmpty) {
          return name.toString().toUpperCase();
        }
      }
    } catch (_) {}
    return 'PAX HOSPITALITY';
  }

  String _getScreensaverGreeting() {
    final hour = DateTime.now().hour;
    String timeOfDay = 'Good Afternoon';
    if (hour >= 5 && hour < 12) {
      timeOfDay = 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      timeOfDay = 'Good Afternoon';
    } else if (hour >= 17 && hour < 22) {
      timeOfDay = 'Good Evening';
    } else {
      timeOfDay = 'Good Night';
    }

    try {
      final rawData = SharedPrefs.getString(AppConstants.tvLoginDataKey);
      if (rawData != null && rawData.isNotEmpty) {
        final decoded = jsonDecode(rawData);
        final dataMap = decoded['data'] ?? decoded;
        final guest = dataMap['guest_name'] ?? dataMap['guest']?['name'] ?? 'Guest';
        return '$timeOfDay, $guest';
      }
    } catch (_) {}
    return '$timeOfDay, Guest';
  }

  Widget _buildDownloading(String message) {
    return LoadingWidget(
      type: LoadingType.tvScreen,
      subtitle: message,
    );
  }

  Widget _buildError(BuildContext context, String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            const CustomAppText(
              'Failed to Load Dashboard',
              
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(height: 8),
            CustomAppText(
              errorMessage,
              
              color: Colors.white60,
              fontSize: 13,
              height: 1.4,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                context.read<WebViewBloc>().add(RetryWebViewLoad());
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Load'),
            ),
          ],
        ),
      ),
    );
  }
}
