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
import '../../../../core/utils/logger.dart';
import '../../../../core/services/template/local_template_server.dart';
import '../../../../core/services/storage/shared_prefs.dart';
import '../../../../core/services/storage/token_manger.dart';
import '../../../../core/services/device/device_info_service.dart';
import '../../../../core/services/sync/tv_sync_manager.dart';
import '../../../../core/services/device/accessibility_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../authentication/presentation/pages/tv_login_screen.dart';

import '../../../../shared/widgets/tv_error_widget.dart';
import '../../../../shared/widgets/tv_loading_overlay.dart';
import '../../../../shared/widgets/tv_exit_dialog.dart';
import '../../../../shared/widgets/tv_demo_badge.dart';
import '../../../screensaver/controllers/screensaver_controller.dart';
import '../../../screensaver/widgets/screensaver_overlay_widget.dart';
import '../../../web_bridge/services/tv_js_bridge_injector.dart';

class TvWebviewScreen extends StatefulWidget {
  final bool clearCache;
  const TvWebviewScreen({Key? key, this.clearCache = false}) : super(key: key);

  @override
  State<TvWebviewScreen> createState() => _TvWebviewScreenState();
}

class _TvWebviewScreenState extends State<TvWebviewScreen> with WidgetsBindingObserver {
  WebViewController? _controller;
  final FocusNode _webViewFocusNode = FocusNode();
  final MethodChannel _backChannel = const MethodChannel('com.paxtv.hospitality/back_navigation');
  final MethodChannel _tvControlChannel = const MethodChannel('com.paxtv.hospitality/tv_control');

  late final ScreensaverController _screensaverController;

  bool _isWebViewLoaded = false;
  bool _isDemoMode = false;
  int _demoDaysLeft = 0;
  bool _isExitDialogOpen = false;
  bool _isBackHandling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _isDemoMode = SharedPrefs.getBool(AppConstants.isDemoModeKey) ?? false;
    _demoDaysLeft = SharedPrefs.getInt(AppConstants.demoDaysLeftKey) ?? 0;

    _screensaverController = ScreensaverController()..initialize();

