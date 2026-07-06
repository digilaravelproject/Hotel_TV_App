import 'package:shared_preferences/shared_preferences.dart';

/// A simplified wrapper for SharedPreferences
class SharedPrefs {
  static SharedPreferences? _prefs;

  /// Initialize SharedPreferences instance
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Set a String value
  static Future<bool> setString(String key, String value) async {
    return await _prefs?.setString(key, value) ?? false;
  }

  /// Get a String value
  static String? getString(String key) {
    return _prefs?.getString(key);
  }

  /// Set an int value
  static Future<bool> setInt(String key, int value) async {
    return await _prefs?.setInt(key, value) ?? false;
  }

  /// Get an int value
  static int? getInt(String key) {
    return _prefs?.getInt(key);
  }

  /// Set a bool value
  static Future<bool> setBool(String key, bool value) async {
    return await _prefs?.setBool(key, value) ?? false;
  }

  /// Get a bool value
  static bool? getBool(String key) {
    return _prefs?.getBool(key);
  }

  /// Set a double value
  static Future<bool> setDouble(String key, double value) async {
    return await _prefs?.setDouble(key, value) ?? false;
  }

  /// Get a double value
  static double? getDouble(String key) {
    return _prefs?.getDouble(key);
  }

  /// Set a List<String> value
  static Future<bool> setStringList(String key, List<String> value) async {
    return await _prefs?.setStringList(key, value) ?? false;
  }

  /// Get a List<String> value
  static List<String>? getStringList(String key) {
    return _prefs?.getStringList(key);
  }

  /// Check if key exists
  static bool containsKey(String key) {
    return _prefs?.containsKey(key) ?? false;
  }

  /// Remove a key-value pair
  static Future<bool> remove(String key) async {
    return await _prefs?.remove(key) ?? false;
  }

  /// Clear all preferences
  static Future<bool> clear() async {
    return await _prefs?.clear() ?? false;
  }

}
