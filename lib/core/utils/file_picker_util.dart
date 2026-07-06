// lib/core/utils/file_picker_util.dart

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'custom_snackbar.dart';

/// Comprehensive file picker utility for images, videos, documents, and all file types
class FilePickerUtil {
  static final ImagePicker _imagePicker = ImagePicker();

  /// ============================================
  /// IMAGE PICKER
  /// ============================================

  /// Pick single image from gallery
  static Future<File?> pickImageFromGallery({
    int? imageQuality = 85,
    double? maxWidth,
    double? maxHeight,
  }) async {
    try {
      // Check and request permission
      final hasPermission = await _requestGalleryPermission();

      if (!hasPermission) {
        CustomSnackbar.showError(message: 'Gallery permission is required');
        return null;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('❌ Gallery picker error: $e');
      CustomSnackbar.showError(message: 'Failed to pick image: $e');
      return null;
    }
  }

  /// Pick single image from camera
  static Future<File?> pickImageFromCamera({
    int? imageQuality = 85,
    double? maxWidth,
    double? maxHeight,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
    try {
      // Check and request permission
      if (!await _checkCameraPermission()) {
        CustomSnackbar.showError(message: 'Camera permission denied');
        return null;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        preferredCameraDevice: preferredCameraDevice,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      CustomSnackbar.showError(message: 'Failed to capture image: $e');
      return null;
    }
  }

  /// Pick multiple images from gallery
  static Future<List<File>?> pickMultipleImages({
    int? imageQuality = 85,
    double? maxWidth,
    double? maxHeight,
    int? limit,
  }) async {
    try {
      // Check and request permission
      final hasPermission = await _requestGalleryPermission();

      if (!hasPermission) {
        CustomSnackbar.showError(message: 'Gallery permission is required');
        return null;
      }

      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        limit: limit,
      );

      if (images.isNotEmpty) {
        return images.map((xFile) => File(xFile.path)).toList();
      }
      return null;
    } catch (e) {
      CustomSnackbar.showError(message: 'Failed to pick images: $e');
      return null;
    }
  }

  /// ============================================
  /// VIDEO PICKER
  /// ============================================

  /// Pick video from gallery
  static Future<File?> pickVideoFromGallery({
    Duration? maxDuration,
  }) async {
    try {
      // Check and request permission
      final hasPermission = await _requestGalleryPermission();

      if (!hasPermission) {
        CustomSnackbar.showError(message: 'Gallery permission is required');
        return null;
      }

      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: maxDuration,
      );

      if (video != null) {
        return File(video.path);
      }
      return null;
    } catch (e) {
      CustomSnackbar.showError(message: 'Failed to pick video: $e');
      return null;
    }
  }

  /// Record video from camera
  static Future<File?> recordVideoFromCamera({
    Duration? maxDuration,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
    try {
      // Check and request permission
      if (!await _checkCameraPermission()) {
        CustomSnackbar.showError(message: 'Camera permission denied');
        return null;
      }

      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: maxDuration,
        preferredCameraDevice: preferredCameraDevice,
      );

      if (video != null) {
        return File(video.path);
      }
      return null;
    } catch (e) {
      CustomSnackbar.showError(message: 'Failed to record video: $e');
      return null;
    }
  }

  /// ============================================
  /// DOCUMENT / FILE PICKER
  /// ============================================

  /// Pick single file of any type
  static Future<File?> pickFile({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowCompression = true,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        allowCompression: allowCompression,
      );

      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
      return null;
    } catch (e) {
      CustomSnackbar.showError(message: 'Failed to pick file: $e');
      return null;
    }
  }

