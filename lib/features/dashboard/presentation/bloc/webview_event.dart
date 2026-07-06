abstract class WebViewEvent {}

class InitializeWebView extends WebViewEvent {}

class DownloadProgressUpdated extends WebViewEvent {
  final double progress;
  DownloadProgressUpdated({required this.progress});
}

class RetryWebViewLoad extends WebViewEvent {}
