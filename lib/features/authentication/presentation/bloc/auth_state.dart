// lib/features/auth/bloc/auth_state.dart

import '../data/models/user_model.dart';

abstract class AuthState {}

/// Initial state
class AuthInitial extends AuthState {}

/// Loading states
class AuthLoading extends AuthState {}

class OtpSending extends AuthState {}

class OtpVerifying extends AuthState {}

class ProfileUpdating extends AuthState {}

/// Success states
class OtpSentSuccess extends AuthState {
  final String message;
  final String phoneNumber;
  final String? otp; // For development/testing

  OtpSentSuccess({
    required this.message,
    required this.phoneNumber,
    this.otp,
  });
}

class OtpVerifiedSuccess extends AuthState {
  final bool isNewUser;
  final UserModel? user;

  OtpVerifiedSuccess({
    required this.isNewUser,
    this.user,
  });
}

class Authenticated extends AuthState {
  final UserModel user;

  Authenticated({required this.user});
}

class Unauthenticated extends AuthState {}

/// Error states
class AuthError extends AuthState {
  final String message;

  AuthError({required this.message});
}

class OtpSendError extends AuthState {
  final String message;

  OtpSendError({required this.message});
}

class OtpVerifyError extends AuthState {
  final String message;

  OtpVerifyError({required this.message});
}

class ProfileSetupError extends AuthState {
  final String message;

  ProfileSetupError({required this.message});
}

/// Logout success
class LogoutSuccess extends AuthState {}