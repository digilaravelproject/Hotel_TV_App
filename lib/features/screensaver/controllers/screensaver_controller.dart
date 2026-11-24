import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage/shared_prefs.dart';
import '../../../core/services/template/template_manager_service.dart';
import '../../../core/utils/logger.dart';

class ScreensaverController extends ChangeNotifier {
  Timer? _inactivityTimer;
  Timer? _clockTimer;

  bool _isScreensaverVisible = false;
  int _wallpaperIndex = 0;
  String _timeStr = '';
  String _temperatureStr = '29°';

  List<File> _cachedWallpaperFiles = [];
  List<String> _networkWallpaperUrls = [];
  String? _fallbackBgFilePath;

  bool get isVisible => _isScreensaverVisible;
  int get wallpaperIndex => _wallpaperIndex;
  String get timeStr => _timeStr;
  String get temperatureStr => _temperatureStr;
  List<File> get cachedWallpaperFiles => _cachedWallpaperFiles;
  List<String> get networkWallpaperUrls => _networkWallpaperUrls;
  String? get fallbackBgFilePath => _fallbackBgFilePath;

  void initialize() {
    _updateTime();
    _loadTemperature();
    _loadWallpapers();
    _startInactivityTimer();
    _startClockTimer();
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(AppConstants.screensaverInactivityDuration, () {
      showScreensaver();
    });
  }

  void resetInactivityTimer() {
    _startInactivityTimer();
    if (_isScreensaverVisible) {
      dismissScreensaver();
    }
  }

  void showScreensaver() {
    if (!_isScreensaverVisible) {
      _isScreensaverVisible = true;
      _updateTime();
      notifyListeners();
    }
  }

  void dismissScreensaver() {
    if (_isScreensaverVisible) {
      _isScreensaverVisible = false;
      notifyListeners();
    }
  }

  void _startClockTimer() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateTime();
      final totalWallpapers = _cachedWallpaperFiles.length + _networkWallpaperUrls.length;
      if (_isScreensaverVisible && totalWallpapers > 0) {
        _wallpaperIndex = (_wallpaperIndex + 1) % totalWallpapers;
      }
      notifyListeners();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    _timeStr = '$h:$m';
  }

  void _loadTemperature() {
    try {
      final rawData = SharedPrefs.getString(AppConstants.tvLoginDataKey);
      if (rawData != null && rawData.isNotEmpty) {
        final decoded = jsonDecode(rawData);
        final dataMap = decoded['data'] ?? decoded;
        final weather = dataMap['weather'] ?? dataMap['hotel']?['weather'] ?? dataMap['device']?['weather'];
        if (weather is Map) {
          final tempC = weather['temp_c'] ?? weather['temp'] ?? weather['temperature'] ?? weather['celsius'];
          if (tempC != null && tempC.toString().trim().isNotEmpty) {
            final clean = tempC.toString().replaceAll('°C', '').replaceAll('°', '').trim();
            _temperatureStr = '$clean°';
            return;
          }
        } else if (weather != null && weather.toString().trim().isNotEmpty) {
          final match = RegExp(r'(\d+)\s*°?\s*C?').firstMatch(weather.toString());
          if (match != null) {
            _temperatureStr = '${match.group(1)}°';
            return;
          }
        }
      }
    } catch (_) {}
    _temperatureStr = '29°';
  }

  Future<void> _loadWallpapers() async {
    try {
      final List<File> files = [];
      final List<String> urls = [];

      final dir = await TemplateManagerService.getTemplateDirectory();
      final rawData = SharedPrefs.getString(AppConstants.tvLoginDataKey);

      void addCandidate(dynamic raw) {
        if (raw == null) return;
        final urlStr = raw.toString().trim();
        if (urlStr.isEmpty) return;

        if (urlStr.startsWith('cached_media/')) {
          final f = File('${dir.path}/$urlStr');
          if (f.existsSync() && !files.any((e) => e.path == f.path)) {
            files.add(f);
            return;
          }
        }

        final uri = Uri.tryParse(urlStr);
        final fileName = uri != null && uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
        if (fileName.isNotEmpty) {
          final localF = File('${dir.path}/cached_media/$fileName');
          if (localF.existsSync() && !files.any((e) => e.path == localF.path)) {
            files.add(localF);
            return;
          }
        }

        if (urlStr.startsWith('http://') || urlStr.startsWith('https://')) {
          if (!urls.contains(urlStr)) {
            urls.add(urlStr);
          }
        }
      }

      if (rawData != null && rawData.isNotEmpty) {
        final decoded = jsonDecode(rawData);
        final dataMap = decoded['data'] is Map ? decoded['data'] as Map : (decoded is Map ? decoded : {});

        final hotelMap = dataMap['hotel'] is Map ? dataMap['hotel'] as Map : null;
        final mediaMap = hotelMap?['media'] is Map ? hotelMap!['media'] as Map : null;
        if (mediaMap != null) {
          addCandidate(mediaMap['cover_image']);
          final sliders = mediaMap['slider_images'];
          if (sliders is List) {
            for (final s in sliders) {
              addCandidate(s);
            }
          }
        }

        final facilities = dataMap['facilities'] ?? dataMap['hotel_gallery'];
        if (facilities is List) {
          for (final f in facilities) {
            if (f is Map) addCandidate(f['image_url'] ?? f['image']);
          }
        }

        final roomInfoList = dataMap['room_info'] ?? dataMap['rooms'];
        if (roomInfoList is List) {
          for (final r in roomInfoList) {
            if (r is Map) addCandidate(r['image_url'] ?? r['image'] ?? r['photo']);
          }
        }

        final amenitiesList = dataMap['amenities'] ?? hotelMap?['amenities'];
        if (amenitiesList is List) {
          for (final a in amenitiesList) {
            if (a is Map) addCandidate(a['image_url'] ?? a['image'] ?? a['img']);
          }
        }

        final cityList = dataMap['our_city'] ?? dataMap['city_info'];
        if (cityList is List) {
          for (final c in cityList) {
            if (c is Map) addCandidate(c['image_url'] ?? c['image']);
          }
        }
      }

      // Check fallback template bgImage
      final candidates = ['bgImage.png', 'bg.jpg', 'bg.png', 'background.jpg', 'background.png', 'assets/bgImage.png', 'assets/bg.jpg'];
      for (final name in candidates) {
        final f = File('${dir.path}/$name');
        if (await f.exists()) {
          _fallbackBgFilePath = f.path;
          break;
        }
      }

      _cachedWallpaperFiles = files;
      _networkWallpaperUrls = urls;
      notifyListeners();
    } catch (e) {
      Logger.w('[ScreensaverController] Error loading wallpapers: $e');
    }
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }
}
