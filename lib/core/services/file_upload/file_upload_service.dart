// lib/core/services/file_upload/file_upload_service.dart

import 'dart:io';
import '../../constants/api_constents.dart';
import '../network/api_client.dart';
import '../network/api_response.dart';
import '../network/multipart.dart';

class UploadedFileModel {
  final String url;
  final String type;
  final String fileName;
  final int fileSize;

  UploadedFileModel({
    required this.url,
    required this.type,
    required this.fileName,
    required this.fileSize,
  });

  factory UploadedFileModel.fromJson(Map<String, dynamic> json) {
    return UploadedFileModel(
      url: json['url'] ?? '',
      type: json['type'] ?? '',
      fileName: json['fileName'] ?? '',
      fileSize: json['fileSize'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'type': type,
      'fileName': fileName,
      'fileSize': fileSize,
    };
  }
}

class FileUploadService {
  final ApiClient _apiClient;

  FileUploadService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Upload single file
  /// [file] - File to upload
  /// [type] - Upload type: 'profile', 'chat', 'document', etc.
  /// [onProgress] - Progress callback (0.0 to 1.0)
  Future<ApiResponse<List<UploadedFileModel>>> uploadFile({
    required File file,
    required String type,
    Function(double)? onProgress,
  }) async {
    try {
      print('📤 Uploading file: ${file.path}');
      print('📤 Upload type: $type');

      // Prepare multipart data
      final multipartBody = [
        MultipartBody(key: 'files', file: file),
      ];

      final body = {
        'type': type,
      };

      // Upload file
      final response = await _apiClient.postMultipartData(
        '/api/upload',
        body,
        multipartBody,
        [],
        onSendProgress: (int sent, int total) {
          if (onProgress != null) {
            final progress = sent / total;
            print('📊 Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
            onProgress(progress);
          }
        },
      );

      print('📥 Upload response status: ${response.statusCode}');
      print('📥 Upload response data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;

        if (data['success'] == true && data['files'] != null) {
          final files = (data['files'] as List)
              .map((file) => UploadedFileModel.fromJson(file))
              .toList();

          print('✅ File uploaded successfully: ${files.first.url}');

          return ApiResponse.success(
            files,
            message: 'File uploaded successfully',
            code: response.statusCode,
          );
        } else {
          return ApiResponse.error(
            data['message'] ?? 'Failed to upload file',
            code: response.statusCode,
            error: data,
          );
        }
      } else {
        return ApiResponse.error(
          response.data['message'] ?? 'Failed to upload file',
          code: response.statusCode,
          error: response.data,
        );
      }
    } catch (e, stackTrace) {
      print('❌ File Upload Error: $e');
      print('Stack trace: $stackTrace');
      return ApiResponse.error(
        'Failed to upload file: ${e.toString()}',
        error: e,
      );
    }
  }

  /// Upload multiple files
  /// [files] - List of files to upload
  /// [type] - Upload type: 'profile', 'chat', 'document', etc.
  /// [onProgress] - Progress callback (0.0 to 1.0)
  Future<ApiResponse<List<UploadedFileModel>>> uploadMultipleFiles({
    required List<File> files,
    required String type,
    Function(double)? onProgress,
  }) async {
    try {
      print('📤 Uploading ${files.length} files');
      print('📤 Upload type: $type');

      // Prepare multipart data for multiple files
      final multipartBody = files
          .map((file) => MultipartBody(key: 'files', file: file))
          .toList();

      final body = {
        'type': type,
      };

      // Upload files
      final response = await _apiClient.postMultipartData(
        '/api/upload',
        body,
        multipartBody,
        [],
        onSendProgress: (int sent, int total) {
          if (onProgress != null) {
            final progress = sent / total;
            print('📊 Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
            onProgress(progress);
          }
        },
      );

      print('📥 Upload response status: ${response.statusCode}');
      print('📥 Upload response data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;

        if (data['success'] == true && data['files'] != null) {
          final uploadedFiles = (data['files'] as List)
              .map((file) => UploadedFileModel.fromJson(file))
              .toList();

          print('✅ ${uploadedFiles.length} files uploaded successfully');

          return ApiResponse.success(
            uploadedFiles,
            message: 'Files uploaded successfully',
            code: response.statusCode,
          );
        } else {
          return ApiResponse.error(
            data['message'] ?? 'Failed to upload files',
            code: response.statusCode,
            error: data,
          );
        }
      } else {
        return ApiResponse.error(
          response.data['message'] ?? 'Failed to upload files',
          code: response.statusCode,
          error: response.data,
        );
      }
    } catch (e, stackTrace) {
      print('❌ Multiple Files Upload Error: $e');
      print('Stack trace: $stackTrace');
      return ApiResponse.error(
        'Failed to upload files: ${e.toString()}',
        error: e,
      );
    }
  }

  /// Upload profile image (shortcut method)
  Future<ApiResponse<List<UploadedFileModel>>> uploadProfileImage({
    required File file,
    Function(double)? onProgress,
  }) async {
    return uploadFile(
      file: file,
      type: 'profile',
      onProgress: onProgress,
    );
  }

  /// Upload chat media (shortcut method)
  Future<ApiResponse<List<UploadedFileModel>>> uploadChatMedia({
    required List<File> files,
    Function(double)? onProgress,
  }) async {
    return uploadMultipleFiles(
      files: files,
      type: 'chat',
      onProgress: onProgress,
    );
  }

  /// Upload document (shortcut method)
  Future<ApiResponse<List<UploadedFileModel>>> uploadDocument({
    required File file,
    Function(double)? onProgress,
  }) async {
    return uploadFile(
      file: file,
      type: 'chat',
      onProgress: onProgress,
    );
  }
}
