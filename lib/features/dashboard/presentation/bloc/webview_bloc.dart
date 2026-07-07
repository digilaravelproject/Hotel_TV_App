import 'dart:convert';
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
      await TemplateManagerService.regenerateDataJson();

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
      final bridgeHandler = FlutterBridgeHandler(controller);
      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel('FlutterBridge',
            onMessageReceived: (message) {
          bridgeHandler.handleMessage(message.message);
        })
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (url) {
              _injectTvNavigationJs(controller);
              _injectLoginData(controller);
            },
            onWebResourceError: (error) {
              if (!isClosed) {
                emit(WebViewError(
                  message: 'Failed to load asset: ${error.description}',
                ));
              }
            },
          ),
        );

      if (controller.platform is AndroidWebViewController) {
        AndroidWebViewController.enableDebugging(true);
      }

      await controller
          .loadRequest(Uri.parse('${LocalTemplateServer.baseUrl}/index.html'));

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
    document.body.setAttribute('tabindex', '-1');
    var all = document.querySelectorAll('a, button, input, select, textarea, [onclick], [role="button"], [role="link"], [role="tab"], [role="menuitem"], [tabindex]');
    all.forEach(function(e) {
      if (!e.hasAttribute('tabindex')) e.setAttribute('tabindex', '0');
    });
  }
  makeFocusable();
  var s = document.createElement('style');
  s.textContent = '*:focus { outline: 2px solid #6366F1 !important; outline-offset: 2px !important; } #appsCloseBtn { display: none !important; }';
  document.head.appendChild(s);
  var first = document.querySelector('[tabindex]:not([tabindex="-1"])');
  if (first) first.focus();

  // Override template behavior for Applications and Live TV overlays
  window.openAppsOverlay = function() {
    var overlay = document.getElementById('appsOverlay');
    if (!overlay) return;
    overlay.classList.add('show');
    document.getElementById('mainUI').style.display = 'none';
    window.history.pushState(null, "", window.location.href);

    var title = overlay.querySelector('.apps-title');
    if (title) title.textContent = "Applications";
    
    var appsContainer = document.getElementById('apps-container');
    if (appsContainer) appsContainer.style.display = '';
    
    var tvTitle = overlay.querySelector('.tv-section-title');
    if (tvTitle) tvTitle.style.display = 'none';
    
    var tvContainer = document.getElementById('tv-inputs-container');
    if (tvContainer) tvContainer.style.display = 'none';

    if (typeof loadApplications === 'function') loadApplications();

    var closeBtn = document.getElementById('appsCloseBtn');
    if (closeBtn) setTimeout(function() { closeBtn.focus(); }, 100);
  };

  window.handleLiveTV = function() {
    var overlay = document.getElementById('appsOverlay');
    if (!overlay) return;
    overlay.classList.add('show');
    document.getElementById('mainUI').style.display = 'none';
    window.history.pushState(null, "", window.location.href);

    var title = overlay.querySelector('.apps-title');
    if (title) title.textContent = "Live TV";
    
    var appsContainer = document.getElementById('apps-container');
    if (appsContainer) appsContainer.style.display = 'none';
    
    var tvTitle = overlay.querySelector('.tv-section-title');
    if (tvTitle) tvTitle.style.display = 'none';
    
    var tvContainer = document.getElementById('tv-inputs-container');
    if (tvContainer) tvContainer.style.display = '';

    if (typeof loadTvInputs === 'function') loadTvInputs();

    var closeBtn = document.getElementById('appsCloseBtn');
    if (closeBtn) setTimeout(function() { closeBtn.focus(); }, 100);
  };

  window.loadTvInputs = async function() {
    var container = document.getElementById('tv-inputs-container');
    if (!container) return;
    try {
      var inputs = await window.flutterBridge.getTvInputs();
      var selectedHdmi = localStorage.getItem('selectedHdmiPort') || '';
      try {
        var serial = localStorage.getItem('deviceSerial');
        if (serial) {
          var config = await fetch('admin/devices/' + serial + '.json?t=' + Date.now()).then(r => r.json());
          if (config && config.tv_source === "HDMI") {
            selectedHdmi = config.package;
            localStorage.setItem('selectedHdmiPort', selectedHdmi);
          }
        }
      } catch (e) {}

      if (!selectedHdmi && inputs && inputs.length > 0) {
        selectedHdmi = inputs[0].id || '';
      }

      container.innerHTML = '';
      if (!inputs || inputs.length === 0) {
        container.innerHTML = '<div style="color:#888;font-size:1.1vw;">No TV inputs available</div>';
        return;
      }
      inputs.forEach(function(input) {
        var btn = document.createElement('button');
        btn.className = 'tv-input-btn';
        btn.tabIndex = 0;
        var inputId = input.id || '';
        var isSelected = selectedHdmi && (selectedHdmi.toLowerCase() === inputId.toLowerCase());
        btn.textContent = input.label || input.id || 'HDMI';
        if (isSelected) {
          btn.style.borderColor = '#b38a2d';
          btn.style.background = 'rgba(179,138,45,0.35)';
          btn.style.boxShadow = '0 0 10px rgba(179,138,45,0.5)';
        }
        btn.setAttribute('data-model', inputId);
        btn.addEventListener('click', function() {
          var model = this.getAttribute('data-model');
          if (model) {
            localStorage.setItem('selectedHdmiPort', model);
            window.loadTvInputs();
            if (window.flutterBridge && window.flutterBridge.launchHdmi) {
              closeAppsOverlay();
              window.flutterBridge.launchHdmi(model).catch(function(err) {});
            }
          }
        });
        btn.addEventListener('keydown', function(e) {
          if (e.key === 'Enter' || e.keyCode === 13) {
            this.click();
          }
        });
        container.appendChild(btn);
      });
    } catch (e) {
      container.innerHTML = '<div style="color:#888;font-size:1.1vw;">No TV inputs available</div>';
    }
  };
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
      await controller.runJavaScript(
        "window.tvLoginData = JSON.parse(atob('$b64'));",
      );
    } catch (_) {
    }
  }

  @override
  Future<void> close() {
    LocalTemplateServer.stop();
    return super.close();
  }
}
