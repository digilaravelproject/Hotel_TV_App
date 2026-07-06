import '../datasource/local/auth_local_datasource.dart';
import '../datasource/remote/auth_remote_datasource.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/services/network/api_response.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<ApiResponse<AuthResponseModel>> sendOtp(String phoneNumber) async {
    final response = await remoteDataSource.sendOtp(phoneNumber);
    return response;
  }

  @override
  Future<ApiResponse<AuthResponseModel>> verifyOtp(
      String phoneNumber, String otp) async {
    final response = await remoteDataSource.verifyOtp(phoneNumber, otp);

    // ✅ Only save token on successful OTP verification
    if (response.code == 200 && response.data != null) {
      // Save token (always save when verification is successful)
      if (response.data!.token != null && response.data!.token!.isNotEmpty) {
        await localDataSource.saveToken(response.data!.token!);
      }

      // ✅ Only save user data if it's NOT a new user
      if (response.data!.user != null &&
          response.data!.user!.isNewUser == false) {
        await localDataSource.saveUser(response.data!.user!);
      }
      // ✅ If isNewUser == true, don't save user data yet
    }

    return response;
  }

  @override
  Future<ApiResponse<AuthResponseModel>> completeProfile(
      Map<String, dynamic> profileData) async {
    final response = await remoteDataSource.completeProfile(profileData);

    // ✅ Save user data after profile setup completion
    if (response.code == 200 && response.data?.user != null) {
      await localDataSource.saveUser(response.data!.user!);
    }

    return response;
  }

  @override
  Future<ApiResponse<AuthResponseModel>> getCurrentUser() async {
    final response = await remoteDataSource.getCurrentUser();

    // ✅ Save/update user data from getCurrentUser
    if (response.code == 200 && response.data?.user != null) {
      await localDataSource.saveUser(response.data!.user!);
    }

    return response;
  }

  @override
  Future<ApiResponse<void>> logout() async {
    final response = await remoteDataSource.logout();

    // ✅ Always clear local data on logout (even if API fails)
    await localDataSource.clearAuthData();

    return response;
  }

  @override
  Future<UserModel?> getCachedUser() async {
    return await localDataSource.getUser();
  }

  @override
  Future<bool> isLoggedIn() async {
    return await localDataSource.isLoggedIn();
  }
}