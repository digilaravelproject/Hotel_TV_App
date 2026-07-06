// lib/features/auth/bloc/auth_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repository/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<SendOtpEvent>(_onSendOtp);
    on<ResendOtpEvent>(_onResendOtp);
    on<VerifyOtpEvent>(_onVerifyOtp);
    on<CompleteProfileEvent>(_onCompleteProfile);
    on<GetCurrentUserEvent>(_onGetCurrentUser);
    on<LogoutEvent>(_onLogout);
  }

  /// Check if user is already authenticated
  /// Check if user is already authenticated
  Future<void> _onCheckAuthStatus(
      CheckAuthStatusEvent event,
      Emitter<AuthState> emit,
      ) async {
    try {
      print('🔍 Checking auth status...');
      emit(AuthLoading());

      final isLoggedIn = await authRepository.isLoggedIn();
      print('🔍 Is logged in: $isLoggedIn');

      if (isLoggedIn) {
        final user = await authRepository.getCachedUser();
        print('🔍 Cached user: ${user?.toJson()}');

        if (user != null) {
          print('✅ User authenticated');
          emit(Authenticated(user: user));
        } else {
          print('❌ No cached user found, setting as unauthenticated');
          emit(Unauthenticated());
        }
      } else {
        print('❌ Not logged in');
        emit(Unauthenticated());
      }
    } catch (e, stackTrace) {
      print('❌ Error checking auth status: $e');
      print('Stack trace: $stackTrace');
      emit(Unauthenticated());
    }
  }

  /// Send OTP to phone number
  Future<void> _onSendOtp(
      SendOtpEvent event,
      Emitter<AuthState> emit,
      ) async {
    try {
      emit(OtpSending());

      final response = await authRepository.sendOtp(event.phoneNumber);

      if (response.success) {
        emit(OtpSentSuccess(
          message: response.message,
          phoneNumber: event.phoneNumber,
          otp: response.data!.otp, // For development/testing
        ));
      } else {
        emit(OtpSendError(message: response.message));
      }
    } catch (e) {
      emit(OtpSendError(message: 'Failed to send OTP: ${e.toString()}'));
    }
  }

  /// Resend OTP
  Future<void> _onResendOtp(
      ResendOtpEvent event,
      Emitter<AuthState> emit,
      ) async {
    try {
      emit(OtpSending());

      final response = await authRepository.sendOtp(event.phoneNumber);

      if (response.success) {
        emit(OtpSentSuccess(
          message: 'OTP resent successfully',
          phoneNumber: event.phoneNumber,
          otp: response.data!.otp,
        ));
      } else {
        emit(OtpSendError(message: response.message));
      }
    } catch (e) {
      emit(OtpSendError(message: 'Failed to resend OTP: ${e.toString()}'));
    }
  }

  /// Verify OTP
  Future<void> _onVerifyOtp(
      VerifyOtpEvent event,
      Emitter<AuthState> emit,
      ) async {
    try {
      emit(OtpVerifying());

      final response = await authRepository.verifyOtp(
        event.phoneNumber,
        event.otp,
      );

      if (response.success) {
        emit(OtpVerifiedSuccess(
          isNewUser: response.data!.user?.isNewUser ?? false,
          user: response.data!.user,
        ));
      } else {
        emit(OtpVerifyError(message: response.message));
      }
    } catch (e) {
      emit(OtpVerifyError(message: 'Failed to verify OTP: ${e.toString()}'));
    }
  }

  /// Complete user profile (Update Profile)
  Future<void> _onCompleteProfile(
      CompleteProfileEvent event,
      Emitter<AuthState> emit,
      ) async {
    try {
      emit(ProfileUpdating());

      final profileData = {
        'name': event.name,
        if (event.about != null && event.about!.isNotEmpty)
          'about': event.about,
        if (event.avatar != null && event.avatar!.isNotEmpty)
          'avatar': event.avatar,
      };

      print('📤 Sending profile data: $profileData');

      final response = await authRepository.completeProfile(profileData);

      print('📥 Profile update response: ${response.data?.toJson()}');

      if (response.success && response.data?.user != null) {
        print('✅ Profile updated successfully');
        emit(Authenticated(user: response.data!.user!));
      } else {
        print('❌ Profile update failed: ${response.message ?? "Unknown error"}');
        emit(ProfileSetupError(
          message: response.message ?? 'Failed to update profile',
        ));
      }
    } catch (e, stackTrace) {
      print('❌ Error completing profile: $e');
      print('Stack trace: $stackTrace');
      emit(ProfileSetupError(
        message: 'Failed to complete profile: ${e.toString()}',
      ));
    }
  }

  /// Get current user from API
  Future<void> _onGetCurrentUser(
      GetCurrentUserEvent event,
      Emitter<AuthState> emit,
      ) async {
    try {
      emit(AuthLoading());

      final response = await authRepository.getCurrentUser();

      if (response.success && response.data?.user != null) {
        emit(Authenticated(user: response.data!.user!));
      } else {
        emit(AuthError(message: response.message));
      }
    } catch (e) {
      emit(AuthError(message: 'Failed to get user: ${e.toString()}'));
    }
  }

  /// Logout user
  Future<void> _onLogout(
      LogoutEvent event,
      Emitter<AuthState> emit,
      ) async {
    try {
      emit(AuthLoading());

      await authRepository.logout();

      emit(Unauthenticated());
    } catch (e) {
      // Even on error, clear local state
      emit(Unauthenticated());
    }
  }
}