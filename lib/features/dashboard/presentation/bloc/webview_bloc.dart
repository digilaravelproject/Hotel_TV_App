import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../../../../core/services/template/template_manager_service.dart';
import '../../../../core/services/template/local_template_server.dart';
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
        await TemplateManagerService.checkAndUpdateTemplateSilent(
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
      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (url) {
              _injectTvNavigationJs(controller);
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

      TemplateManagerService.checkAndUpdateTemplateSilent();
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
  s.textContent = '*:focus { outline: 2px solid #6366F1 !important; outline-offset: 2px !important; }';
  document.head.appendChild(s);
  var first = document.querySelector('[tabindex]:not([tabindex="-1"])');
  if (first) first.focus();
})();
''';
    try {
      await controller.runJavaScript(js);
    } catch (_) {
    }
  }

  @override
  Future<void> close() {
    LocalTemplateServer.stop();
    return super.close();
  }
}