  /// Pick multiple files
  static Future<List<File>?> pickMultipleFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowCompression = true,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        allowCompression: allowCompression,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        return result.files
            .where((file) => file.path != null)
            .map((file) => File(file.path!))
            .toList();
      }
      return null;
    } catch (e) {
      CustomSnackbar.showError(message: 'Failed to pick files: $e');
      return null;
    }
  }

  /// Pick PDF document
  static Future<File?> pickPdfDocument() async {
    return await pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
  }

  /// Pick Word document
  static Future<File?> pickWordDocument() async {
    return await pickFile(
      type: FileType.custom,
      allowedExtensions: ['doc', 'docx'],
    );
  }

  /// Pick Excel document
  static Future<File?> pickExcelDocument() async {
    return await pickFile(
      type: FileType.custom,
      allowedExtensions: ['xls', 'xlsx'],
    );
  }

  /// Pick audio file
  static Future<File?> pickAudioFile() async {
    return await pickFile(
      type: FileType.audio,
    );
  }

  /// ============================================
  /// MEDIA PICKER (Image + Video)
  /// ============================================

  /// Pick image or video
  static Future<File?> pickMedia() async {
    return await pickFile(
      type: FileType.media,
    );
  }

  /// Pick multiple images or videos
  static Future<List<File>?> pickMultipleMedia() async {
    return await pickMultipleFiles(
      type: FileType.media,
    );
  }

  /// ============================================
  /// PERMISSION HANDLING (IMPROVED)
  /// ============================================

  /// Check and request camera permission
  static Future<bool> _checkCameraPermission() async {
    PermissionStatus status = await Permission.camera.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      status = await Permission.camera.request();
      return status.isGranted;
    }

    if (status.isPermanentlyDenied) {
      final shouldOpenSettings = await _showPermissionDialog(
        'Camera Permission Required',
        'Please enable camera permission from settings to take photos.',
      );

      if (shouldOpenSettings) {
        await openAppSettings();
      }
      return false;
    }

    return false;
  }

  /// Request gallery permission (FIXED VERSION)
  static Future<bool> _requestGalleryPermission() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;

        // Android 13+ (API 33+)
        if (androidInfo.version.sdkInt >= 33) {
          print('📱 Android 13+ detected, requesting photos permission');

          PermissionStatus photosStatus = await Permission.photos.status;
          print('📸 Photos permission status: $photosStatus');

          if (photosStatus.isGranted) {
            return true;
          }

          if (photosStatus.isDenied) {
            photosStatus = await Permission.photos.request();
            print('📸 After request: $photosStatus');
            return photosStatus.isGranted;
          }

          if (photosStatus.isPermanentlyDenied) {
            final shouldOpenSettings = await _showPermissionDialog(
              'Photos Permission Required',
              'Please enable photos permission from settings to select images.',
            );

            if (shouldOpenSettings) {
              await openAppSettings();
            }
            return false;
          }

          return photosStatus.isGranted;
        }
        // Android 12 and below (API 32 and below)
        else {
          print('📱 Android 12 or below detected, requesting storage permission');

          PermissionStatus storageStatus = await Permission.storage.status;
          print('💾 Storage permission status: $storageStatus');

          if (storageStatus.isGranted) {
            return true;
          }

          if (storageStatus.isDenied) {
            storageStatus = await Permission.storage.request();
            print('💾 After request: $storageStatus');
            return storageStatus.isGranted;
          }

          if (storageStatus.isPermanentlyDenied) {
            final shouldOpenSettings = await _showPermissionDialog(
              'Storage Permission Required',
              'Please enable storage permission from settings to access gallery.',
            );

            if (shouldOpenSettings) {
              await openAppSettings();
            }
            return false;
          }

          return storageStatus.isGranted;
        }
      }
      // iOS
      else if (Platform.isIOS) {
        print('📱 iOS detected, requesting photos permission');

        PermissionStatus photosStatus = await Permission.photos.status;
        print('📸 Photos permission status: $photosStatus');

        if (photosStatus.isGranted || photosStatus.isLimited) {
          return true;
        }

        if (photosStatus.isDenied) {
          photosStatus = await Permission.photos.request();
          print('📸 After request: $photosStatus');
          return photosStatus.isGranted || photosStatus.isLimited;
        }

        if (photosStatus.isPermanentlyDenied) {
          final shouldOpenSettings = await _showPermissionDialog(
            'Photos Permission Required',
            'Please enable photos permission from settings to select images.',
          );

          if (shouldOpenSettings) {
            await openAppSettings();
          }
          return false;
        }

        return photosStatus.isGranted || photosStatus.isLimited;
      }

      return true;
    } catch (e) {
      print('❌ Permission error: $e');
      return false;
    }
  }

  /// Show permission dialog
  static Future<bool> _showPermissionDialog(String title, String message) async {
    // You can implement a custom dialog here
    // For now, returning true to open settings
    return true;
  }

  /// Check and request storage permission (Legacy)
  static Future<bool> _checkStoragePermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+ doesn't need storage permission for scoped storage
        return true;
      }

      PermissionStatus status = await Permission.storage.status;
      if (status.isGranted) return true;
      if (status.isDenied) {
        status = await Permission.storage.request();
        return status.isGranted;
      }
      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }
    }
    return true; // iOS doesn't need storage permission
  }

  /// ============================================
  /// UTILITY METHODS
  /// ============================================

  /// Get file size in MB
  static double getFileSizeInMB(File file) {
    int bytes = file.lengthSync();
    return bytes / (1024 * 1024);
  }

  /// Get file extension
  static String getFileExtension(File file) {
    return file.path.split('.').last.toLowerCase();
  }

  /// Check if file is image
  static bool isImageFile(File file) {
    String ext = getFileExtension(file);
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);
  }

  /// Check if file is video
  static bool isVideoFile(File file) {
    String ext = getFileExtension(file);
    return ['mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv'].contains(ext);
  }

  /// Check if file is document
  static bool isDocumentFile(File file) {
    String ext = getFileExtension(file);
    return ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt']
        .contains(ext);
  }

  /// Validate file size (in MB)
  static bool validateFileSize(File file, double maxSizeMB) {
    double fileSizeMB = getFileSizeInMB(file);
    return fileSizeMB <= maxSizeMB;
  }
}