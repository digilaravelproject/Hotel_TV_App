// lib/core/utils/image_compress_util.dart

import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Utility class for compressing images while maintaining quality
class ImageCompressUtil {
  /// Compress image with custom quality and dimensions
  ///
  /// [file] - Original image file
  /// [quality] - Compression quality (0-100), default 85
  /// [maxWidth] - Maximum width, default 1024
  /// [maxHeight] - Maximum height, default 1024
  /// [format] - Output format (jpg, png, heic, webp), default jpg
  static Future<File?> compressImage(
      File file, {
        int quality = 85,
        int maxWidth = 1024,
        int maxHeight = 1024,
        CompressFormat format = CompressFormat.jpeg,
      }) async {
    try {
      print('📦 Starting image compression...');
      print('📦 Original file size: ${_getFileSizeInMB(file)} MB');

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(
        tempDir.path,
        '${DateTime.now().millisecondsSinceEpoch}_compressed${_getExtension(format)}',
      );

      // Compress image
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: format,
      );

      if (compressedFile != null) {
        final compressedFileObj = File(compressedFile.path);
        print('✅ Image compressed successfully');
        print('📦 Compressed file size: ${_getFileSizeInMB(compressedFileObj)} MB');
        print('📊 Size reduced by: ${_getCompressionPercentage(file, compressedFileObj)}%');

        return compressedFileObj;
      }

      print('⚠️ Compression returned null, using original file');
      return file;
    } catch (e) {
      print('❌ Image compression error: $e');
      return file; // Return original file if compression fails
    }
  }

  /// Compress image for profile (smaller size)
  static Future<File?> compressForProfile(File file) async {
    return await compressImage(
      file,
      quality: 85,
      maxWidth: 512,
      maxHeight: 512,
      format: CompressFormat.jpeg,
    );
  }

  /// Compress image for chat (medium size)
  static Future<File?> compressForChat(File file) async {
    return await compressImage(
      file,
      quality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
      format: CompressFormat.jpeg,
    );
  }

  /// Compress image for high quality (larger size)
  static Future<File?> compressHighQuality(File file) async {
    return await compressImage(
      file,
      quality: 90,
      maxWidth: 2048,
      maxHeight: 2048,
      format: CompressFormat.jpeg,
    );
  }

  /// Compress multiple images
  static Future<List<File>> compressMultipleImages(
      List<File> files, {
        int quality = 85,
        int maxWidth = 1024,
        int maxHeight = 1024,
      }) async {
    List<File> compressedFiles = [];

    for (var file in files) {
      final compressed = await compressImage(
        file,
        quality: quality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );

      if (compressed != null) {
        compressedFiles.add(compressed);
      } else {
        compressedFiles.add(file);
      }
    }

    return compressedFiles;
  }

  /// Get file size in MB
  static double _getFileSizeInMB(File file) {
    int bytes = file.lengthSync();
    return bytes / (1024 * 1024);
  }

  /// Get compression percentage
  static String _getCompressionPercentage(File original, File compressed) {
    double originalSize = _getFileSizeInMB(original);
    double compressedSize = _getFileSizeInMB(compressed);
    double percentage = ((originalSize - compressedSize) / originalSize) * 100;
    return percentage.toStringAsFixed(2);
  }

  /// Get file extension based on format
  static String _getExtension(CompressFormat format) {
    switch (format) {
      case CompressFormat.jpeg:
        return '.jpg';
      case CompressFormat.png:
        return '.png';
      case CompressFormat.heic:
        return '.heic';
      case CompressFormat.webp:
        return '.webp';
      default:
        return '.jpg';
    }
  }

  /// Check if image needs compression
  /// Returns true if file size is greater than maxSizeMB
  static bool needsCompression(File file, {double maxSizeMB = 1.0}) {
    double fileSizeMB = _getFileSizeInMB(file);
    return fileSizeMB > maxSizeMB;
  }

  /// Auto compress if needed
  /// Only compresses if file size exceeds threshold
  static Future<File?> autoCompress(
      File file, {
        double maxSizeMB = 1.0,
        int quality = 85,
      }) async {
    if (needsCompression(file, maxSizeMB: maxSizeMB)) {
      print('🔄 Auto-compressing image (size > $maxSizeMB MB)');
      return await compressImage(file, quality: quality);
    }

    print('✅ Image size is acceptable, no compression needed');
    return file;
  }
}