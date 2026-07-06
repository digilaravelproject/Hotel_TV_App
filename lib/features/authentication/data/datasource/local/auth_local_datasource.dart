// lib/features/auth/data/datasource/local/auth_local_datasource.dart

import 'dart:convert';
import '../../../../../core/services/storage/shared_prefs.dart';
import '../../../../../core/services/storage/token_manger.dart';
import '../../models/user_model.dart';
import '../../../../../core/constants/app_constants.dart';

abstract class AuthLocalDataSource {
  Future<void> saveToken(String token);
  Future<String?> getToken();
  Future<void> saveUser(UserModel user);
  Future<UserModel?> getUser();
  Future<void> clearAuthData();
  Future<bool> isLoggedIn();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl();

  @override
  Future<void> saveToken(String token) async {
    print('💾 Saving token...');
    await TokenManager.saveToken(token);
    await SharedPrefs.setBool(AppConstants.isLoggedInPref, true);
    print('✅ Token saved');
  }

  @override
  Future<String?> getToken() async {
    print('🔑 Getting token...');
    final token = await TokenManager.getToken();
    print('🔑 Token: ${token.isEmpty ? "empty" : "exists"}');
    return token.isEmpty ? null : token;
  }

  @override
  Future<void> saveUser(UserModel user) async {
    print('💾 Saving user: ${user.toJson()}');
    final userJson = json.encode(user.toJson());
    final result = await SharedPrefs.setString(AppConstants.userDataPref, userJson);
    print('✅ User saved: $result');
  }

  @override
  Future<UserModel?> getUser() async {
    print('👤 Getting user...');
    try {
      final userJson = SharedPrefs.getString(AppConstants.userDataPref);
      print('👤 User JSON: $userJson');

      if (userJson != null && userJson.isNotEmpty) {
        final user = UserModel.fromJson(json.decode(userJson));
        print('✅ User found: ${user.name}');
        return user;
      }
      print('❌ No user data found');
      return null;
    } catch (e, stackTrace) {
      print('❌ Error getting user: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  @override
  Future<void> clearAuthData() async {
    print('🗑️ Clearing auth data...');
    await TokenManager.clearToken();
    await SharedPrefs.remove(AppConstants.userDataPref);
    await SharedPrefs.remove(AppConstants.isLoggedInPref);
    print('✅ Auth data cleared');
  }

  @override
  Future<bool> isLoggedIn() async {
    print('🔍 Checking if logged in...');
    try {
      final token = await getToken();
      final isLoggedIn = token != null && token.isNotEmpty;
      print('🔍 Is logged in: $isLoggedIn');
      return isLoggedIn;
    } catch (e) {
      print('❌ Error checking login status: $e');
      return false;
    }
  }
}