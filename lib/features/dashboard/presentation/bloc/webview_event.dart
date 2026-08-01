abstract class WebViewEvent {}

class InitializeWebView extends WebViewEvent {
  final bool clearCache;
  InitializeWebView({this.clearCache = false});
}

class DownloadProgressUpdated extends WebViewEvent {
  final double progress;
  DownloadProgressUpdated({required this.progress});
}

class RetryWebViewLoad extends WebViewEvent {}
