import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../constants/app_constants.dart';
import '../../constants/api_constents.dart';
import '../network/api_client.dart';
import '../storage/shared_prefs.dart';
import '../storage/token_manger.dart';
import '../device/device_info_service.dart';
import '../../utils/logger.dart';

class TemplateManagerService {
  static const String _templateFolderName = 'tv_template';
  static bool _isUpdating = false;

  /// Gets the directory where the template assets are stored
  static Future<Directory> getTemplateDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final templatePath = p.join(docDir.path, _templateFolderName);
    final dir = Directory(templatePath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Checks if index.html exists locally in the template folder
  static Future<bool> isTemplateDownloaded() async {
    final dir = await getTemplateDirectory();
    final indexFile = File(p.join(dir.path, 'index.html'));
    return await indexFile.exists();
  }

  /// Returns the local path to the template's index.html
  static Future<String> getTemplatePath() async {
    final dir = await getTemplateDirectory();
    return p.join(dir.path, 'index.html');
  }

  static Future<String> _downloadAndGetLocalPath(String url, Directory cacheDir, Dio dio) async {
    try {
      final uri = Uri.parse(url);
      final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'image_${url.hashCode}';
      final localFile = File(p.join(cacheDir.path, fileName));
      
      if (await localFile.exists()) {
        Logger.i('[TemplateManager] Offline media already cached: $fileName');
        return 'cached_media/$fileName';
      }
      
      Logger.i('[TemplateManager] Downloading offline media: $url');
      await dio.download(url, localFile.path);
      Logger.i('[TemplateManager] Offline media cached at: ${localFile.path}');
      
      return 'cached_media/$fileName';
    } catch (e) {
      Logger.w('[TemplateManager] Failed to cache offline media ($url): $e');
      final uri = Uri.parse(url);
      final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'image_${url.hashCode}';
      final localFile = File(p.join(cacheDir.path, fileName));
      if (await localFile.exists()) {
        return 'cached_media/$fileName';
      }
      return url;
    }
  }

  static Future<dynamic> _cacheAllUrls(dynamic node, Directory cacheDir, Dio dio) async {
    if (node is Map) {
      final Map<String, dynamic> result = {};
      for (final entry in node.entries) {
        result[entry.key] = await _cacheAllUrls(entry.value, cacheDir, dio);
      }
      return result;
    } else if (node is List) {
      final List<dynamic> result = [];
      for (final item in node) {
        result.add(await _cacheAllUrls(item, cacheDir, dio));
      }
      return result;
    } else if (node is String) {
      final String val = node.trim();
      // Detect image URLs (ends with typical extensions or contains uploads/storage)
      if (val.startsWith('http') && 
          !val.endsWith('.zip') &&
          (val.contains('.png') || 
           val.contains('.jpg') || 
           val.contains('.jpeg') || 
           val.contains('.webp') || 
           val.contains('.gif') || 
           val.contains('/uploads/') || 
           val.contains('/storage/'))) {
        return await _downloadAndGetLocalPath(val, cacheDir, dio);
      }
      return node;
    }
    return node;
  }

  static Future<String?> _cacheOfflineMediaAndGetJson() async {
    try {
      final loginDataStr = SharedPrefs.getString(AppConstants.tvLoginDataKey);
      if (loginDataStr == null || loginDataStr.isEmpty) return null;

      final dynamic root = jsonDecode(loginDataStr);
      
      final dir = await getTemplateDirectory();
      final cacheDir = Directory(p.join(dir.path, 'cached_media'));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      final updatedRoot = await _cacheAllUrls(root, cacheDir, dio);

      // Inject native network details (gateway, subnet_mask, dns) and persistent selectedLiveTvPort into device node
      try {
        final deviceDetails = await DeviceInfoService.getFullDeviceInfo();
        final savedPort = SharedPrefs.getString('selectedLiveTvPort');

        if (updatedRoot is Map) {
          final dataMap = updatedRoot['data'] is Map
              ? updatedRoot['data'] as Map<String, dynamic>
              : updatedRoot as Map<String, dynamic>;

          if (savedPort != null && savedPort.isNotEmpty && savedPort != 'null') {
            dataMap['selectedLiveTvPort'] = savedPort;
            dataMap['liveTvPort'] = savedPort;
            dataMap['tvInputPort'] = savedPort;
          }

          if (dataMap['device'] is Map) {
            final devMap = Map<String, dynamic>.from(dataMap['device'] as Map);
            devMap['gateway'] = deviceDetails['gateway'] ?? '';
            devMap['subnet_mask'] = deviceDetails['subnet'] ?? '';
            devMap['dns'] = deviceDetails['dns'] ?? '';
            if (savedPort != null && savedPort.isNotEmpty && savedPort != 'null') {
              devMap['tvInputPort'] = savedPort;
              devMap['liveTvPort'] = savedPort;
              devMap['selectedLiveTvPort'] = savedPort;
            }
            dataMap['device'] = devMap;
          }
        }
      } catch (_) {}

      return jsonEncode(updatedRoot);
    } catch (e) {
      Logger.e('[TemplateManager] Error caching offline media: $e');
      return SharedPrefs.getString(AppConstants.tvLoginDataKey);
    }
  }

  /// Regenerates data.json in the template directory from stored login data
  static Future<void> regenerateDataJson() async {
    try {
      final jsonToWrite = await _cacheOfflineMediaAndGetJson();
      if (jsonToWrite == null || jsonToWrite.isEmpty) return;

      final dir = await getTemplateDirectory();
      final file = File(p.join(dir.path, 'data.json'));
      await file.writeAsString(jsonToWrite);
      Logger.i('[TemplateManager] data.json regenerated successfully.');
    } catch (e) {
      Logger.e('[TemplateManager] Error regenerating data.json: $e');
    }
  }

  /// Checks the backend for a new template version, and updates silently if available.
  /// Returns 0 for no changes, 1 if only JSON data changed, and 2 if the template was updated.
  static Future<int> checkAndUpdateTemplateSilent({Function(double)? onProgress}) async {
    if (_isUpdating) {
      Logger.i('[TemplateManager] Update check/download is already in progress. Ignoring duplicate call.');
      return 0;
    }
    _isUpdating = true;
    try {
      Logger.i('[TemplateManager] Checking for template updates...');
      final ApiClient apiClient = ApiClient();
      
      final response = await apiClient.get(
        ApiConstants.checkTemplateVersionUri,
        enableRetry: false,
      );

      if (response.statusCode == 401 || 
          (response.data is Map && 
           response.data['status'] == false && 
           response.data['message']?.toString().toLowerCase().contains('unauthenticated') == true)) {
        Logger.w('[TemplateManager] Unauthenticated! Token is invalid.');
        return -1;
      }

      if (response.statusCode == 200 && response.data != null && response.data['status'] == true) {
        final dataMap = response.data['data'] as Map<String, dynamic>?;
        final token = dataMap?['auth']?['token']?.toString() ??
            dataMap?['token']?.toString() ??
            response.data['token']?.toString();
        if (token != null && token.isNotEmpty) {
          await TokenManager.saveToken(token);
        }

        final templateData = (dataMap?['template'] ?? response.data['template']) as Map<String, dynamic>?;
        final String? latestVersion = templateData?['latest_version']?.toString();
        final String? downloadUrl = templateData?['download_url'];

        // Check if data actually changed
        final oldDataStr = SharedPrefs.getString(AppConstants.tvLoginDataKey);
        final newDataStr = jsonEncode(response.data);
        final bool dataChanged = oldDataStr != newDataStr;

        // Save the updated response data and regenerate template config
        await SharedPrefs.setString(AppConstants.tvLoginDataKey, newDataStr);
        await regenerateDataJson();

        if (latestVersion == null || downloadUrl == null || downloadUrl.isEmpty) {
          Logger.w('[TemplateManager] Update check returned empty version or download URL.');
          return dataChanged ? 1 : 0;
        }

        final currentVersion = SharedPrefs.getString(AppConstants.templateVersionKey) ?? '0.0';
        Logger.i('[TemplateManager] Current version: $currentVersion, Latest version: $latestVersion');

        // Parse versions to compare
        double currentVal = double.tryParse(currentVersion) ?? 0.0;
        double latestVal = double.tryParse(latestVersion) ?? 0.0;

        if (latestVal > currentVal || !await isTemplateDownloaded()) {
          Logger.i('[TemplateManager] New version available ($latestVersion). Starting background download...');
          await _downloadAndExtractTemplate(downloadUrl, latestVersion, onProgress: onProgress);
          return 2; // Return 2 because template updated
        } else {
          Logger.i('[TemplateManager] Template is already up to date (Version $currentVersion).');
          return dataChanged ? 1 : 0; // Return 1 if JSON data changed, otherwise 0
        }
      } else {
        Logger.w('[TemplateManager] Update check response invalid or template inactive.');
      }
    } catch (e) {
      Logger.e('[TemplateManager] Error checking template updates: $e');
      if (e is DioException && e.response?.statusCode == 401) {
        return -1;
      }
    } finally {
      _isUpdating = false;
    }
    return 0;
  }

  /// Downloads the template ZIP, unzips it into the template directory, and deletes the ZIP file.
  static Future<void> _downloadAndExtractTemplate(String url, String newVersion, {Function(double)? onProgress}) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final tempZipPath = p.join(docDir.path, 'temp_template.zip');
      final tempExtractPath = p.join(docDir.path, 'temp_extract');
      
      Logger.i('[TemplateManager] Downloading zip from: $url');
      final dio = Dio();
      await dio.download(
        url,
        tempZipPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            double progress = received / total;
            if (onProgress != null) {
              onProgress(progress);
            }
          }
        },
      );
      Logger.i('[TemplateManager] Download completed. Starting extraction...');

      final tempExtractDir = Directory(tempExtractPath);
      if (await tempExtractDir.exists()) {
        await tempExtractDir.delete(recursive: true);
      }
      await tempExtractDir.create(recursive: true);

      // Read ZIP contents
      final bytes = await File(tempZipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Extract ZIP entries into temp directory first
      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          final outFile = File(p.join(tempExtractDir.path, filename));
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(data);
        } else {
          final outDir = Directory(p.join(tempExtractDir.path, filename));
          await outDir.create(recursive: true);
        }
      }

      // Check if ZIP extracted into a single top-level wrapper directory
      var targetDirToMove = tempExtractDir;
      final extractedList = tempExtractDir.listSync();
      if (extractedList.length == 1 && extractedList.first is Directory) {
        targetDirToMove = extractedList.first as Directory;
      }

      final finalTemplateDir = await getTemplateDirectory();
      
      // Clean target directory and copy extracted files safely
      if (await finalTemplateDir.exists()) {
        await finalTemplateDir.delete(recursive: true);
      }
      await finalTemplateDir.create(recursive: true);

      for (final entity in targetDirToMove.listSync()) {
        final destPath = p.join(finalTemplateDir.path, p.basename(entity.path));
        if (entity is File) {
          await entity.copy(destPath);
        } else if (entity is Directory) {
          await _copyDirectory(entity, Directory(destPath));
        }
      }

      // Clean up temp folders
      try {
        await tempExtractDir.delete(recursive: true);
        final tempZipFile = File(tempZipPath);
        if (await tempZipFile.exists()) {
          await tempZipFile.delete();
        }
      } catch (_) {}

      // Save new version code locally
      await SharedPrefs.setString(AppConstants.templateVersionKey, newVersion);

      // Regenerate data.json with latest login data
      await regenerateDataJson();

      Logger.i('[TemplateManager] Template updated successfully to version $newVersion.');
    } catch (e) {
      Logger.e('[TemplateManager] Error unzipping or downloading template: $e');
    }
  }

  static Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final newPath = p.join(destination.path, p.basename(entity.path));
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      } else if (entity is File) {
        await entity.copy(newPath);
      }
    }
  }

  /// Downloads and extracts the template using details saved in local storage (e.g. after login)
  static Future<void> downloadTemplateFromSavedData({Function(double)? onProgress}) async {
    try {
      final loginData = SharedPrefs.getString(AppConstants.tvLoginDataKey);
      if (loginData == null || loginData.isEmpty) {
        Logger.w('[TemplateManager] No login data found to download template.');
        return;
      }

      final dataMap = jsonDecode(loginData) as Map<String, dynamic>;
      final innerData = dataMap['data'] as Map<String, dynamic>?;
      final templateData = ((innerData != null && innerData['template'] is Map)
          ? innerData['template']
          : (dataMap['template'] is Map ? dataMap['template'] : null)) as Map<String, dynamic>?;

      final String? latestVersion = templateData?['latest_version']?.toString();
      final String? downloadUrl = templateData?['download_url'];

      if (latestVersion == null || downloadUrl == null || downloadUrl.isEmpty) {
        Logger.w('[TemplateManager] Template version or download URL not found in login data.');
        return;
      }

      await _downloadAndExtractTemplate(downloadUrl, latestVersion, onProgress: onProgress);
    } catch (e) {
      Logger.e('[TemplateManager] Error downloading template from saved data: $e');
    }
  }
}
