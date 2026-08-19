import 'dart:convert';
import 'dart:io';
import '../../../../core/utils/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/template/template_manager_service.dart';
import '../../../../core/services/template/local_template_server.dart';
import '../../../../core/services/storage/shared_prefs.dart';
import '../services/flutter_bridge_handler.dart';
import 'webview_event.dart';
import 'webview_state.dart';

class WebViewBloc extends Bloc<WebViewEvent, WebViewState> {
  void Function()? onPageFinished;

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
      // Only block UI with regeneration if data.json doesn't exist yet
      final dir = await TemplateManagerService.getTemplateDirectory();
      final dataJsonFile = File('${dir.path}/data.json');
      if (!await dataJsonFile.exists()) {
        await TemplateManagerService.regenerateDataJson();
      } else {
        // Otherwise, regenerate in the background to avoid blocking startup (especially when offline)
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
      final bridgeHandler = FlutterBridgeHandler(controller);
      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel('FlutterBridge',
            onMessageReceived: (message) {
          bridgeHandler.handleMessage(message.message);
        })
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              _injectLoginData(controller);
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
  }

  @override
  Future<void> close() {
    LocalTemplateServer.stop();
    return super.close();
  }
}
