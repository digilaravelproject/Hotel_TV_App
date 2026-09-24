import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'shared_prefs.dart';
import '../../constants/app_constants.dart';

class TokenManager {
  static const _secureStorage = FlutterSecureStorage();

  static Future<String> getToken() async {
    if (kIsWeb) {
      return SharedPrefs.getString('auth_token') ?? '';
    }
    try {
      return await _secureStorage.read(key: 'token') ?? '';
    } catch (_) {
      return SharedPrefs.getString('auth_token') ?? '';
    }
  }

  static Future<void> saveToken(String token) async {
    if (kIsWeb) {
      await SharedPrefs.setString('auth_token', token);
      return;
    }
    try {
      await _secureStorage.write(key: 'token', value: token);
    } catch (_) {
      await SharedPrefs.setString('auth_token', token);
    }
  }

  static Future<void> clearToken() async {
    if (kIsWeb) {
      await SharedPrefs.remove('auth_token');
      return;
    }
    try {
      await _secureStorage.delete(key: 'token');
    } catch (_) {
      await SharedPrefs.remove('auth_token');
    }
  }
}
