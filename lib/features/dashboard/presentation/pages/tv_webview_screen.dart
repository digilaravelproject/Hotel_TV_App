import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';
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

class TvWebviewScreen extends StatefulWidget {
  final bool clearCache;
  const TvWebviewScreen({Key? key, this.clearCache = false}) : super(key: key);

  @override
  State<TvWebviewScreen> createState() => _TvWebviewScreenState();
}

class _TvWebviewScreenState extends State<TvWebviewScreen> {
  WebViewController? _controller;
  final FocusNode _webViewFocusNode = FocusNode();
  final _backChannel = const MethodChannel('com.digiemperor.hotel/back_navigation');

  bool _showBottomUpdating = false;
  double _downloadProgress = 0.0;
  bool _showCenterLoading = false;

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

  @override
  void initState() {
    super.initState();
    _startInactivityTimer();
    _startScreensaverClock();
    _loadLocalBackgroundFile();
    _loadAmenitiesWallpapers();

    _backChannel.setMethodCallHandler((call) async {
      if (call.method == 'onBackPressed') {
        if (_showScreensaver) {
          _resetInactivityTimer();
          return;
        }
        final ctrl = _controller;
        if (ctrl != null) await _handleBackNavigation(ctrl);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initHybridSync();
      // Prompt Home Set Dialog once web template download completes & screen shows
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          AccessibilityService.requestDefaultLauncher();
        }
      });
    });
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: 2), () {
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
    final now = DateTime.now();
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
        Logger.w('[TvWebviewScreen] Token is unauthenticated! Performing automatic logout...');
        await TokenManager.clearToken();
        await SharedPrefs.remove(AppConstants.tvLoginDataKey);
        await LocalTemplateServer.stop();
        await TvSyncManager.dispose();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const TvLoginScreen()),
            (route) => false,
          );
        }
      },
    );
  }



  @override
  void dispose() {
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
        bloc.onPageFinished = () {
          if (mounted) {
            setState(() {
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
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  bool _isBackHandling = false;

  Future<void> _handleBackNavigation(WebViewController controller) async {
    print('[BackNavigation] onBackPressed triggered');
    if (_isBackHandling) {
      print('[BackNavigation] Already handling back, ignoring');
      return;
    }
    _isBackHandling = true;
    try {
      // 1. Check if JavaScript triggerTVBack handles closing an active overlay/popup first
      try {
        final Object? isTVBackHandled = await controller.runJavaScriptReturningResult(
          "typeof window.triggerTVBack === 'function' ? window.triggerTVBack() : false"
        );
        print('[BackNavigation] isTVBackHandled result: $isTVBackHandled');
        if (isTVBackHandled == true || isTVBackHandled == 'true' || isTVBackHandled == 1 || isTVBackHandled == '1') {
          print('[BackNavigation] Back press handled successfully by JS overlay/page');
          return;
        }
      } catch (e) {
        print('[BackNavigation] Error checking triggerTVBack: $e');
      }

      // 2. Fallback to path check: if we are on index/home page and no overlay was closed, ignore back to prevent exit.
      final currentUrl = await controller.currentUrl() ?? '';
      print('[BackNavigation] currentUrl: $currentUrl');
      final uri = Uri.tryParse(currentUrl);
      if (uri != null) {
        final path = uri.path;
        final hash = uri.fragment;
        print('[BackNavigation] Parsed path: $path, hash: $hash');
        if ((path == '/' || path == '/index.html') && (hash.isEmpty || hash == '/')) {
          print('[BackNavigation] On home page with no active overlays, ignoring back press to prevent app exit');
          return;
        }
      }

      // 3. Fallback to TVNavigation.goBack() or browser history.back() redirection
      print('[BackNavigation] Executing TVNavigation.goBack fallback redirection');
      await controller.runJavaScript('''
        (function() {
          if (typeof window.TVNavigation === 'object' && typeof window.TVNavigation.goBack === 'function') {
            window.TVNavigation.goBack();
          } else {
            window.history.back();
          }
        })();
      ''');
    } catch (e) {
      print('[BackNavigation] Error in back navigation: $e');
    } finally {
      _isBackHandling = false;
      print('[BackNavigation] Reset _isBackHandling');
    }
  }

  Widget _buildWebView(WebViewController controller) {
    _controller = controller;
    return Focus(
      focusNode: _webViewFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
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
            controller.runJavaScript(
              "if (typeof window.triggerTVBack === 'function') { window.triggerTVBack(); } else { history.back(); }"
            );
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
          WebViewWidget(controller: controller),
          
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
        final logo = dataMap['hotel']?['logo'] ?? dataMap['hotel']?['logo_url'] ?? dataMap['hotel_logo'];
        if (logo != null && logo.toString().isNotEmpty) {
          final logoStr = logo.toString();
          if (logoStr.startsWith('http')) {
            imageChild = Image.network(
              logoStr,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Image.asset('assets/logo.png', width: 52, height: 52, fit: BoxFit.cover),
            );
          } else {
            imageChild = Image.asset('assets/logo.png', width: 52, height: 52, fit: BoxFit.cover);
          }
        } else {
          imageChild = Image.asset('assets/logo.png', width: 52, height: 52, fit: BoxFit.cover);
        }
      } else {
        imageChild = Image.asset('assets/logo.png', width: 52, height: 52, fit: BoxFit.cover);
      }
    } catch (_) {
      imageChild = Image.asset(
        'assets/logo.png',
        width: 52,
        height: 52,
        fit: BoxFit.cover,
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
        child: imageChild,
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
