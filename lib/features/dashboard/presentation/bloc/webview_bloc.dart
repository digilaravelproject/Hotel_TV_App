import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import '../../../../core/utils/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/template/template_manager_service.dart';
import '../../../../core/services/template/local_template_server.dart';
import '../../../../core/services/network/network_info.dart';
import '../../../../core/services/storage/shared_prefs.dart';
import '../../../../core/services/device/device_info_service.dart';
import '../../../../core/services/time/tv_time_service.dart';
import '../services/flutter_bridge_handler.dart';
import 'webview_event.dart';
import 'webview_state.dart';

class WebViewBloc extends Bloc<WebViewEvent, WebViewState> {
  void Function()? onPageStarted;
  void Function()? onPageFinished;
  void Function(String view)? onViewChanged;

  WebViewBloc() : super(WebViewInitial()) {
    on<InitializeWebView>(_onInitialize);
    on<DownloadProgressUpdated>(_onDownloadProgress);
    on<RetryWebViewLoad>(_onRetry);
  }

  Future<void> _onInitialize(
    InitializeWebView event,
    Emitter<WebViewState> emit,
  ) async {
    try {
      // data.json missing OR offline media not fully cached → block until ready.
      // This guarantees the page never renders remote/broken images on first load.
      final dir = await TemplateManagerService.getTemplateDirectory();
      final dataJsonFile = File('${dir.path}/data.json');
      final bool dataJsonExists = await dataJsonFile.exists();
      final bool mediaReady = await TemplateManagerService.isOfflineMediaReady();

      if (!dataJsonExists || !mediaReady) {
        // Offline → downloading would just burn connect/receive timeouts
        // (up to 23s per image) and hang startup. Skip blocking entirely;
        // cached images still render, remote ones retry on next online sync.
        final bool online = await NetworkInfo.checkConnectivity();
        if (online) {
          // Bounded wait: quick 4s check so startup is instant
          await TemplateManagerService.regenerateDataJson()
              .timeout(const Duration(seconds: 4), onTimeout: () {});
        } else {
          Logger.w('[WebViewBloc] Offline and media cache incomplete — skipping blocking cache fill.');
          if (!dataJsonExists) {
            // data.json is required to render anything at all — write it from
            // whatever is stored, without network access.
            await TemplateManagerService.regenerateDataJson();
          }
        }
      } else {
        // Everything cached → regenerate in the background (non-blocking).
        TemplateManagerService.regenerateDataJson().catchError((e) {
          Logger.e('[WebViewBloc] Background regenerateDataJson failed: $e');
        });
      }

      var exists = await TemplateManagerService.isTemplateDownloaded();
      if (!exists) {
        emit(WebViewDownloading(message: 'Installing...'));
        await TemplateManagerService.downloadTemplateFromSavedData(
          onProgress: (progress) {
            if (!isClosed) {
              add(DownloadProgressUpdated(progress: progress));
            }
          },
        );
        exists = await TemplateManagerService.isTemplateDownloaded();
      }

      if (!exists) {
        emit(WebViewError(
          message:
              'Template files not found. Please ensure the server has active templates.',
        ));
        return;
      }

      await LocalTemplateServer.start();

      final controller = WebViewController();
      if (event.clearCache) {
        await controller.clearCache();
        try {
          await controller.clearLocalStorage();
        } catch (_) {}
      }
      final bridgeHandler = FlutterBridgeHandler(
        controller,
        onViewChanged: (view) => onViewChanged?.call(view),
      );
      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setOnConsoleMessage((JavaScriptConsoleMessage message) {
          Logger.i('[WebViewConsole][${message.level.name}] ${message.message}');
          if (message.level == JavaScriptLogLevel.error) {
            Logger.e('[WebViewConsoleError] ${message.message}');
          }
        })
        ..addJavaScriptChannel('FlutterBridge',
            onMessageReceived: (message) {
          bridgeHandler.handleMessage(message.message);
        })
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              _injectLoginData(controller);
              if (onPageStarted != null) {
                onPageStarted!();
              }
            },
            onPageFinished: (url) {
              _injectTvNavigationJs(controller);
              _injectLoginData(controller);
              if (onPageFinished != null) {
                onPageFinished!();
              }
            },
            onWebResourceError: (error) async {
              if (error.isForMainFrame == true && !isClosed) {
                Logger.w('[WebViewBloc] Main frame load glitch (${error.description}). Retrying server bind...');
                try {
                  await LocalTemplateServer.start();
                  final p = await LocalTemplateServer.port;
                  await controller.loadRequest(Uri.parse('http://127.0.0.1:$p/index.html'));
                } catch (_) {
                  if (!isClosed) {
                    emit(WebViewError(
                      message: 'Failed to load asset: ${error.description}',
                    ));
                  }
                }
              }
            },
          ),
        );

      if (controller.platform is AndroidWebViewController) {
        AndroidWebViewController.enableDebugging(true);
        try {
          final androidController = controller.platform as AndroidWebViewController;
          await androidController.setMediaPlaybackRequiresUserGesture(false);
          await androidController.setAllowFileAccess(true);
          await androidController.setAllowContentAccess(true);
          await androidController.setTextZoom(100);
          await androidController.setMixedContentMode(MixedContentMode.alwaysAllow);
        } catch (_) {}
      }

      await Future.delayed(const Duration(milliseconds: 250));
      final port = await LocalTemplateServer.port;
      final serverUrl = 'http://127.0.0.1:$port/index.html';
      Logger.i('[WebViewBloc] Loading template from LocalTemplateServer: $serverUrl');
      await controller.loadRequest(Uri.parse(serverUrl));

      emit(WebViewReady(controller: controller));
    } catch (e) {
      emit(WebViewError(message: 'Error loading web template: $e'));
    }
  }

  void _onDownloadProgress(
    DownloadProgressUpdated event,
    Emitter<WebViewState> emit,
  ) {
    emit(WebViewDownloading(
      message: 'Installing: ${(event.progress * 100).toStringAsFixed(0)}%',
    ));
  }

  void _onRetry(RetryWebViewLoad event, Emitter<WebViewState> emit) {
    add(InitializeWebView());
  }

  Future<void> _injectTvNavigationJs(WebViewController controller) async {
    const js = '''
(function() {
  function makeFocusable() {
    if (!document.body) return;
    document.body.setAttribute('tabindex', '-1');
    var all = document.querySelectorAll('a, button, input, select, textarea, [onclick], [role="button"], [role="link"], [role="tab"], [role="menuitem"], [tabindex]');
    all.forEach(function(e) {
      if (!e.hasAttribute('tabindex')) e.setAttribute('tabindex', '0');
    });
  }
  makeFocusable();
  var s = document.createElement('style');
  s.textContent = '*:focus { outline: 2px solid #6366F1 !important; outline-offset: 2px !important; }';
  if (document.head) document.head.appendChild(s);
  var first = document.querySelector('[tabindex]:not([tabindex="-1"])');
  if (first) first.focus();
})();
''';
    try {
      await controller.runJavaScript(js);
    } catch (_) {
    }
  }

  Future<void> _injectLoginData(WebViewController controller) async {
    try {
      final raw = SharedPrefs.getString(AppConstants.tvLoginDataKey);
      if (raw == null || raw.isEmpty) return;
      final b64 = base64Encode(utf8.encode(raw));
      await controller.runJavaScript('''
        (function() {
          try {
            window.tvLoginData = JSON.parse(atob('$b64'));
            var normalized = window.tvLoginData.data || window.tvLoginData;
            localStorage.setItem('cachedHotelData', JSON.stringify(normalized));
          } catch(e) {}
        })();
      ''');
    } catch (_) {
    }
    // Cast screen device name patch karo
    await _injectCastDeviceNamePatch(controller);
    await _injectNetworkFallbackPatch(controller);
    await _injectTvInputsPatch(controller);
    await _injectClockSyncPatch(controller);
    await _injectApplicationsPatch(controller);
  }

  /// Injects clock calibration & timezone sync patch into WebView runtime
  Future<void> _injectClockSyncPatch(WebViewController controller) async {
    try {
      final jsPatch = TvTimeService.generateJsClockSyncPatch();
      await controller.runJavaScript(jsPatch);
    } catch (e) {
      Logger.w('[WebViewBloc] Error injecting clock sync patch: $e');
    }
  }

  /// TVScreenCastController ke getCastDeviceName() ko override karta hai
  /// Alpine.js app.js line 53: ...TVScreenCastController spread hota hai init pe
  /// Isliye window.TVScreenCastController patch karne se kuch nahi hota — Alpine ki copy alag hai
  /// Fix: el._x_dataStack[0] se direct data object patch karo
  Future<void> _injectCastDeviceNamePatch(WebViewController controller) async {
    try {
      final tvDisplayName = SharedPrefs.getString('tv_display_name') ?? '';
      if (tvDisplayName.isEmpty) return;

      final safeName = tvDisplayName.replaceAll("'", r"\'");

      await controller.runJavaScript(
        "(function() {"
        "  var N = '$safeName';"
        "  var patch = function() {"
        // 1. Global TVScreenCastController patch (future Alpine inits ke liye)
        "    if (window.TVScreenCastController) {"
        "      window.TVScreenCastController.getCastDeviceName = function() { return N; };"
        "      window.TVScreenCastController.fetchCastDeviceInfo = async function() { this.castDeviceName = N; };"
        "      window.TVScreenCastController.castDeviceName = N;"
        "    }"
        // 2. Already mounted Alpine components — _x_dataStack[0] se raw data object lo
        "    document.querySelectorAll('[x-data]').forEach(function(el) {"
        "      var stack = el._x_dataStack;"
        "      if (!stack) return;"
        "      for (var i = 0; i < stack.length; i++) {"
        "        var obj = stack[i];"
        "        if (obj && typeof obj.getCastDeviceName === 'function') {"
        "          obj.getCastDeviceName = function() { return N; };"
        "          obj.castDeviceName = N;"
        "          obj.fetchCastDeviceInfo = async function() { this.castDeviceName = N; };"
        "        }"
        "      }"
        "    });"
        "  };"
        "  patch();"
        "  document.addEventListener('alpine:initialized', patch);"
        "  setTimeout(patch, 300);"
        "  setTimeout(patch, 1000);"
        "  setTimeout(patch, 2500);"
        "})();",
      );
    } catch (_) {}
  }

  Future<void> _injectNetworkFallbackPatch(WebViewController controller) async {
    try {
      await controller.runJavaScript(
        "(function() {"
        "  var patch = function() {"
        "    document.querySelectorAll('[x-data]').forEach(function(el) {"
        "      var stack = el._x_dataStack;"
        "      if (!stack) return;"
        "      for (var i = 0; i < stack.length; i++) {"
        "        var obj = stack[i];"
        "        if (obj && obj.hwData) {"
        "          if (obj.hwData.gateway === '10.0.2.2') obj.hwData.gateway = '';"
        "          if (obj.hwData.subnet === '255.255.255.0') obj.hwData.subnet = '';"
        "          if (obj.hwData.dns === '8.8.8.8') obj.hwData.dns = '';"
        "        }"
        "      }"
        "    });"
        "  };"
        "  patch();"
        "  setTimeout(patch, 500);"
        "  setTimeout(patch, 1500);"
        "})();",
      );
    } catch (_) {}
  }

  Future<void> _injectTvInputsPatch(WebViewController controller) async {
    try {
      final info = await DeviceInfoService.getFullDeviceInfo();
      final List<dynamic>? rawPorts = info['tv_inputs'] as List<dynamic>?;
      if (rawPorts == null || rawPorts.isEmpty) return;

      final ports = rawPorts.map((e) => e.toString()).toList();
      final portsJson = jsonEncode(ports);

      await controller.runJavaScript(
        "(function() {"
        "  var realPorts = $portsJson;"
        "  var patch = function() {"
        "    document.querySelectorAll('[x-data]').forEach(function(el) {"
        "      var stack = el._x_dataStack;"
        "      if (!stack) return;"
        "      for (var i = 0; i < stack.length; i++) {"
        "        var obj = stack[i];"
        "        if (obj && obj.availableTvPorts) {"
        "          if (JSON.stringify(obj.availableTvPorts) !== JSON.stringify(realPorts)) {"
        "            obj.availableTvPorts = realPorts;"
        "          }"
        "        }"
        "      }"
        "    });"
        "  };"
        "  setInterval(patch, 500);"
        "})();",
      );
    } catch (_) {}
  }

  Future<void> _injectApplicationsPatch(WebViewController controller) async {
    try {
      await controller.runJavaScript(r'''
        (function() {
          function patchAppsGrid() {
            var container = document.getElementById('apps-grid-container');
            if (!container) return;

            container.style.display = 'grid';
            container.style.gridTemplateColumns = 'repeat(5, minmax(0, 1fr))';
            container.style.gap = '1.5rem';
            container.style.minHeight = '420px';
            container.style.maxHeight = '560px';
            container.style.overflowY = 'auto';

            // Only populate if container has no rendered cards
            var renderedCards = container.querySelectorAll('.app-card-item');
            if (renderedCards.length === 0) {
              var apps = [];
              if (window.TVAppsController && typeof window.TVAppsController.getActiveOttList === 'function') {
                apps = window.TVAppsController.getActiveOttList();
              }
              if (!apps || apps.length === 0) {
                if (window.tvAppInstance && Array.isArray(window.tvAppInstance.activeOttList)) {
                  apps = window.tvAppInstance.activeOttList;
                }
              }
              if (!apps || apps.length === 0) return;

              var cardsHtml = '';
              apps.forEach(function(app, idx) {
                var name = app.name || 'App';
                var pkg = app.package_name || app.package || app.packageName || app.id || '';
                var icon = '';
                if (window.TVAppsController && typeof window.TVAppsController.getAppIcon === 'function') {
                  try { icon = window.TVAppsController.getAppIcon(app); } catch(_) {}
                }
                if (!icon && app.icon) icon = app.icon;
                if (!icon && app.id) icon = 'assets/images/ott/' + app.id + '.svg';
                
                var initials = name.trim().split(/\s+/).map(function(w){return w[0];}).join('').toUpperCase().substring(0, 3);
                if (!initials) initials = 'APP';

                var iconInner = icon 
                  ? '<img src="' + icon + '" class="w-full h-full object-contain" style="max-width:64px;max-height:64px;" onerror="this.style.display=\'none\';this.nextElementSibling.style.display=\'block\';"><span style="display:none;font-weight:900;font-size:1.5rem;color:#ffc700;">' + initials + '</span>'
                  : '<span style="font-weight:900;font-size:1.5rem;color:#ffc700;">' + initials + '</span>';

                cardsHtml += '<div tabindex="0" id="app_card_' + idx + '" data-package="' + pkg + '" ' +
                  'class="app-card-item h-52 rounded-2xl flex flex-col items-center justify-between p-4 cursor-pointer text-center relative border border-white/10 bg-white/5" ' +
                  'style="transition: all 0.2s ease; outline: none;" ' +
                  'onclick="if(window.flutterBridge && window.flutterBridge.launchApp){ window.flutterBridge.launchApp(\'' + pkg + '\'); }">' +
                  '<div class="w-full flex-1 flex items-center justify-center pt-1 pb-2">' +
                  '  <div class="w-24 h-24 rounded-2xl flex items-center justify-center p-3 bg-black/40 border border-white/10 shadow-md">' +
                       iconInner +
                  '  </div>' +
                  '</div>' +
                  '<div class="w-full pt-2 border-t border-white/10 flex flex-col items-center">' +
                  '  <h3 class="text-sm font-extrabold text-white truncate max-w-full">' + name + '</h3>' +
                  '  <div class="flex items-center gap-1.5 mt-0.5">' +
                  '    <span class="w-1.5 h-1.5 rounded-full bg-emerald-400"></span>' +
                  '    <span class="text-[10px] font-bold text-slate-400 uppercase">OPEN APP</span>' +
                  '  </div>' +
                  '</div>' +
                  '</div>';
              });

              if (cardsHtml) {
                container.innerHTML = cardsHtml;
              }
            }
          }

          setInterval(patchAppsGrid, 600);
        })();
      ''');
    } catch (_) {}
  }

  @override
  Future<void> close() {
    LocalTemplateServer.stop();
    return super.close();
  }
}
