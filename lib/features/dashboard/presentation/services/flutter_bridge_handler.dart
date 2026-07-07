import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/services/storage/shared_prefs.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/device/device_info_service.dart';

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
      print('[WebToFlutter] Received Message: $rawMessage');
      final call = jsonDecode(rawMessage) as Map<String, dynamic>;
      final method = call['method'] as String?;
      final args = call['args'] as List<dynamic>?;
      final id = call['id'] as int?;

      if (method == null || id == null) {
        print('[WebToFlutter] Invalid message format (missing method or id)');
        return;
      }

      print('[WebToFlutter] Dispatching: method=$method, args=$args, id=$id');
      dynamic result;
      try {
        result = await _dispatch(method, args ?? []);
      } catch (e) {
        print('[WebToFlutter] Error in method $method: $e');
        await _reject(id, e.toString());
        return;
      }

      print('[WebToFlutter] Resolved: method=$method, result=$result');
      await _resolve(id, result);
    } catch (e) {
      print('[WebToFlutter] Exception parsing message: $e');
    }
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
      case 'getSystemInfo':
        final info = await DeviceInfoService.getFullDeviceInfo();
        final deviceMap = {
          'device_id': info['deviceId'] ?? '',
          'mac_address': info['macAddress'] ?? '',
          'ip_address': info['ipAddress'] ?? '',
          'model': info['model'] ?? '',
          'brand': info['brand'] ?? '',
          'os_version': info['osVersion'] ?? '',
          'deviceId': info['deviceId'] ?? '',
          'macAddress': info['macAddress'] ?? '',
          'ipAddress': info['ipAddress'] ?? '',
          'osVersion': info['osVersion'] ?? '',
          'serial': info['deviceId'] ?? '',
          'ip': info['ipAddress'] ?? '',
        };
        return {
          'status': true,
          'success': true,
          'data': deviceMap,
          'device': deviceMap,
          ...deviceMap,
        };

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
        final Map? nativeMap = await _tvChannel.invokeMethod<Map>('getHdmiModels');
        if (nativeMap == null) return [];
        final list = [];
        nativeMap.forEach((key, val) {
          list.add({
            'name': key.toString(),
            'label': key.toString(),
            'id': val.toString(),
            'value': val.toString(),
            'model': val.toString(),
          });
        });
        return list;

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
