import 'package:flutter/services.dart';

class AccessibilityService {
  static const MethodChannel _channel =
      MethodChannel('com.digiemperor.hotel/accessibility');

  static Future<bool> isAccessibilityEnabled() async {
    try {
      final bool result = await _channel.invokeMethod('isAccessibilityEnabled');
      return result;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openAccessibilitySettings() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('openAccessibilitySettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestDefaultLauncher() async {
    try {
      final bool result = await _channel.invokeMethod('requestDefaultLauncher');
      return result;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isDefaultLauncher() async {
    try {
      final bool result = await _channel.invokeMethod('isDefaultLauncher');
      return result;
    } catch (_) {
      return false;
    }
  }
}
