import 'dart:async';
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

  /// Keys that change on every API call (timestamps, tokens, request ids).
  /// These must be ignored when deciding whether real template/room data changed,
  /// otherwise the app treats every poll as an "update" and reloads endlessly.
  static const Set<String> _volatileKeys = {
    'server_time', 'serverTime', 'server_timestamp', 'serverTimestamp',
    'timestamp', 'time', 'now', 'generated_at', 'generatedAt',
    'token', 'auth_token', 'accessToken', 'access_token',
    'request_id', 'requestId', 'nonce', 'expires_at', 'expiresAt',
    'offset', 'tzOffset', 'tz_offset',
  };

  /// Recursively strips volatile keys so two payloads differing only in
  /// timestamps/tokens are treated as identical.
  static dynamic _normalizeForComparison(dynamic node) {
    if (node is Map) {
      final out = <String, dynamic>{};
      node.forEach((k, v) {
        final key = k.toString();
        if (_volatileKeys.contains(key)) return;
        out[key] = _normalizeForComparison(v);
      });
      return out;
    }
    if (node is List) {
      return node.map(_normalizeForComparison).toList();
    }
    return node;
  }

  /// Stable, comparable string for an API payload. Accepts either a raw JSON
  /// string or a parsed object. Volatile fields are removed before encoding.
  static String stablePayloadString(dynamic payload) {
    dynamic node = payload;
    if (payload is String) {
      if (payload.isEmpty) return '';
      try {
        node = jsonDecode(payload);
      } catch (_) {
        return payload; // Not JSON — compare verbatim.
      }
    }
    try {
      return jsonEncode(_normalizeForComparison(node));
    } catch (_) {
      return node?.toString() ?? '';
    }
  }

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

  /// A cache file is only usable if it exists and is non-empty.
  /// Guards against truncated leftovers from an interrupted download.
  static Future<bool> _isValidCacheFile(File f) async {
    try {
      if (!await f.exists()) return false;
      return await f.length() > 0;
    } catch (_) {
      return false;
    }
  }

  static Future<String> _downloadAndGetLocalPath(String url, Directory cacheDir, Dio dio) async {
    final uri = Uri.tryParse(url);
    final fileName =
        (uri != null && uri.pathSegments.isNotEmpty) ? uri.pathSegments.last : 'image_${url.hashCode}';
    final localFile = File(p.join(cacheDir.path, fileName));

    // Already cached AND valid → reuse. Unchanged images are never re-downloaded.
    if (await _isValidCacheFile(localFile)) {
      Logger.i('[TemplateManager] Offline media already cached: $fileName');
      return 'cached_media/$fileName';
    }

    // Drop corrupt/zero-byte leftovers, else they'd keep rendering as broken.
    if (await localFile.exists()) {
      try {
        await localFile.delete();
      } catch (_) {}
    }

    final tempFile = File('${localFile.path}.part');
    try {
      Logger.i('[TemplateManager] Downloading offline media: $url');
      await _withDownloadSlot(() => dio.download(url, tempFile.path));

      if (!await _isValidCacheFile(tempFile)) {
        throw Exception('download produced an empty file');
      }

      // Publish only a fully downloaded file (no partial image is ever served).
      if (await localFile.exists()) {
        try {
          await localFile.delete();
        } catch (_) {}
      }
      await tempFile.rename(localFile.path);
      Logger.i('[TemplateManager] Offline media cached at: ${localFile.path}');

      return 'cached_media/$fileName';
    } catch (e) {
      Logger.w('[TemplateManager] Failed to cache offline media ($url): $e');
      try {
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}
      // Prefer any previously valid cache over the remote URL (offline-safe).
      if (await _isValidCacheFile(localFile)) {
        return 'cached_media/$fileName';
      }
      return url;
    }
  }

  static Future<dynamic> _cacheAllUrls(dynamic node, Directory cacheDir, Dio dio) async {
    if (node is Map) {
      final Map<String, dynamic> result = {};
      // Process sibling keys concurrently (bounded) instead of one-by-one.
      final entries = node.entries.toList();
      final values = await Future.wait(
        entries.map((e) => _cacheAllUrls(e.value, cacheDir, dio)),
        eagerError: false,
      );
      for (var i = 0; i < entries.length; i++) {
        result[entries[i].key] = values[i];
      }
      return result;
    } else if (node is List) {
      // Images inside one array download in parallel — big speed win.
      return await Future.wait(
        node.map((item) => _cacheAllUrls(item, cacheDir, dio)),
        eagerError: false,
      );
    } else if (node is String) {
      final String val = node.trim();
      // Detect image URLs (ends with typical extensions or contains uploads/storage)
      if (val.startsWith('http') && _isCacheableUrl(val)) {
        return await _downloadAndGetLocalPath(val, cacheDir, dio);
      }
      return node;
    }
    return node;
  }

  static final Dio _sharedDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// Limits concurrent image downloads so a large gallery doesn't hammer
  /// the network (or exhaust sockets) all at once.
  ///
  /// FIFO waiter queue — no busy-wait polling. A waiting download is woken
  /// only when a slot actually frees up.
  static const int _maxConcurrentDownloads = 5;
  static int _activeDownloads = 0;
  static final List<Completer<void>> _waitQueue = [];

  static Future<void> _acquireDownloadSlot() {
    if (_activeDownloads < _maxConcurrentDownloads) {
      _activeDownloads++;
      return Future.value();
    }
    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  static void _releaseDownloadSlot() {
    if (_waitQueue.isNotEmpty) {
      // Hand the slot straight to the oldest waiter (count stays the same).
      _waitQueue.removeAt(0).complete();
    } else {
      _activeDownloads--;
    }
  }

  static Future<T> _withDownloadSlot<T>(Future<T> Function() task) async {
    await _acquireDownloadSlot();
    try {
      return await task();
    } finally {
      _releaseDownloadSlot();
    }
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

      final updatedRoot = await _cacheAllUrls(root, cacheDir, _sharedDio);

      // Inject native network details (gateway, subnet_mask, dns), real serial, and persistent selectedLiveTvPort into device node
      try {
        final deviceDetails = await DeviceInfoService.getFullDeviceInfo(forceRefresh: true);
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

            final realSerial = deviceDetails['serial']?.toString() ?? '';
            final realDeviceId = deviceDetails['deviceId']?.toString() ?? '';
            final realMac = deviceDetails['macAddress']?.toString() ?? '';
            final realIp = deviceDetails['ipAddress']?.toString() ?? '';

            if (realSerial.isNotEmpty) {
              devMap['serial'] = realSerial;
              devMap['Serial'] = realSerial;
              devMap['device_id'] = realSerial;
              devMap['deviceId'] = realSerial;
            } else if (realDeviceId.isNotEmpty) {
              devMap['serial'] = realDeviceId;
              devMap['Serial'] = realDeviceId;
              devMap['device_id'] = realDeviceId;
              devMap['deviceId'] = realDeviceId;
            }
            if (realMac.isNotEmpty) {
              devMap['mac_address'] = realMac;
              devMap['macAddress'] = realMac;
              devMap['mac'] = realMac;
              devMap['MAC'] = realMac;
            }
            if (realIp.isNotEmpty) {
              devMap['ip_address'] = realIp;
              devMap['ipAddress'] = realIp;
              devMap['ip'] = realIp;
              devMap['IP'] = realIp;
            }

            // Inject dynamic template version from template object or SharedPreferences
            final templateMap = dataMap['template'] as Map<String, dynamic>?;
            final dynamicVer = templateMap?['latest_version']?.toString() ??
                SharedPrefs.getString(AppConstants.templateVersionKey) ??
                '';
            devMap['version'] = dynamicVer;
            devMap['Ver'] = dynamicVer;

            if (savedPort != null && savedPort.isNotEmpty && savedPort != 'null') {
              devMap['tvInputPort'] = savedPort;
              devMap['liveTvPort'] = savedPort;
              devMap['selectedLiveTvPort'] = savedPort;
            }

            // Inject TV display name = "Device Name (Room No)"
            // Real device brand + model directly use karo — static maps nahi
            final roomNo = devMap['room_no']?.toString() ?? '';
            if (roomNo.isNotEmpty) {
              // Real device details: brand aur model directly from deviceDetails (Android hardware)
              final realBrand = deviceDetails['brand']?.toString() ?? devMap['brand']?.toString() ?? '';
              final realModel = deviceDetails['model']?.toString() ?? devMap['model']?.toString() ?? '';

              // Clean: underscores/hyphens hatao, capitalize karo
              final cleanBrand = _cleanDeviceWord(realBrand);
              final cleanModel = _cleanDeviceWord(realModel);

              // Agar brand aur model alag hain to combine karo, warna sirf ek use karo
              final deviceLabel = (cleanBrand.isNotEmpty && cleanModel.isNotEmpty &&
                      !cleanModel.toLowerCase().contains(cleanBrand.toLowerCase()))
                  ? '$cleanBrand $cleanModel'
                  : (cleanBrand.isNotEmpty ? cleanBrand : cleanModel);

              final tvDisplayName = deviceLabel.isNotEmpty
                  ? '$deviceLabel (Room $roomNo)'
                  : 'Room $roomNo';

              devMap['tv_display_name'] = tvDisplayName;
              devMap['tvDisplayName'] = tvDisplayName;
              devMap['tv_name'] = tvDisplayName;
              // Persist for native Android device name + JS injection
              await SharedPrefs.setString('tv_display_name', tvDisplayName);
              Logger.i('[TemplateManager] tv_display_name → $tvDisplayName (brand=$realBrand, model=$realModel)');
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

  /// Returns true when every image URL in the stored login data is already
  /// downloaded into cached_media/. Used to decide if startup can skip blocking.
  static Future<bool> isOfflineMediaReady() async {
    try {
      final loginDataStr = SharedPrefs.getString(AppConstants.tvLoginDataKey);
      if (loginDataStr == null || loginDataStr.isEmpty) return false;

      final dir = await getTemplateDirectory();
      final cacheDir = Directory(p.join(dir.path, 'cached_media'));

      final List<String> pending = [];
      await _collectPendingUrls(jsonDecode(loginDataStr), pending);

      if (pending.isEmpty) return true;

      // Every pending URL must exist locally AND be non-empty.
      // Using exists() alone would let a 0-byte crash leftover count as
      // "ready", so the page would render a broken image instead of waiting.
      for (final url in pending) {
        final uri = Uri.tryParse(url);
        final fileName = (uri != null && uri.pathSegments.isNotEmpty)
            ? uri.pathSegments.last
            : 'image_${url.hashCode}';
        if (!await _isValidCacheFile(File(p.join(cacheDir.path, fileName)))) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Collects remote image URLs that still need caching (skips ones already
  /// rewritten to cached_media/).
  static Future<void> _collectPendingUrls(dynamic node, List<String> out) async {
    if (node is Map) {
      for (final v in node.values) {
        await _collectPendingUrls(v, out);
      }
    } else if (node is List) {
      for (final v in node) {
        await _collectPendingUrls(v, out);
      }
    } else if (node is String) {
      final val = node.trim();
      if (val.startsWith('http') && _isCacheableUrl(val)) {
        out.add(val);
      }
    }
  }

  /// Single source of truth for which remote strings are cacheable images.
  static bool _isCacheableUrl(String val) {
    if (val.endsWith('.zip')) return false;
    return val.contains('.png') ||
        val.contains('.jpg') ||
        val.contains('.jpeg') ||
        val.contains('.webp') ||
        val.contains('.gif') ||
        val.contains('/uploads/') ||
        val.contains('/storage/');
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

      if (response.statusCode == 403 || 
          (response.data is Map && 
           (response.data['error_code'] == 'DEMO_EXPIRED' || 
            response.data['message']?.toString().toLowerCase().contains('expired') == true))) {
        Logger.w('[TemplateManager] Demo expired! 403 received from server.');
        return -3;
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

        // Check if data actually changed (ignore volatile timestamp/token fields)
        final oldDataStr = SharedPrefs.getString(AppConstants.tvLoginDataKey);
        final newDataStr = jsonEncode(response.data);
        final bool dataChanged =
            stablePayloadString(oldDataStr) != stablePayloadString(newDataStr);

        // Save the updated response data and regenerate template config
        await SharedPrefs.setString(AppConstants.tvLoginDataKey, newDataStr);
        await regenerateDataJson();

        if (latestVersion == null || downloadUrl == null || downloadUrl.isEmpty) {
          Logger.w('[TemplateManager] Update check returned empty version or download URL.');
          return dataChanged ? 1 : 0;
        }

        final currentVersion = SharedPrefs.getString(AppConstants.templateVersionKey) ?? '';
        final currentTemplateId = SharedPrefs.getString('template_id') ?? '';
        final String? latestTemplateId = templateData?['template_id']?.toString();

        Logger.i('[TemplateManager] Current templateId: $currentTemplateId, Latest templateId: $latestTemplateId');
        Logger.i('[TemplateManager] Current version: $currentVersion, Latest version: $latestVersion');

        // Step 1: Template ID changed → download karo
        final bool templateIdChanged = latestTemplateId != null &&
            latestTemplateId.isNotEmpty &&
            latestTemplateId != currentTemplateId;

        // Step 2: Template ID same → version string compare karo
        final bool versionChanged = !templateIdChanged &&
            latestVersion.isNotEmpty &&
            latestVersion != currentVersion;

        // Step 3: Template file missing
        final bool isMissing = !await isTemplateDownloaded();

        if (templateIdChanged || versionChanged || isMissing) {
          final reason = templateIdChanged
              ? 'Template ID changed ($currentTemplateId → $latestTemplateId)'
              : versionChanged
                  ? 'Version changed ($currentVersion → $latestVersion)'
                  : 'Template files missing';
          Logger.i('[TemplateManager] Download triggered: $reason');
          // Save template_id BEFORE download to prevent parallel re-trigger
          if (latestTemplateId != null && latestTemplateId.isNotEmpty) {
            await SharedPrefs.setString('template_id', latestTemplateId);
          }
          await _downloadAndExtractTemplate(downloadUrl, latestVersion, onProgress: onProgress);
          return 2; // Return 2 because template updated
        } else {
          Logger.i('[TemplateManager] Template is already up to date (ID: $currentTemplateId, Version: $currentVersion). Skipping download.');
          return dataChanged ? 1 : 0; // Return 1 if JSON data changed, otherwise 0
        }
      } else {
        Logger.w('[TemplateManager] Update check response invalid or template inactive.');
      }
    } catch (e) {
      Logger.e('[TemplateManager] Error checking template updates: $e');
      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          return -1;
        }
        if (e.response?.statusCode == 403 ||
            (e.response?.data is Map && e.response?.data['error_code'] == 'DEMO_EXPIRED')) {
          return -3;
        }
      }
    } finally {
      _isUpdating = false;
    }
    return 0;
  }

  /// Public wrapper to download template from a specific URL and version
  static Future<void> downloadTemplateFromUrl(String url, String newVersion, {Function(double)? onProgress}) async {
    await _downloadAndExtractTemplate(url, newVersion, onProgress: onProgress);
  }

  /// Downloads the template ZIP, unzips it into the template directory, and deletes the ZIP file.
  static Future<void> _downloadAndExtractTemplate(String url, String newVersion, {Function(double)? onProgress}) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final tempZipPath = p.join(docDir.path, 'temp_template.zip');
      final tempExtractPath = p.join(docDir.path, 'temp_extract');
      
      Logger.i('[TemplateManager] Downloading zip from: $url');
      await _sharedDio.download(
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

      // Preserve offline media cache across template updates.
      // cached_media/ is NOT part of the template ZIP — it is device-local,
      // so wiping it would force every image to be re-downloaded.
      final cachedMediaDir = Directory(p.join(finalTemplateDir.path, 'cached_media'));
      Directory? preservedCache;
      if (await cachedMediaDir.exists()) {
        final preservePath = p.join(docDir.path, 'cached_media_preserve');
        final preserveDir = Directory(preservePath);
        try {
          if (await preserveDir.exists()) {
            await preserveDir.delete(recursive: true);
          }
          try {
            await cachedMediaDir.rename(preservePath);
          } catch (renameErr) {
            // Cross-device/lock rename can fail — fall back to copy so the
            // cache still survives the template directory wipe below.
            Logger.w('[TemplateManager] Preserve rename failed ($renameErr). Copying...');
            await _copyDirectory(cachedMediaDir, preserveDir);
          }
          preservedCache = preserveDir;
          Logger.i('[TemplateManager] Offline media cache preserved before template swap.');
        } catch (e) {
          Logger.w('[TemplateManager] Failed to preserve cached_media: $e');
          preservedCache = null;
        }
      }

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

      // Restore preserved offline media cache.
      if (preservedCache != null && await preservedCache.exists()) {
        final dest = Directory(p.join(finalTemplateDir.path, 'cached_media'));
        try {
          // ZIP may itself ship a cached_media/ dir — never let it shadow
          // (or cause loss of) the device-local cache we just preserved.
          if (await dest.exists()) {
            await dest.delete(recursive: true);
          }
          await preservedCache.rename(dest.path);
          Logger.i('[TemplateManager] Offline media cache restored after template swap.');
        } catch (e) {
          Logger.w('[TemplateManager] Rename restore failed ($e). Falling back to copy...');
          try {
            if (!await dest.exists()) {
              await _copyDirectory(preservedCache, dest);
            }
            await preservedCache.delete(recursive: true);
            Logger.i('[TemplateManager] Offline media cache restored (copy) after template swap.');
          } catch (e2) {
            // Keep the preserved copy on disk rather than deleting it —
            // a later run can still recover it, and images must not vanish.
            Logger.e('[TemplateManager] Could not restore cached_media: $e2');
          }
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

  /// Real device word clean karta hai — underscores/hyphens hatata hai, capitalize karta hai
  /// Koi static map nahi — jo real device ka naam hai wahi use hota hai
  /// Example: "sdk_google_atv64_arm64" → "Sdk Google Atv64 Arm64"
  ///          "mi_box_4k"              → "Mi Box 4k"
  ///          "SHIELD"                 → "Shield"
  static String _cleanDeviceWord(String raw) {
    if (raw.trim().isEmpty) return '';
    return raw
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ')
        .trim();
  }


  /// Downloads and extracts the template using details saved in local storage (e.g. after login)
  static Future<void> downloadTemplateFromSavedData({Function(double)? onProgress}) async {
    try {
      final loginData = SharedPrefs.getString(AppConstants.tvLoginDataKey);
      if (loginData == null || loginData.isEmpty) {
        Logger.w('[TemplateManager] No login data found to download template.');
        return;
      }

      dynamic decoded = jsonDecode(loginData);
      if (decoded is String) {
        decoded = jsonDecode(decoded);
      }
      final dataMap = decoded as Map<String, dynamic>;
      final innerData = dataMap['data'] as Map<String, dynamic>?;
      final templateData = ((innerData != null && innerData['template'] is Map)
          ? innerData['template']
          : (dataMap['template'] is Map ? dataMap['template'] : null)) as Map<String, dynamic>?;

      final String? latestVersion = templateData?['latest_version']?.toString();
      final String? downloadUrl = templateData?['download_url']?.toString();

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
