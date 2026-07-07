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

  static Future<String?> _cacheOfflineMediaAndGetJson() async {
    try {
      final loginDataStr = SharedPrefs.getString(AppConstants.tvLoginDataKey);
      if (loginDataStr == null || loginDataStr.isEmpty) return null;

      final Map<String, dynamic> root = jsonDecode(loginDataStr);
      final Map<String, dynamic>? data = root['data'] as Map<String, dynamic>?;
      if (data == null) return loginDataStr;

      final Map<String, dynamic>? hotel = data['hotel'] as Map<String, dynamic>?;
      if (hotel == null) return loginDataStr;

      final Map<String, dynamic>? media = hotel['media'] as Map<String, dynamic>?;
      if (media == null) return loginDataStr;

      final dir = await getTemplateDirectory();
      final cacheDir = Directory(p.join(dir.path, 'cached_media'));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final dio = Dio();

      Future<String> _cacheImage(String url) async {
        if (!url.startsWith('http')) return url;
        try {
          final uri = Uri.parse(url);
          final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'image_${url.hashCode}';
          final localFile = File(p.join(cacheDir.path, fileName));
          
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

      final String? logoImage = media['logo_image'] as String?;
      if (logoImage != null && logoImage.isNotEmpty) {
        media['logo_image'] = await _cacheImage(logoImage);
      }

      final String? coverImage = media['cover_image'] as String?;
      if (coverImage != null && coverImage.isNotEmpty) {
        media['cover_image'] = await _cacheImage(coverImage);
      }

      final List? sliders = media['slider_images'] as List?;
      if (sliders != null && sliders.isNotEmpty) {
        final List<String> cachedSliders = [];
        for (final item in sliders) {
          if (item != null) {
            cachedSliders.add(await _cacheImage(item.toString()));
          }
        }
        media['slider_images'] = cachedSliders;
      }

      return jsonEncode(root);
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

  /// Checks the backend for a new template version, and updates silently if available
  static Future<void> checkAndUpdateTemplateSilent({Function(double)? onProgress}) async {
    if (_isUpdating) {
      Logger.i('[TemplateManager] Update check/download is already in progress. Ignoring duplicate call.');
      return;
    }
    _isUpdating = true;
    try {
      Logger.i('[TemplateManager] Checking for template updates...');
      final ApiClient apiClient = ApiClient();
      
      final response = await apiClient.get(
        ApiConstants.checkTemplateVersionUri,
        enableRetry: false,
      );

      if (response.statusCode == 200 && response.data != null && response.data['status'] == true) {
        final dataMap = response.data['data'] as Map<String, dynamic>?;
        final templateData = dataMap?['template'] as Map<String, dynamic>?;
        final String? latestVersion = templateData?['latest_version']?.toString();
        final String? downloadUrl = templateData?['download_url'];

        // Save the updated response data and regenerate template config
        await SharedPrefs.setString(AppConstants.tvLoginDataKey, jsonEncode(response.data));
        await regenerateDataJson();

        if (latestVersion == null || downloadUrl == null || downloadUrl.isEmpty) {
          Logger.w('[TemplateManager] Update check returned empty version or download URL.');
          return;
        }

        final currentVersion = SharedPrefs.getString(AppConstants.templateVersionKey) ?? '0.0';
        Logger.i('[TemplateManager] Current version: $currentVersion, Latest version: $latestVersion');

        // Parse versions to compare
        double currentVal = double.tryParse(currentVersion) ?? 0.0;
        double latestVal = double.tryParse(latestVersion) ?? 0.0;

        if (latestVal > currentVal || !await isTemplateDownloaded()) {
          Logger.i('[TemplateManager] New version available. Starting background download...');
          await _downloadAndExtractTemplate(downloadUrl, latestVersion, onProgress: onProgress);
        } else {
          Logger.i('[TemplateManager] Template is already up to date.');
        }
      } else {
        Logger.w('[TemplateManager] Update check response invalid or template inactive.');
      }
    } catch (e) {
      Logger.e('[TemplateManager] Error checking template updates: $e');
    } finally {
      _isUpdating = false;
    }
  }

  /// Downloads the template ZIP, unzips it into the template directory, and deletes the ZIP file.
  static Future<void> _downloadAndExtractTemplate(String url, String newVersion, {Function(double)? onProgress}) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final tempZipPath = p.join(docDir.path, 'temp_template.zip');
      
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

      final templateDir = await getTemplateDirectory();
      
      // Clean existing files in directory to avoid conflict
      if (await templateDir.exists()) {
        await templateDir.delete(recursive: true);
        await templateDir.create(recursive: true);
      }

      // Read ZIP contents
      final bytes = await File(tempZipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Extract ZIP entries
      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          final outFile = File(p.join(templateDir.path, filename));
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(data);
        } else {
          final outDir = Directory(p.join(templateDir.path, filename));
          await outDir.create(recursive: true);
        }
      }

      // Clean up temp ZIP
      final tempZipFile = File(tempZipPath);
      if (await tempZipFile.exists()) {
        await tempZipFile.delete();
      }

      // Save new version code locally
      await SharedPrefs.setString(AppConstants.templateVersionKey, newVersion);

      // Regenerate data.json with latest login data
      await regenerateDataJson();

      Logger.i('[TemplateManager] Template updated successfully to version $newVersion.');
    } catch (e) {
      Logger.e('[TemplateManager] Error unzipping or downloading template: $e');
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
      final templateData = innerData?['template'] as Map<String, dynamic>?;

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
