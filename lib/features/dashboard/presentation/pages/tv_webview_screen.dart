import 'dart:async';
import 'dart:convert';
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

  @override
  void initState() {
    super.initState();
    _backChannel.setMethodCallHandler((call) async {
      if (call.method == 'onBackPressed') {
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
      final info = await DeviceInfoService.getFullDeviceInfo();
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
        ],
      ),
    );
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
