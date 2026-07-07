import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/services/storage/shared_prefs.dart';
import '../../../../core/constants/app_constants.dart';

class FlutterBridgeHandler {
  final WebViewController controller;
  final MethodChannel _tvChannel;
  StreamSubscription? _connectivitySub;

  FlutterBridgeHandler(this.controller)
      : _tvChannel = const MethodChannel('com.digiemperor.hotel/tv_control');

  void dispose() {
    _connectivitySub?.cancel();
  }

  Future<void> handleMessage(String rawMessage) async {
    try {
      final call = jsonDecode(rawMessage) as Map<String, dynamic>;
      final method = call['method'] as String?;
      final args = call['args'] as List<dynamic>?;
      final id = call['id'] as int?;

      if (method == null || id == null) return;

      dynamic result;
      try {
        result = await _dispatch(method, args ?? []);
      } catch (e) {
        await _reject(id, e.toString());
        return;
      }

      await _resolve(id, result);
    } catch (_) {}
  }

  Future<dynamic> _dispatch(String method, List<dynamic> args) async {
    switch (method) {
      case 'getInstalledApps':
      case 'getApps':
      case 'getAppList':
        final apps = await _tvChannel.invokeMethod<List>('getInstalledApps');
        return apps ?? [];

      case 'launchApp':
        final package = args[0] as String?;
        if (package == null) throw ArgumentError('package is required');
        await _tvChannel.invokeMethod('launchApp', {'package': package});
        return {'success': true};

      case 'openSettings':
        await _tvChannel.invokeMethod('openSettings');
        return {'success': true};

      case 'identifyDevice':
        final result = await _tvChannel.invokeMethod<Map>('identifyDevice');
        return result ?? {'success': false, 'error': 'identifyDevice returned null'};

      case 'getSystemInfo':
        final result = await _tvChannel.invokeMethod<Map>('getDeviceInfo');
        return result ?? {'success': false, 'error': 'getDeviceInfo returned null'};

      case 'launchHdmi':
        final model = args[0] as String?;
        if (model == null) throw ArgumentError('model is required');
        await _tvChannel.invokeMethod('launchHdmi', {'model': model});
        return {'success': true};

      case 'checkInternet':
        final result = await Connectivity().checkConnectivity();
        final isOnline = result.contains(ConnectivityResult.mobile) ||
            result.contains(ConnectivityResult.wifi) ||
            result.contains(ConnectivityResult.ethernet);
        return isOnline;

      case 'clearConfig':
        await _tvChannel.invokeMethod('clearConfig');
        return {'success': true};

      case 'getDeviceConfig':
        return SharedPrefs.getString(AppConstants.tvLoginDataKey) ?? '{}';

      case 'saveDeviceConfig':
        final config = args[0] as String?;
        if (config != null) {
          await SharedPrefs.setString(AppConstants.tvLoginDataKey, config);
        }
        return {'success': true};

      case 'getHdmiModels':
      case 'getTvInputs':
      case 'getLiveTvInputs':
        final result = await _tvChannel.invokeMethod<Map>('getHdmiModels');
        return result ?? {};

      case 'launchIptv':
        final package = args[0] as String?;
        if (package == null) throw ArgumentError('package is required');
        await _tvChannel.invokeMethod('launchApp', {'package': package});
        return {'success': true};

      case 'getPictureList':
        return [];

      case 'rotateImage':
        return {'success': false, 'error': 'Not implemented'};

      default:
        throw UnimplementedError('Method $method not implemented');
    }
  }

  Future<void> _resolve(int id, dynamic result) async {
    await controller.runJavaScript(
      'window.flutterBridge._resolve($id, ${jsonEncode(result)});',
    );
  }

  Future<void> _reject(int id, String error) async {
    await controller.runJavaScript(
      "window.flutterBridge._reject($id, '${error.replaceAll("'", "\\'")}');",
    );
  }
}
