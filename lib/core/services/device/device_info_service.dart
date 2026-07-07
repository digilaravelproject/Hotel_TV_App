import 'package:connectivity_plus/connectivity_plus.dart';

class DeviceInfoService {
  static Map<String, dynamic>? _cachedDeviceInfo;

  /// Fetches and caches the complete device details
  static Future<Map<String, dynamic>> getFullDeviceInfo() async {
    if (_cachedDeviceInfo != null) {
      return _cachedDeviceInfo!;
    }

    _cachedDeviceInfo = {
      'deviceId': '6231A4D7B13402C5',
      'macAddress': 'AA:BB:CC:DD:EE:FF',
      'ipAddress': '192.168.1.100',
      'model': 'BRAVIA-X90L',
      'brand': 'Sony',
      'osVersion': 'Android TV 12',
    };

    return _cachedDeviceInfo!;
  }

  /// Helper to get just the unique device ID
  static Future<String> getDeviceId() async {
    final info = await getFullDeviceInfo();
    return info['deviceId'] ?? '';
  }

  /// Fetches the real network connectivity type (WiFi, Ethernet, Mobile, etc.)
  static Future<String> getNetworkType() async {
    try {
      final dynamic connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult is List) {
        if (connectivityResult.isEmpty || connectivityResult.contains(ConnectivityResult.none)) {
          return 'Disconnected';
        }
        if (connectivityResult.contains(ConnectivityResult.ethernet)) {
          return 'Ethernet';
        }
        if (connectivityResult.contains(ConnectivityResult.wifi)) {
          return 'WiFi';
        }
        if (connectivityResult.contains(ConnectivityResult.mobile)) {
          return 'Mobile';
        }
        return 'Connected';
      } else {
        final ConnectivityResult result = connectivityResult as ConnectivityResult;
        if (result == ConnectivityResult.none) {
          return 'Disconnected';
        }
        if (result == ConnectivityResult.ethernet) {
          return 'Ethernet';
        }
        if (result == ConnectivityResult.wifi) {
          return 'WiFi';
        }
        if (result == ConnectivityResult.mobile) {
          return 'Mobile';
        }
        return 'Connected';
      }
    } catch (_) {
      return 'Connected';
    }
  }
}
