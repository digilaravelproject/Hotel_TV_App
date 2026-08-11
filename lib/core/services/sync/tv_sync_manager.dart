import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../storage/shared_prefs.dart';
import '../storage/token_manger.dart';
import '../template/template_manager_service.dart';
import '../../constants/app_constants.dart';
import '../../utils/logger.dart';

typedef OnSyncDataUpdated = void Function(int updateType);
typedef OnUnauthenticated = void Function();

class TvSyncManager {
  static StreamSubscription<DocumentSnapshot>? _firestoreSubscription;
  static Timer? _fallbackHttpTimer;
  
  static bool _isSyncing = false;

  /// Starts the Hybrid Real-Time System (Firestore Stream as primary + HTTP Polling as fallback)
  static Future<void> startHybridSync({
    required String hotelId,
    required String deviceId,
    required OnSyncDataUpdated onDataUpdated,
    required OnUnauthenticated onUnauthenticated,
  }) async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      Logger.e('[TvSyncManager] Firebase initialization error: $e');
    }

    _listenToFirestoreStream(
      hotelId: hotelId,
      deviceId: deviceId,
      onDataUpdated: onDataUpdated,
      onUnauthenticated: onUnauthenticated,
    );
  }

  /// -------------------------------------------------------------
  /// 🟢 PRIMARY MODE: FIREBASE FIRESTORE REAL-TIME STREAM
  /// -------------------------------------------------------------
  static void _listenToFirestoreStream({
    required String hotelId,
    required String deviceId,
    required OnSyncDataUpdated onDataUpdated,
    required OnUnauthenticated onUnauthenticated,
  }) {
    final String cleanHotelId = hotelId.startsWith('hotel_') ? hotelId.replaceFirst('hotel_', '') : hotelId;
    final String cleanDeviceId = deviceId.startsWith('device_') ? deviceId.replaceFirst('device_', '') : deviceId;

    final String collectionPath = "hotels/hotel_$cleanHotelId/rooms";
    final String docId = "device_$cleanDeviceId";

    print("==========================================================");
    print("🔥 [Firestore Sync] Initializing Stream Subscription...");
    print("📍 Collection: $collectionPath");
    print("📄 Document  : $docId");
    print("==========================================================");
    Logger.i('[TvSyncManager] ⚡ Listening to Firestore stream: $collectionPath/$docId');

    _firestoreSubscription?.cancel();

    _firestoreSubscription = FirebaseFirestore.instance
        .collection(collectionPath)
        .doc(docId)
        .snapshots()
        .listen(
      (DocumentSnapshot snapshot) async {
        if (snapshot.exists && snapshot.data() != null) {
          print("⚡ [Firestore Sync] SNAPSHOT UPDATED for $docId!");
          Logger.i('[TvSyncManager] 🔥 Firebase Live Stream update received!');

          // Stop HTTP Fallback if running since Firebase is active
          _stopHttpFallback();

          final Map<String, dynamic> rawMap = snapshot.data() as Map<String, dynamic>;

          // Extract and update auth token if available
          final authMap = rawMap['auth'] as Map<String, dynamic>?;
          final token = authMap?['token']?.toString();
          if (token != null && token.isNotEmpty) {
            await TokenManager.saveToken(token);
          }

          final updateType = await _processUpdatedJsonData(rawMap);
          print("✅ [Firestore Sync] Processed Update Type: $updateType (1=Data, 2=Template, 0=No Change)");
          onDataUpdated(updateType);
        } else {
          print("⚠️ [Firestore Sync] Document $docId not found in Firestore. Starting HTTP Fallback...");
          Logger.w('[TvSyncManager] Document $docId not found in Firestore. Starting HTTP Fallback...');
          _startHttpFallback(onDataUpdated: onDataUpdated, onUnauthenticated: onUnauthenticated);
        }
      },
      onError: (error) {
        print("❌ [Firestore Sync] STREAM ERROR / DISCONNECTED: $error");
        Logger.e('[TvSyncManager] ❌ Firebase Stream Disconnected/Failed: $error');
        _startHttpFallback(onDataUpdated: onDataUpdated, onUnauthenticated: onUnauthenticated);
      },
    );
  }

  /// -------------------------------------------------------------
  /// 🔴 FALLBACK MODE: PERIODIC HTTP POLLING (60 Seconds)
  /// -------------------------------------------------------------
  static void _startHttpFallback({
    required OnSyncDataUpdated onDataUpdated,
    required OnUnauthenticated onUnauthenticated,
  }) {
    if (_fallbackHttpTimer != null && _fallbackHttpTimer!.isActive) {
      return;
    }

    Logger.w('[TvSyncManager] 🔄 Switching to BACKUP MODE: HTTP Polling (Every 60s)...');

    // Run immediate check once
    _executeHttpPollingCheck(onDataUpdated, onUnauthenticated);

    // Schedule timer every 60 seconds
    _fallbackHttpTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _executeHttpPollingCheck(onDataUpdated, onUnauthenticated);
    });
  }

  static Future<void> _executeHttpPollingCheck(
    OnSyncDataUpdated onDataUpdated,
    OnUnauthenticated onUnauthenticated,
  ) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      Logger.i('[TvSyncManager] [HTTP Fallback] Executing silent HTTP update check...');
      final int updateType = await TemplateManagerService.checkAndUpdateTemplateSilent();

      if (updateType == -1) {
        Logger.w('[TvSyncManager] Token unauthenticated! Triggering logout callback.');
        onUnauthenticated();
      } else {
        onDataUpdated(updateType);
      }
    } catch (e) {
      Logger.e('[TvSyncManager] [HTTP Fallback] Exception: $e');
    } finally {
      _isSyncing = false;
    }
  }

  static void _stopHttpFallback() {
    if (_fallbackHttpTimer != null) {
      Logger.i('[TvSyncManager] 🟢 Firebase Stream active! Disabling HTTP backup polling.');
      _fallbackHttpTimer?.cancel();
      _fallbackHttpTimer = null;
    }
  }

  /// -------------------------------------------------------------
  /// 🛠️ COMMON DATA PROCESSING & TEMPLATE VERSION CHECK
  /// -------------------------------------------------------------
  static Future<int> _processUpdatedJsonData(Map<String, dynamic> firestoreMap) async {
    try {
      final Map<String, dynamic> normalizedPayload;
      if (firestoreMap.containsKey('data') && firestoreMap['data'] is Map) {
        final innerMap = Map<String, dynamic>.from(firestoreMap['data'] as Map);
        normalizedPayload = {
          'status': firestoreMap['status'] ?? true,
          'message': firestoreMap['message'] ?? 'Realtime stream update fetched successfully.',
          'data': innerMap,
        };
      } else {
        normalizedPayload = {
          'status': true,
          'message': 'Realtime stream update fetched successfully.',
          'data': firestoreMap,
        };
      }

      final oldDataStr = SharedPrefs.getString(AppConstants.tvLoginDataKey);
      final newDataStr = jsonEncode(normalizedPayload);
      final bool dataChanged = oldDataStr != newDataStr;

      await SharedPrefs.setString(AppConstants.tvLoginDataKey, newDataStr);
      await TemplateManagerService.regenerateDataJson();

      final dataContent = (normalizedPayload['data'] as Map<String, dynamic>?) ?? normalizedPayload;
      final templateMap = dataContent['template'] as Map<String, dynamic>?;
      final String? latestVersion = templateMap?['latest_version']?.toString();
      final String? templateId = templateMap?['template_id']?.toString();
      final String? downloadUrl = templateMap?['download_url']?.toString();

      if (latestVersion != null && downloadUrl != null && downloadUrl.isNotEmpty) {
        final currentVersion = SharedPrefs.getString(AppConstants.templateVersionKey) ?? '0.0';
        final currentTemplateId = SharedPrefs.getString('template_id') ?? '';

        double currentVal = double.tryParse(currentVersion) ?? 0.0;
        double latestVal = double.tryParse(latestVersion) ?? 0.0;

        bool templateIdChanged = templateId != null && templateId != currentTemplateId;
        bool versionChanged = latestVal > currentVal;
        bool isMissing = !await TemplateManagerService.isTemplateDownloaded();

        if (templateIdChanged || versionChanged || isMissing) {
          Logger.i('[TvSyncManager] Template Update Triggered (IdChanged: $templateIdChanged, VersionChanged: $versionChanged, Missing: $isMissing). Downloading ZIP...');
          await TemplateManagerService.downloadTemplateFromUrl(downloadUrl, latestVersion);
          if (templateId != null) {
            await SharedPrefs.setString('template_id', templateId);
          }
          return 2; // Template Updated
        }
      }

      return dataChanged ? 1 : 0;
    } catch (e) {
      Logger.e('[TvSyncManager] Error processing Firestore update: $e');
      return 0;
    }
  }

  /// Stop all sync listeners (Call during logout / dispose)
  static Future<void> dispose() async {
    await _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
    _stopHttpFallback();
  }
}
