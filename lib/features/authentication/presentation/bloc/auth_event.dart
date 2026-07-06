// lib/features/auth/bloc/auth_event.dart

abstract class AuthEvent {}

/// Send OTP to phone number
class SendOtpEvent extends AuthEvent {
  final String phoneNumber;

  SendOtpEvent({required this.phoneNumber});
}

/// Verify OTP
class VerifyOtpEvent extends AuthEvent {
  final String phoneNumber;
  final String otp;

  VerifyOtpEvent({
    required this.phoneNumber,
    required this.otp,
  });
}

/// Complete profile setup (Update Profile)
class CompleteProfileEvent extends AuthEvent {
  final String name;
  final String? avatar;
  final String? about;

  CompleteProfileEvent({
    required this.name,
    this.avatar,
    this.about,
  });
}

/// Check if user is already logged in
class CheckAuthStatusEvent extends AuthEvent {}

/// Get current user from API
class GetCurrentUserEvent extends AuthEvent {}

/// Logout user
class LogoutEvent extends AuthEvent {}

/// Resend OTP
class ResendOtpEvent extends AuthEvent {
  final String phoneNumber;

  ResendOtpEvent({required this.phoneNumber});
}