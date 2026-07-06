import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data'; // Import for Uint8List


class CacheManager {
  static final DefaultCacheManager _cacheManager = DefaultCacheManager();

  static Future<File> downloadFile(String url) async {
    final fileInfo = await _cacheManager.downloadFile(url);
    return fileInfo.file;
  }

  static Future<File?> getFileFromCache(String url) async {
    final fileInfo = await _cacheManager.getFileFromCache(url);
    return fileInfo?.file;
  }

  static Future<void> putFileInCache(String url, Uint8List bytes) async {
    await _cacheManager.putFile(
      url,
      bytes,
      key: url,
      maxAge: const Duration(days: 7),
    );
  }

  static Future<void> removeFile(String url) async {
    await _cacheManager.removeFile(url);
  }

  static Future<void> clearCache() async {
    await _cacheManager.emptyCache();
  }

  static Future<String> getCachePath() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }

  static Future<int> getCacheSize() async {
    final dir = await getTemporaryDirectory();
    return await _calculateDirSize(dir);
  }

  static Future<int> _calculateDirSize(Directory dir) async {
    int size = 0;
    try {
      final List<FileSystemEntity> entities = await dir.list().toList();
      for (var entity in entities) {
        if (entity is File) {
          size += await entity.length();
        } else if (entity is Directory) {
          size += await _calculateDirSize(entity);
        }
      }
    } catch (e) {
      // Handle error
    }
    return size;
  }
}
