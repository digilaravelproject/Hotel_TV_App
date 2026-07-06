import '../models/auth_response_model.dart';
import '../models/user_model.dart';
import '../../../../core/services/network/api_response.dart';

abstract class AuthRepository {
  Future<ApiResponse<AuthResponseModel>> sendOtp(String phoneNumber);
  Future<ApiResponse<AuthResponseModel>> verifyOtp(
      String phoneNumber, String otp);
  Future<ApiResponse<AuthResponseModel>> completeProfile(
      Map<String, dynamic> profileData);
  Future<ApiResponse<AuthResponseModel>> getCurrentUser();
  Future<ApiResponse<void>> logout();

  Future<UserModel?> getCachedUser();
  Future<bool> isLoggedIn();
}
