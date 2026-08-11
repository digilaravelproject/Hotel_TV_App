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

  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }
}
