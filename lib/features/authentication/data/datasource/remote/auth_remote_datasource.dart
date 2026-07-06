import 'package:virtual_office/core/services/network/api_response.dart';
import 'package:virtual_office/core/services/network/api_client.dart';

import '../../../../../core/constants/api_constents.dart';
import '../../models/auth_response_model.dart';

abstract class AuthRemoteDataSource {
    Future<ApiResponse<AuthResponseModel>> sendOtp(String phoneNumber);
    Future<ApiResponse<AuthResponseModel>> verifyOtp(
        String phoneNumber, String otp);
    Future<ApiResponse<AuthResponseModel>> completeProfile(
        Map<String, dynamic> profileData);
    Future<ApiResponse<AuthResponseModel>> getCurrentUser();
    Future<ApiResponse<void>> logout();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
    final ApiClient apiClient;

    AuthRemoteDataSourceImpl({required this.apiClient});

    @override
    Future<ApiResponse<AuthResponseModel>> sendOtp(String phoneNumber) async {
        try {
            final response = await apiClient.post(
                '/api/auth/send-otp',
                data: {'phoneNumber': phoneNumber}
            );

            if (response.statusCode == 200) {
                return ApiResponse.success(
                    AuthResponseModel.fromJson(response.data),
                    message: response.data['message'],
                    code: response.statusCode
                );
            }
            else {
                return ApiResponse.error(
                    response.data['message'],
                    code: response.statusCode,
                    error: response.data
                );
            }
        }
        catch (e) {
            return ApiResponse.error(e.toString(), error: e);
        }
    }

    @override
    Future<ApiResponse<AuthResponseModel>> verifyOtp(
        String phoneNumber, String otp) async {
        try {
            final response = await apiClient.post(
                '/api/auth/verify-otp',
                data: {
                    'phoneNumber': phoneNumber,
                    'otp': otp
                }
            );

            if (response.statusCode == 200) {
                return ApiResponse.success(
                    AuthResponseModel.fromJson(response.data),
                    message: response.data['message'],
                    code: response.statusCode
                );
            }
            else {
                return ApiResponse.error(
                    response.data['message'],
                    code: response.statusCode,
                    error: response.data
                );
            }
        }
        catch (e) {
            return ApiResponse.error(e.toString(), error: e);
        }
    }

    @override
    Future<ApiResponse<AuthResponseModel>> completeProfile(
        Map<String, dynamic> profileData) async {
      try {
        final response = await apiClient.put(
            '/api/user/update-profile',
            data: profileData
        );

        if (response.statusCode == 200) {
          // ✅ Add default message if not present
          final responseData = response.data as Map<String, dynamic>;
          if (!responseData.containsKey('message')) {
            responseData['message'] = 'Profile updated successfully';
          }

          return ApiResponse.success(
              AuthResponseModel.fromJson(responseData),
              message: responseData['message'],
              code: response.statusCode
          );
        } else {
          return ApiResponse.error(
              response.data['message'] ?? 'Failed to update profile',
              code: response.statusCode,
              error: response.data
          );
        }
      } catch (e) {
        print('❌ Complete Profile Error: $e');
        return ApiResponse.error(e.toString(), error: e);
      }
    }

    @override
    Future<ApiResponse<AuthResponseModel>> getCurrentUser() async {
        try {
            final response = await apiClient.get('/api/user/profile');

            if (response.statusCode == 200) {
                return ApiResponse.success(
                    AuthResponseModel.fromJson(response.data),
                    message: response.data['message'],
                    code: response.statusCode
                );
            }
            else {
                return ApiResponse.error(
                    response.data['message'],
                    code: response.statusCode,
                    error: response.data
                );
            }
        }
        catch (e) {
            return ApiResponse.error(e.toString(), error: e);
        }
    }

    @override
    Future<ApiResponse<void>> logout() async {
        try {
            final response = await apiClient.post('/api/auth/logout');

            if (response.statusCode == 200) {
                return ApiResponse.success(
                    null,
                    message: response.data['message'],
                    code: response.statusCode
                );
            }
            else {
                return ApiResponse.error(
                    response.data['message'],
                    code: response.statusCode,
                    error: response.data
                );
            }
        }
        catch (e) {
            return ApiResponse.error(e.toString(), error: e);
        }
    }
}
