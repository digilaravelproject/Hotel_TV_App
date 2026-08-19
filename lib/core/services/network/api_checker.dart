import 'package:dio/dio.dart';
import '../../constants/app_constants.dart';
import '../../utils/custom_snackbar.dart';
import '../../utils/logger.dart';
import '../storage/shared_prefs.dart';
import '../storage/token_manger.dart';
import 'error_handler.dart';

class ApiChecker {
  static Response checkResponse(Response response) {
    switch (response.statusCode) {
      case 200:
      case 201:
        return response;
      case 401:
        _showErrorMessage(response, 'Unauthorized access. Please login again.');
        _logout();
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'Unauthorized',
        );
      case 403:
        _showErrorMessage(response, 'Access forbidden');
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'Forbidden',
        );
      case 404:
        _showErrorMessage(response, 'Resource not found');
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'Not Found',
        );
      case 408:
        _showErrorMessage(response, 'Request timeout. Please try again.');
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'Request Timeout',
        );
      case 422:
        _showValidationErrors(response);
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'Validation Error',
        );
      case 429:
        _showErrorMessage(response, 'Too many requests. Please wait and try again.');
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'Too Many Requests',
        );
      case 500:
        _showErrorMessage(response, 'Server error. Please try again later.');
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'Server Error',
        );
      case 502:
        _showErrorMessage(response, 'Bad gateway. Server is temporarily unavailable.');
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'Bad Gateway',
        );
      case 503:
        _showErrorMessage(response, 'Service temporarily unavailable. Please try again.');
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'Service Unavailable',
        );
      default:
        _showErrorMessage(response, 'Something went wrong');
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: 'Something went wrong',
        );
    }
  }

  static Response handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          // Silent fallback for connection timeout on TV - DO NOT show red snackbar popup
          Logger.w('[ApiChecker] Connection timeout occurred (Silent fallback)');
          break;
        case DioExceptionType.sendTimeout:
          // Silent fallback for send timeout on TV - DO NOT show red snackbar popup
          Logger.w('[ApiChecker] Send timeout occurred (Silent fallback)');
          break;
        case DioExceptionType.receiveTimeout:
          // Silent fallback for receive timeout on TV - DO NOT show red snackbar popup
          Logger.w('[ApiChecker] Receive timeout occurred (Silent fallback)');
          break;
        case DioExceptionType.badCertificate:
          CustomSnackbar.showError(
            message: 'Security certificate error. Please contact support.',
          );
          break;
        case DioExceptionType.badResponse:
          if (error.response?.data != null) {
            final responseData = error.response!.data;
            if (responseData is Map) {
              try {
                ErrorResponse errorResponse = ErrorResponse.fromJson(responseData);
                if (errorResponse.errors != null && errorResponse.errors!.isNotEmpty) {
                  CustomSnackbar.showError(
                    message: errorResponse.errors!.first.message ?? 'Unknown error',
                  );
                } else if (responseData['msg'] != null) {
                  CustomSnackbar.showError(
                    message: responseData['msg'].toString(),
                  );
                } else if (responseData['message'] != null) {
                  CustomSnackbar.showError(
                    message: responseData['message'].toString(),
                  );
                } else {
                  CustomSnackbar.showError(message: 'Something went wrong');
                }
              } catch (e) {
                if (responseData['msg'] != null) {
                  CustomSnackbar.showError(
                    message: responseData['msg'].toString(),
                  );
                } else if (responseData['message'] != null) {
                  CustomSnackbar.showError(
                    message: responseData['message'].toString(),
                  );
                } else {
                  CustomSnackbar.showError(message: 'Something went wrong');
                }
              }
            } else {
              CustomSnackbar.showError(message: responseData.toString());
            }
          } else {
            CustomSnackbar.showError(message: 'Server error. Please try again.');
          }
          break;
        case DioExceptionType.cancel:
          CustomSnackbar.showError(message: 'Request cancelled');
          break;
        case DioExceptionType.connectionError:
          // Silent fallback for connection errors
          break;
        case DioExceptionType.unknown:
          if (error.error.toString().contains('SocketException') ||
              error.error.toString().contains('Failed host lookup')) {
            // Silent fallback for offline/socket errors
          } else if (error.error.toString().contains('HttpException')) {
            // Silent fallback for HttpException
          } else {
            CustomSnackbar.showError(message: 'Something went wrong. Please try again.');
          }
          break;
        default:
          CustomSnackbar.showError(message: 'Something went wrong. Please try again.');
          break;
      }

      Logger.e('DioError Type: ${error.type}');
      Logger.e('DioError Message: ${error.message}');
      Logger.e('DioError: ${error.error}');

      return Response(
        requestOptions: error.requestOptions,
        statusCode: error.response?.statusCode ?? 500,
        data: error.response?.data ?? {
          'res': 'error',
          'msg': _getErrorMessage(error),
        },
      );
    } else {
      Logger.e('Error: $error');
      CustomSnackbar.showError(message: 'Unexpected error occurred. Please try again.');

      return Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 500,
        data: {'res': 'error', 'msg': 'Unexpected error occurred'},
      );
    }
  }

  static String _getErrorMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout';
      case DioExceptionType.sendTimeout:
        return 'Request timeout';
      case DioExceptionType.receiveTimeout:
        return 'Response timeout';
      case DioExceptionType.connectionError:
        return 'No internet connection';
      case DioExceptionType.badResponse:
        return error.response?.data['msg']?.toString() ??
            error.response?.data['message']?.toString() ??
            'Server error';
      default:
        return 'Something went wrong';
    }
  }

  static void _showErrorMessage(Response response, [String? defaultMessage]) {
    String message = defaultMessage ?? 'Something went wrong';

    if (response.data != null && response.data is Map) {
      message = response.data['msg']?.toString() ??
          response.data['message']?.toString() ??
          response.data['error']?.toString() ??
          message;
    }

    CustomSnackbar.showError(message: message);
  }

  static void _showValidationErrors(Response response) {
    if (response.data != null) {
      try {
        ErrorResponse errorResponse = ErrorResponse.fromJson(response.data);
        if (errorResponse.errors != null && errorResponse.errors!.isNotEmpty) {
          String errorMsg = errorResponse.errors!
              .map((e) => e.message ?? '')
              .where((msg) => msg.isNotEmpty)
              .join('\n');
          CustomSnackbar.showError(
            message: errorMsg.isNotEmpty ? errorMsg : 'Validation errors occurred',
          );
        } else {
          CustomSnackbar.showError(message: 'Validation Error');
        }
      } catch (e) {
        String message = response.data['msg']?.toString() ??
            response.data['message']?.toString() ??
            'Validation Error';
        CustomSnackbar.showError(message: message);
      }
    } else {
      CustomSnackbar.showError(message: 'Validation Error');
    }
  }

  static void _logout() {
    SharedPrefs.remove('user_data');
    SharedPrefs.setBool('is_logged_in', false);
    TokenManager.clearToken();
    // Navigate to sign-in page and remove all previous routes
  }

  static void showResponseError(Response response) {
    if (response.data != null) {
      try {
        ErrorResponse errorResponse = ErrorResponse.fromJson(response.data);
        if (errorResponse.errors != null && errorResponse.errors!.isNotEmpty) {
          CustomSnackbar.showError(
            message: errorResponse.errors!.first.message ?? 'An error occurred',
          );
          return;
        }
      } catch (e) {}

      CustomSnackbar.showError(
        message: response.data['msg']?.toString() ??
            response.data['message']?.toString() ??
            response.data['error']?.toString() ??
            'Something went wrong',
      );
    } else {
      CustomSnackbar.showError(message: 'Something went wrong');
    }
  }

  @Deprecated('Use showResponseError instead')
  static void checkApi(Response response, {bool showToaster = false}) {
    if (showToaster && response.statusCode != 200 && response.statusCode != 201) {
      showResponseError(response);
    }
  }
}