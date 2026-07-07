import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart';
import '../../constants/app_constants.dart';
import '../../utils/logger.dart';
import '../storage/token_manger.dart';
import 'api_checker.dart';
import 'multipart.dart';
import 'network_info.dart';

class ApiClient {
  final Dio _dio;
  final int _maxRetries = 3;
  final Duration _retryDelay = const Duration(seconds: 2);

  ApiClient() : _dio = Dio() {
    _initializeDio();
  }

  void _initializeDio() {
    _dio.options = BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(milliseconds: 30000),
      receiveTimeout: const Duration(milliseconds: 30000),
      contentType: 'application/json',
      validateStatus: (status) => status! < 500,
    );

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        String? token = await TokenManager.getToken();

        if (token != null && token.isNotEmpty) {
          options.headers["Authorization"] = "Bearer $token";
        }
        options.headers["Content-Type"] = "application/json";
        options.headers["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

        // --- Logging Request ---
        Logger.d('┌─────────────── REQUEST ───────────────');
        Logger.d('│ Method  : ${options.method}');
        Logger.d('│ URL     : ${options.baseUrl}${options.path}');
        Logger.d('│ Headers : ${options.headers}');
        if (options.queryParameters.isNotEmpty) {
          Logger.d('│ Query   : ${options.queryParameters}');
        }
        if (options.data != null) Logger.d('│ Body    : ${options.data}');
        Logger.d('└───────────────────────────────────────');

        return handler.next(options);
      },
      onResponse: (response, handler) {
        // --- Logging Response ---
        Logger.d('┌─────────────── RESPONSE ──────────────');
        Logger.d('│ Method      : ${response.requestOptions.method}');
        Logger.d('│ URL         : ${response.requestOptions.baseUrl}${response.requestOptions.path}');
        Logger.d('│ Status Code : ${response.statusCode}');
        Logger.d('│ Response    : ${response.data}');
        Logger.d('└───────────────────────────────────────');

        return handler.next(response);
      },
      onError: (DioException e, handler) {
        // --- Logging Error ---
        Logger.e('┌─────────────── ERROR ─────────────────');
        Logger.e('│ Method   : ${e.requestOptions.method}');
        Logger.e('│ URL      : ${e.requestOptions.baseUrl}${e.requestOptions.path}');
        Logger.e('│ Message  : ${e.message}');
        Logger.e('│ Error    : ${e.error}');
        if (e.response != null) Logger.e('│ Response : ${e.response?.data}');
        Logger.e('└───────────────────────────────────────');

        return handler.next(e);
      },
    ));
  }

  /// Retry logic with exponential backoff and logging
  Future<Response> _retryRequest(
      Future<Response> Function() request, {
        required String requestType,
        required String path,
      }) async {
    int attempt = 0;

    while (attempt < _maxRetries) {
      try {
        // Make the request
        Response response = await request();
        return response;
      } catch (e) {
        attempt++;

        Logger.w('┌─────────────── RETRY ────────────────');
        Logger.w('│ Request Type : $requestType');
        Logger.w('│ URL          : $path');
        Logger.w('│ Attempt      : $attempt/$_maxRetries');
        Logger.w('│ Waiting      : ${_retryDelay.inSeconds * attempt}s before next attempt');
        Logger.w('└───────────────────────────────────────');

        if (e is DioException) {
          bool shouldRetry = _shouldRetryError(e);
          if (shouldRetry && attempt < _maxRetries) {
            await Future.delayed(_retryDelay * attempt);
            continue;
          }
        }

        Logger.e('❌ $requestType request failed after $attempt attempts: $e');
        return ApiChecker.handleError(e);
      }
    }

    // Max retries exceeded
    return ApiChecker.handleError(
      DioException(
        requestOptions: RequestOptions(path: path),
        error: 'Max retries exceeded',
      ),
    );
  }

  bool _shouldRetryError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        return statusCode != null &&
            (statusCode >= 500 || statusCode == 408 || statusCode == 429);
      case DioExceptionType.unknown:
        return error.error is SocketException || error.error is HttpException;
      default:
        return false;
    }
  }

  // ------------------- GET -------------------
  Future<Response> get(
      String path, {
        Map<String, dynamic>? queryParameters,
        Options? options,
        CancelToken? cancelToken,
        ProgressCallback? onReceiveProgress,
        bool handleError = false,
        bool showToaster = false,
        bool enableRetry = true,
      }) async {
    Future<Response> makeRequest() async {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );

      if (handleError) return ApiChecker.checkResponse(response);
      if (showToaster && response.statusCode != 200 && response.statusCode != 201) {
        ApiChecker.showResponseError(response);
      }

      return response;
    }

    return enableRetry
        ? _retryRequest(makeRequest, requestType: 'GET', path: path)
        : makeRequest().catchError(ApiChecker.handleError);
  }

  // ------------------- POST -------------------
  Future<Response> post(
      String path, {
        dynamic data,
        Map<String, dynamic>? queryParameters,
        Options? options,
        CancelToken? cancelToken,
        ProgressCallback? onSendProgress,
        ProgressCallback? onReceiveProgress,
        bool handleError = false,
        bool showToaster = false,
        bool enableRetry = true,
      }) async {
    Future<Response> makeRequest() async {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );

      if (handleError) return ApiChecker.checkResponse(response);
      if (showToaster && response.statusCode != 200 && response.statusCode != 201) {
        ApiChecker.showResponseError(response);
      }

      return response;
    }

    return enableRetry
        ? _retryRequest(makeRequest, requestType: 'POST', path: path)
        : makeRequest().catchError(ApiChecker.handleError);
  }

  // ------------------- PUT -------------------
  Future<Response> put(
      String path, {
        dynamic data,
        Map<String, dynamic>? queryParameters,
        Options? options,
        CancelToken? cancelToken,
        ProgressCallback? onSendProgress,
        ProgressCallback? onReceiveProgress,
        bool handleError = false,
        bool showToaster = false,
        bool enableRetry = true,
      }) async {
    Future<Response> makeRequest() async {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );

      if (handleError) return ApiChecker.checkResponse(response);
      if (showToaster && response.statusCode != 200 && response.statusCode != 201) {
        ApiChecker.showResponseError(response);
      }

      return response;
    }

    return enableRetry
        ? _retryRequest(makeRequest, requestType: 'PUT', path: path)
        : makeRequest().catchError(ApiChecker.handleError);
  }

  // ------------------- DELETE -------------------
  Future<Response> delete(
      String path, {
        dynamic data,
        Map<String, dynamic>? queryParameters,
        Options? options,
        CancelToken? cancelToken,
        bool handleError = false,
        bool showToaster = false,
        bool enableRetry = true,
      }) async {
    Future<Response> makeRequest() async {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );

      if (handleError) return ApiChecker.checkResponse(response);
      if (showToaster && response.statusCode != 200 && response.statusCode != 201) {
        ApiChecker.showResponseError(response);
      }

      return response;
    }

    return enableRetry
        ? _retryRequest(makeRequest, requestType: 'DELETE', path: path)
        : makeRequest().catchError(ApiChecker.handleError);
  }

  // ------------------- POST MULTIPART -------------------
  Future<Response> postMultipartData(
      String path,
      Map<String, String> body,
      List<MultipartBody> multipartBody,
      List<MultipartDocument> otherFile, {
        Map<String, dynamic>? queryParameters,
        Options? options,
        CancelToken? cancelToken,
        ProgressCallback? onSendProgress,
        ProgressCallback? onReceiveProgress,
        bool fromChat = false,
        bool handleError = false,
        bool showToaster = false,
        bool enableRetry = true,
      }) async {
    Future<Response> makeRequest() async {
      FormData formData = FormData();

      // Add text fields
      body.forEach((key, value) {
        formData.fields.add(MapEntry(key, value));
      });

      // Add images
      for (MultipartBody multipart in multipartBody) {
        if (multipart.file != null) {
          if (kIsWeb) {
            List<int> bytes = await multipart.file!.readAsBytes();
            formData.files.add(MapEntry(
              multipart.key,
              MultipartFile.fromBytes(
                bytes,
                filename: basename(multipart.file!.path),
                contentType: MediaType('image', 'jpg'),
              ),
            ));
          } else {
            File file = File(multipart.file!.path);
            formData.files.add(MapEntry(
              multipart.key,
              await MultipartFile.fromFile(
                file.path,
                filename: basename(file.path),
              ),
            ));
          }
        }
      }

      // Add documents
      for (MultipartDocument file in otherFile) {
        if (kIsWeb) {
          if (fromChat) {
            PlatformFile platformFile = file.file!.files.first;
            formData.files.add(MapEntry(
              'image[]',
              MultipartFile.fromBytes(
                platformFile.bytes!,
                filename: platformFile.name,
              ),
            ));
          } else {
            var fileBytes = file.file!.files.first.bytes!;
            formData.files.add(MapEntry(
              file.key,
              MultipartFile.fromBytes(
                fileBytes,
                filename: file.file!.files.first.name,
              ),
            ));
          }
        } else {
          File other = File(file.file!.files.single.path!);
          formData.files.add(MapEntry(
            file.key,
            await MultipartFile.fromFile(
              other.path,
              filename: basename(other.path),
            ),
          ));
        }
      }

      final response = await _dio.post(
        path,
        data: formData,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );

      if (handleError) return ApiChecker.checkResponse(response);
      if (showToaster && response.statusCode != 200 && response.statusCode != 201) {
        ApiChecker.showResponseError(response);
      }

      return response;
    }

    return enableRetry
        ? _retryRequest(makeRequest, requestType: 'POST_MULTIPART', path: path)
        : makeRequest().catchError(ApiChecker.handleError);
  }
}