    _setupPlatformChannels();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initHybridSync();
      if (!_isDemoMode) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            AccessibilityService.requestDefaultLauncher();
          }
        });
      }
    });
  }

  void _setupPlatformChannels() {
    // 1. Back and Home Navigation Channel from Native Remote Listener
    _backChannel.setMethodCallHandler((call) async {
      if (call.method == 'onBackPressed') {
        if (_screensaverController.isVisible) {
          _screensaverController.resetInactivityTimer();
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
        if (_screensaverController.isVisible) {
          _screensaverController.resetInactivityTimer();
          return;
        }
        if (_isExitDialogOpen && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          _isExitDialogOpen = false;
          return;
        }
        final ctrl = _controller;
        if (ctrl != null) await _handleHomeNavigation(ctrl);
      }
    });

    // 2. TV Control Channel for Real-time HDMI Input state updates
    _tvControlChannel.setMethodCallHandler((call) async {
      if (call.method == 'onTvInputStateChanged') {
        Logger.i('[TvWebviewScreen] TV HDMI Input state changed in realtime. Refreshing inputs in UI...');
        try {
          _controller?.runJavaScript(
            "try { if (window.tvAppInstance && typeof window.tvAppInstance.refreshInputs === 'function') { window.tvAppInstance.refreshInputs(); } else { window.dispatchEvent(new Event('tv_inputs_changed')); } } catch(e) {}"
          );
        } catch (_) {}
      }
    });

    _tvControlChannel
        .invokeMethod('setDemoMode', {'enabled': _isDemoMode})
        .catchError((_) => null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      if (_isExitDialogOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _isExitDialogOpen = false;
      }
      // TV standby / screen off: pause video and audio
      try {
        _controller?.runJavaScript(
          "try { document.querySelectorAll('video, audio').forEach(el => el.pause()); } catch(e) {}"
        );
      } catch (_) {}
    }

    if (state == AppLifecycleState.resumed) {
      _screensaverController.resetInactivityTimer();
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
        await _performCleanLogout(notice: reason);
      },
      onDemoExpired: () async {
        const reason = 'Demo trial period has expired on server (403).';
        Logger.lastExitOrErrorReason = reason;
        await _performCleanLogout(notice: reason);
      },
    );
  }

  Future<void> _performCleanLogout({required String notice}) async {
    await TokenManager.clearToken();
    await SharedPrefs.remove(AppConstants.tvLoginDataKey);
    await SharedPrefs.remove(AppConstants.isDemoModeKey);
    await SharedPrefs.remove(AppConstants.demoExpiresAtKey);
    await SharedPrefs.remove(AppConstants.demoDaysLeftKey);
    _tvControlChannel.invokeMethod('setDemoMode', {'enabled': false}).catchError((_) => null);
    await LocalTemplateServer.stop();
    await TvSyncManager.dispose();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => TvLoginScreen(expiredNotice: notice),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _handleBackNavigation(WebViewController controller) async {
    Logger.i('[BackNavigation] onBackPressed triggered (isDemoMode=$_isDemoMode)');
    if (_isExitDialogOpen) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _isExitDialogOpen = false;
      }
      return;
    }
    if (_isBackHandling) return;
    _isBackHandling = true;

    try {
      // 1. Check if JavaScript subview can handle back
      final jsHandled = await TvJsBridgeInjector.handleJsBack(controller);
      if (jsHandled) {
        Logger.i('[BackNavigation] Successfully handled back within JS subview/menu');
        return;
      }

      // 2. Check browser history
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
        _isExitDialogOpen = true;
        TvExitDialog.show(
          context,
          onConfirm: () => _performCleanLogout(notice: 'Exited Demo Mode successfully.'),
        ).then((_) {
          _isExitDialogOpen = false;
          if (mounted) _webViewFocusNode.requestFocus();
        });
      } else {
        Logger.i('[BackNavigation] On home in Kiosk mode -> Ignoring back press');
      }
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
      final isAtHome = await TvJsBridgeInjector.isAtHome(controller);
      if (!isAtHome) {
        Logger.i('[HomeNavigation] Sub-view was open; returned to TV App Home screen');
        return;
      }

      if (_isDemoMode) {
        try {
          await _tvControlChannel.invokeMethod('exitToTvHome');
        } catch (_) {
          SystemNavigator.pop();
        }
      }
    } catch (e) {
      Logger.e('[HomeNavigation] Error in home navigation: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _screensaverController.dispose();
    _webViewFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final bloc = WebViewBloc();
        bloc.onPageStarted = () {
          if (mounted) setState(() => _isWebViewLoaded = false);
        };
        bloc.onPageFinished = () {
          if (mounted) {
            setState(() => _isWebViewLoaded = true);
            final ctrl = _controller;
            if (ctrl != null) {
              TvJsBridgeInjector.injectPageFinishedScripts(ctrl);
            }
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
                return TvLoadingOverlay(message: state.message);
              }
              if (state is WebViewError) {
                return TvErrorWidget(
                  errorMessage: state.message,
                  onRetry: () => context.read<WebViewBloc>().add(RetryWebViewLoad()),
                );
              }
              if (state is WebViewReady) {
                return _buildWebViewStack(state.controller);
              }
              return const TvLoadingOverlay(message: 'Loading Hotel TV...');
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWebViewStack(WebViewController controller) {
    _controller = controller;

    return Focus(
      focusNode: _webViewFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) => _handleRemoteKeyEvent(controller, event),
      child: Stack(
        children: [
          // 1. Android Platform WebView
          Positioned.fill(
            child: (!kIsWeb && Platform.isAndroid && controller.platform is AndroidWebViewController)
                ? WebViewWidget.fromPlatformCreationParams(
                    params: AndroidWebViewWidgetCreationParams(
                      controller: controller.platform,
                      displayWithHybridComposition: true,
                    ),
                  )
                : WebViewWidget(controller: controller),
          ),

          // 2. Demo Mode Ribbon (Top-Right)
          if (_isDemoMode)
            Positioned(
              top: 24,
              right: 32,
              child: TvDemoBadge(
                demoDaysLeft: _demoDaysLeft,
                isVisible: _isWebViewLoaded,
              ),
            ),

          // 3. Isolated Screensaver Overlay
          AnimatedBuilder(
            animation: _screensaverController,
            builder: (context, _) => ScreensaverOverlayWidget(
              controller: _screensaverController,
            ),
          ),
        ],
      ),
    );
  }

  KeyEventResult _handleRemoteKeyEvent(WebViewController controller, KeyEvent event) {
    if (_isExitDialogOpen) return KeyEventResult.ignored;

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _screensaverController.resetInactivityTimer();
      if (_screensaverController.isVisible) {
        return KeyEventResult.handled;
      }

      final key = event.logicalKey;
      final physicalKey = event.physicalKey;
      final int keyId = key.keyId;

      int? targetKeyCode;
      String? targetKeyName;

      // Remote D-Pad Navigation
      if (key == LogicalKeyboardKey.arrowLeft || keyId == 0x00070050 || physicalKey.usbHidUsage == 0x00070050) {
        targetKeyCode = 37;
        targetKeyName = 'ArrowLeft';
      } else if (key == LogicalKeyboardKey.arrowRight || keyId == 0x0007004f || physicalKey.usbHidUsage == 0x0007004f) {
        targetKeyCode = 39;
        targetKeyName = 'ArrowRight';
      } else if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.channelUp || keyId == 0x00070052) {
        targetKeyCode = 38;
        targetKeyName = 'ArrowUp';
      } else if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.channelDown || keyId == 0x00070051) {
        targetKeyCode = 40;
        targetKeyName = 'ArrowDown';
      } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.space) {
        targetKeyCode = 13;
        targetKeyName = 'Enter';
      } else if (key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.backspace) {
        _handleBackNavigation(controller);
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.home) {
        _handleHomeNavigation(controller);
        return KeyEventResult.handled;
      } else if (keyId >= LogicalKeyboardKey.digit0.keyId && keyId <= LogicalKeyboardKey.digit9.keyId) {
        final digit = key.keyLabel;
        controller.runJavaScript("if (typeof window.TVKeyInjector === 'object') { window.TVKeyInjector.triggerNumber('$digit'); }");
        return KeyEventResult.handled;
      }

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
  }
}
