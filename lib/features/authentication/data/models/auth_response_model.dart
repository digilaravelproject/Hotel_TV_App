// lib/features/auth/data/models/auth_response_model.dart

import 'user_model.dart';

class AuthResponseModel {
  final bool success;
  final String? message;
  final String? otp;
  final String? token;
  final UserModel? user;

  AuthResponseModel({
    required this.success,
    this.message,
    this.otp,
    this.token,
    this.user,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      success: json['success'] ?? false,
      message: json['message']?.toString(), // ✅ Safe conversion
      otp: json['otp']?.toString(),
      token: json['token']?.toString(),
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      if (message != null) 'message': message,
      if (otp != null) 'otp': otp,
      if (token != null) 'token': token,
      if (user != null) 'user': user?.toJson(),
    };
  }
}