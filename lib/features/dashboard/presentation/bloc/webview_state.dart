import 'package:webview_flutter/webview_flutter.dart';

abstract class WebViewState {}

class WebViewInitial extends WebViewState {}

class WebViewDownloading extends WebViewState {
  final String message;
  WebViewDownloading({required this.message});
}

class WebViewReady extends WebViewState {
  final WebViewController controller;
  WebViewReady({required this.controller});
}

class WebViewError extends WebViewState {
  final String message;
  WebViewError({required this.message});
}
