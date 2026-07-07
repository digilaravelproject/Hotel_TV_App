import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../bloc/webview_bloc.dart';
import '../bloc/webview_event.dart';
import '../bloc/webview_state.dart';
import '../../../../core/widget/loading_widget.dart';
import '../../../../core/widget/custom_app_text.dart';

class TvWebviewScreen extends StatefulWidget {
  const TvWebviewScreen({Key? key}) : super(key: key);

  @override
  State<TvWebviewScreen> createState() => _TvWebviewScreenState();
}

class _TvWebviewScreenState extends State<TvWebviewScreen> {
  final FocusNode _webViewFocusNode = FocusNode();
  final MethodChannel _backChannel = const MethodChannel('com.digiemperor.hotel/back_handler');
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    _backChannel.setMethodCallHandler((call) async {
      if (call.method == 'onBackPressed') {
        final ctrl = _controller;
        if (ctrl != null) await _handleBackNavigation(ctrl);
      }
    });
  }

  @override
  void dispose() {
    _backChannel.setMethodCallHandler(null);
    _webViewFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WebViewBloc>(
      create: (_) => WebViewBloc()..add(InitializeWebView()),
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
      try {
        final Object isOverlayVisible = await controller.runJavaScriptReturningResult(
          "!!(document.getElementById('appsOverlay') && document.getElementById('appsOverlay').classList.contains('show'))"
        );
        print('[BackNavigation] isOverlayVisible: $isOverlayVisible');
        if (isOverlayVisible == true || isOverlayVisible == 'true' || isOverlayVisible == 1) {
          await controller.runJavaScript('window.closeAppsOverlay()');
          print('[BackNavigation] Closed overlay');
          return;
        }
      } catch (e) {
        print('[BackNavigation] Error checking overlay: $e');
      }

      final currentUrl = await controller.currentUrl() ?? '';
      print('[BackNavigation] currentUrl: $currentUrl');
      final uri = Uri.tryParse(currentUrl);
      if (uri != null) {
        final path = uri.path;
        final hash = uri.fragment;
        print('[BackNavigation] Parsed path: $path, hash: $hash');
        if ((path == '/' || path == '/index.html') && (hash.isEmpty || hash == '/')) {
          print('[BackNavigation] On home page, ignoring back press to prevent app exit');
          return;
        }
      }

      if (await controller.canGoBack()) {
        print('[BackNavigation] canGoBack is true, going back');
        await controller.goBack();
        return;
      } else {
        print('[BackNavigation] canGoBack is false');
      }

      final beforeUrl = await controller.currentUrl();
      print('[BackNavigation] Trying history.back() from $beforeUrl');
      await controller.runJavaScript('history.back()');
      await Future.delayed(const Duration(milliseconds: 300));
      final afterUrl = await controller.currentUrl();
      print('[BackNavigation] URL after history.back(): $afterUrl');
      if (beforeUrl != afterUrl) {
        print('[BackNavigation] history.back() succeeded');
        return;
      }
      print('[BackNavigation] history.back() did not change URL');
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
          if (key == LogicalKeyboardKey.arrowRight) {
            controller.runJavaScript("""
              (function() {
                var e = new KeyboardEvent('keydown', { 'key': 'ArrowRight', 'bubbles': true });
                Object.defineProperty(e, 'keyCode', { value: 39 });
                Object.defineProperty(e, 'which', { value: 39 });
                document.dispatchEvent(e);
              })();
            """);
          } else if (key == LogicalKeyboardKey.arrowLeft) {
            controller.runJavaScript("""
              (function() {
                var e = new KeyboardEvent('keydown', { 'key': 'ArrowLeft', 'bubbles': true });
                Object.defineProperty(e, 'keyCode', { value: 37 });
                Object.defineProperty(e, 'which', { value: 37 });
                document.dispatchEvent(e);
              })();
            """);
          } else if (key == LogicalKeyboardKey.arrowUp) {
            controller.runJavaScript("""
              (function() {
                var e = new KeyboardEvent('keydown', { 'key': 'ArrowUp', 'bubbles': true });
                Object.defineProperty(e, 'keyCode', { value: 38 });
                Object.defineProperty(e, 'which', { value: 38 });
                document.dispatchEvent(e);
              })();
            """);
          } else if (key == LogicalKeyboardKey.arrowDown) {
            controller.runJavaScript("""
              (function() {
                var e = new KeyboardEvent('keydown', { 'key': 'ArrowDown', 'bubbles': true });
                Object.defineProperty(e, 'keyCode', { value: 40 });
                Object.defineProperty(e, 'which', { value: 40 });
                document.dispatchEvent(e);
              })();
            """);
          } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.select) {
            controller.runJavaScript("""
              (function() {
                var e = new KeyboardEvent('keydown', { 'key': 'Enter', 'bubbles': true });
                Object.defineProperty(e, 'keyCode', { value: 13 });
                Object.defineProperty(e, 'which', { value: 13 });
                document.dispatchEvent(e);
              })();
            """);
            } else if (key == LogicalKeyboardKey.goBack) {
              _handleBackNavigation(controller);
              return KeyEventResult.handled;
            }
        }
        return KeyEventResult.ignored;
      },
      child: WebViewWidget(controller: controller),
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
