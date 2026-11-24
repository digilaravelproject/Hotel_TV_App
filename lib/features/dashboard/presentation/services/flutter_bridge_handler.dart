import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/services/storage/shared_prefs.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/device/device_info_service.dart';
import '../../../../core/services/template/template_manager_service.dart';

class FlutterBridgeHandler {
  final WebViewController controller;
  final MethodChannel _tvChannel;
  final void Function(String view)? onViewChanged;
  StreamSubscription? _connectivitySub;

  static DateTime? _lastHdmiLaunchTime;

  FlutterBridgeHandler(this.controller, {this.onViewChanged})
      : _tvChannel = const MethodChannel('com.paxtv.hospitality/tv_control');

  void dispose() {
    _connectivitySub?.cancel();
  }

  Future<void> handleMessage(String rawMessage) async {
    try {
      print('[WebToFlutter] Received Message: $rawMessage');
      final call = jsonDecode(rawMessage) as Map<String, dynamic>;
      final method = call['method'] as String?;
      final args = call['args'] as List<dynamic>?;
      final id = call['id'] as int?;

      if (method == null || id == null) {
        print('[WebToFlutter] Invalid message format (missing method or id)');
        return;
      }

      print('[WebToFlutter] Dispatching: method=$method, args=$args, id=$id');
      dynamic result;
      try {
        result = await _dispatch(method, args ?? []);
      } catch (e) {
        print('[WebToFlutter] Error in method $method: $e');
        await _reject(id, e.toString());
        return;
      }

      print('[WebToFlutter] Resolved: method=$method, result=$result');
      await _resolve(id, result);
    } catch (e) {
      print('[WebToFlutter] Exception parsing message: $e');
    }
  }

  Future<dynamic> _dispatch(String method, List<dynamic> args) async {
    switch (method) {
      case 'onViewChanged':
      case 'viewChanged':
        if (args.isNotEmpty) {
          final view = args[0]?.toString() ?? 'home';
          onViewChanged?.call(view);
        }
        return true;

      case 'getInstalledApps':
      case 'getApps':
      case 'getAppList':
        List installedAppsRaw = [];
        try {
          installedAppsRaw = await _tvChannel.invokeMethod<List>('getInstalledApps') ?? [];
        } catch (_) {}
        final List<Map<String, dynamic>> installedApps = installedAppsRaw
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        List<Map<String, dynamic>> activeOttList = [];
        try {
          final rawLoginData = SharedPrefs.getString(AppConstants.tvLoginDataKey);
          if (rawLoginData != null && rawLoginData.isNotEmpty) {
            final dynamic decoded = jsonDecode(rawLoginData);
            final dataMap = decoded is Map && decoded['data'] is Map ? decoded['data'] as Map : (decoded is Map ? decoded : {});
            if (dataMap['active_ott'] is List) {
              final list = dataMap['active_ott'] as List;
              activeOttList = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            }
          }
        } catch (_) {}

        if (activeOttList.isEmpty) {
          // Smart Hybrid Fallback: When admin has not yet configured active_ott for this hotel,
          // display all valid user-facing installed apps (excluding our own app and system core)
          final List<Map<String, dynamic>> fallbackApps = [];
          for (var app in installedApps) {
            final pkg = (app['package'] ?? app['packageName'] ?? '').toString();
            final name = (app['name'] ?? app['appName'] ?? '').toString();
            if (pkg.isEmpty) continue;
            if (pkg == 'com.paxtv.hospitality' || pkg == 'android' || pkg == 'com.android.settings') continue;

            fallbackApps.add({
              'name': name.isNotEmpty ? name : pkg,
              'label': name.isNotEmpty ? name : pkg,
              'package': pkg,
              'packageName': pkg,
              'package_name': pkg,
              'id': pkg,
              'icon': app['icon'] ?? app['appIcon'] ?? '',
            });
          }
          return fallbackApps;
        }

        // Return ONLY apps from active_ott that are physically INSTALLED on the TV device
        final List<Map<String, dynamic>> resultApps = [];
        final Map<String, List<String>> knownOttPackages = {
          'netflix': ['com.netflix.ninja', 'com.netflix.mediaclient'],
          'prime': ['com.amazon.amazonvideo.livingroom', 'com.amazon.avod.thirdpartyclient'],
          'amazon prime video': ['com.amazon.amazonvideo.livingroom', 'com.amazon.avod.thirdpartyclient'],
          'youtube': ['com.google.android.youtube.tv', 'com.google.android.youtube'],
          'hotstar': ['in.startv.hotstar'],
          'disney+ hotstar': ['in.startv.hotstar'],
          'zee5': ['com.graymatrix.did'],
          'sonyliv': ['com.sonyliv'],
          'sony liv': ['com.sonyliv'],
          'jiocinema': ['com.jio.media.ondemand'],
          'jio cinema': ['com.jio.media.ondemand'],
          'aha': ['com.aha.android'],
          'sun nxt': ['com.suntv.sunnxt'],
          'sunnxt': ['com.suntv.sunnxt'],
          'mx player': ['com.mxtech.videoplayer.ad', 'com.mxtech.videoplayer.pro'],
          'playstore': ['com.android.vending'],
          'google play store': ['com.android.vending'],
        };

        for (var ott in activeOttList) {
          final String ottPackage = ott['package_name']?.toString() ?? ott['package']?.toString() ?? ott['packageName']?.toString() ?? '';
          final String ottId = ott['id']?.toString().toLowerCase() ?? '';
          final String ottName = ott['name']?.toString() ?? ottId;

          if (ottPackage.isEmpty && ottId.isEmpty) continue;

          final knownCandidates = (knownOttPackages[ottId] ?? knownOttPackages[ottName.toLowerCase()] ?? [])
              .map((e) => e.toLowerCase())
              .toList();

          final matchingInstalled = installedApps.firstWhere(
            (app) {
              final pkg = (app['package'] ?? app['packageName'] ?? '').toString().toLowerCase();
              final target = ottPackage.toLowerCase();
              final name = ottName.toLowerCase();
              final appDisplayName = (app['name'] ?? app['appName'] ?? '').toString().toLowerCase();
              if (pkg.isEmpty) return false;

              // 1. Exact package match
              if (target.isNotEmpty && pkg == target) return true;

              // 2. Known TV / Mobile package alias match (e.g. com.netflix.ninja vs com.netflix.mediaclient)
              if (knownCandidates.isNotEmpty && knownCandidates.contains(pkg)) return true;

              // 3. Exact Display Name match
              if (name.isNotEmpty && appDisplayName.isNotEmpty && appDisplayName == name) return true;

              // 4. Strict package prefix match (only if target is a full qualified package)
              if (target.contains('.') && target.length >= 10 && pkg == target) return true;

              return false;
            },
            orElse: () => {},
          );

          if (matchingInstalled.isNotEmpty) {
            resultApps.add({
              'name': ott['name'] ?? matchingInstalled['name'] ?? matchingInstalled['appName'] ?? ottName,
              'label': ott['name'] ?? matchingInstalled['name'] ?? matchingInstalled['appName'] ?? ottName,
              'package': matchingInstalled['package'] ?? matchingInstalled['packageName'] ?? ottPackage,
              'packageName': matchingInstalled['package'] ?? matchingInstalled['packageName'] ?? ottPackage,
              'package_name': matchingInstalled['package'] ?? matchingInstalled['packageName'] ?? ottPackage,
              'id': ott['id'] ?? matchingInstalled['package'] ?? matchingInstalled['packageName'] ?? ottId,
              'icon': (matchingInstalled['icon'] != null && matchingInstalled['icon'].toString().isNotEmpty)
                  ? matchingInstalled['icon']
                  : (ott['icon'] ?? ott['logo'] ?? ''),
            });
          }
        }

        return resultApps;

      case 'launchApp':
        final package = args.isNotEmpty ? args[0] as String? : null;
        if (package == null) return {'success': false, 'message': 'package is required'};
        try {
          await _tvChannel.invokeMethod('launchApp', {'package': package});
        } catch (_) {}
        return {'success': true};

      case 'openSettings':
      case 'openAndroidSettings':
        try {
          await _tvChannel.invokeMethod('openSettings');
        } catch (_) {}
        return {'success': true};

      case 'refreshApp':
      case 'refreshData':
      case 'reloadWebView':
      case 'reloadPage':
      case 'refreshAllData':
      case 'refreshAll':
        try {
          print('[FlutterBridge] Refresh requested! Calling backend API...');
          await TemplateManagerService.checkAndUpdateTemplateSilent();
          await TemplateManagerService.regenerateDataJson();
          final raw = SharedPrefs.getString(AppConstants.tvLoginDataKey);
          if (raw != null && raw.isNotEmpty) {
            final b64 = base64Encode(utf8.encode(raw));
            await controller.runJavaScript('''
              (function() {
                try {
                  delete window.tvLoginData;
                  localStorage.removeItem('cachedHotelData');
                  window.tvLoginData = JSON.parse(atob('$b64'));
                  var normalized = window.tvLoginData.data || window.tvLoginData;
                  localStorage.setItem('cachedHotelData', JSON.stringify(normalized));
                } catch(e) {}
              })();
            ''');
          }
        } catch (e) {
          print('[FlutterBridge] Error during refresh API check: $e');
        }
        try {
          await controller.clearCache();
        } catch (_) {}
        await controller.reload();
        print('[FlutterBridge] WebView reloaded successfully with fresh data.');
        return {'success': true};

      case 'launchCast':
      case 'openCast':
      case 'startCast':
        await _tvChannel.invokeMethod('launchCast');
        return {'success': true};

      case 'identifyDevice':
      case 'getSystemInfo':
        final info = await DeviceInfoService.getFullDeviceInfo(forceRefresh: true);
        final ip = info['ipAddress']?.toString() ?? '';
        final gateway = info['gateway']?.toString() ?? '';
        final subnet = info['subnet']?.toString() ?? '';
        final dns = info['dns']?.toString() ?? '';

        String roomNo = SharedPrefs.getString('saved_room_no') ?? '';
        String hotelName = '';
        String apiModel = '';
        String apiBrand = '';
        try {
          final loginDataStr = SharedPrefs.getString(AppConstants.tvLoginDataKey);
          if (loginDataStr != null && loginDataStr.isNotEmpty) {
            final dynamic decoded = jsonDecode(loginDataStr);
            final dataMap = decoded is Map && decoded['data'] is Map ? decoded['data'] as Map : (decoded is Map ? decoded : {});
            if (dataMap['device'] is Map) {
              final devMap = dataMap['device'] as Map;
              if (roomNo.isEmpty) roomNo = devMap['room_no']?.toString() ?? '';
              apiModel = devMap['model']?.toString() ?? '';
              apiBrand = devMap['brand']?.toString() ?? '';
            } else if (dataMap['room_no'] != null && roomNo.isEmpty) {
              roomNo = dataMap['room_no'].toString();
            }
            if (dataMap['hotel'] is Map) {
              hotelName = dataMap['hotel']['hotel_name']?.toString() ?? '';
            }
          }
        } catch (_) {}

        final String brand = info['brand']?.toString().isNotEmpty == true ? info['brand'].toString() : apiBrand;
        final String model = info['model']?.toString().isNotEmpty == true ? info['model'].toString() : apiModel;

        String deviceName = '';
        if (roomNo.isNotEmpty) {
          deviceName = 'Hotel TV (Room $roomNo)';
        } else if (hotelName.isNotEmpty) {
          deviceName = hotelName;
        } else if (brand.isNotEmpty || model.isNotEmpty) {
          deviceName = '$brand $model'.trim();
        } else {
          deviceName = 'Hotel TV';
        }

        final List<String> tvInputs = (info['tv_inputs'] is List)
            ? (info['tv_inputs'] as List).map((e) => e.toString()).toList()
            : [];

        final deviceMap = {
          'device_id': info['deviceId'] ?? '',
          'mac_address': info['macAddress'] ?? '',
          'ip_address': ip,
          'gateway': gateway,
          'subnet_mask': subnet,
          'subnet': subnet,
          'dns': dns,
          'DNS': dns,
          'model': model,
          'brand': brand,
          'os_version': info['osVersion'] ?? '',
          'deviceId': info['deviceId'] ?? '',
          'macAddress': info['macAddress'] ?? '',
          'ipAddress': ip,
          'osVersion': info['osVersion'] ?? '',
          'serial': info['serial'] ?? info['deviceId'] ?? '',
          'ip': ip,
          'room': roomNo,
          'room_no': roomNo,
          'hotel_name': hotelName,
          'hotelName': hotelName,
          'device_name': deviceName,
          'deviceName': deviceName,
          'name': deviceName,
          'availableTvPorts': tvInputs,
          'available_tv_ports': tvInputs,
          'ports': tvInputs,
          'availablePorts': tvInputs,
        };
        return {
          'status': true,
          'success': true,
          'data': deviceMap,
          'device': deviceMap,
          ...deviceMap,
        };

      case 'savePortPreference':
      case 'saveLiveTvPort':
      case 'saveTvInputPort':
        if (args.isNotEmpty && args[0] != null) {
          final port = args[0].toString();
          await SharedPrefs.setString('selectedLiveTvPort', port);
          print('[FlutterBridge] Saved Live TV port preference: $port');
          await TemplateManagerService.regenerateDataJson();
        }
        return {'success': true};

      case 'getSelectedLiveTvPort':
      case 'getSavedPortPreference':
        final saved = SharedPrefs.getString('selectedLiveTvPort');
        List<Map<String, dynamic>> inputsList = [];
        try {
          final dynamic inputsRes = await _tvChannel.invokeMethod('getLiveTvInputs');
          if (inputsRes is List) {
            inputsList = inputsRes.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } catch (_) {}

        Map<String, dynamic>? matched;
        if (saved != null && saved.isNotEmpty && saved != 'null') {
          matched = inputsList.firstWhere(
            (item) {
              final id = item['id']?.toString() ?? '';
              final model = item['model']?.toString() ?? '';
              final label = item['label']?.toString() ?? '';
              return id == saved || model == saved || label == saved;
            },
            orElse: () => <String, dynamic>{},
          );
        }
        if ((matched == null || matched.isEmpty) && inputsList.isNotEmpty) {
          matched = inputsList.first;
        }

        final selectedId = matched != null && matched.isNotEmpty
            ? (matched['id']?.toString() ?? matched['model']?.toString() ?? '')
            : (saved ?? '');
        final cleanLabel = matched != null && matched.isNotEmpty
            ? (matched['label']?.toString() ?? matched['name']?.toString() ?? selectedId)
            : selectedId;

        return {
          'selectedPort': selectedId,
          'port': selectedId,
          'id': selectedId,
          'label': cleanLabel,
          'name': cleanLabel,
        };

      case 'launchTvInput':
      case 'launchTVInput':
      case 'switchTvInput':
      case 'launchLiveTv':
      case 'openLiveTv':
      case 'launchLiveTV':
      case 'launchHdmi':
        final now = DateTime.now();
        if (_lastHdmiLaunchTime != null && now.difference(_lastHdmiLaunchTime!).inMilliseconds < 1500) {
          print('[FlutterBridge] Suppressing duplicate launchLiveTv/launchHdmi call within 1.5s');
          return {'success': true, 'suppressed': true};
        }
        _lastHdmiLaunchTime = now;

        String? model;
        if (args.isNotEmpty && args[0] != null) {
          if (args[0] is Map) {
             model = args[0]['model']?.toString() ?? args[0]['id']?.toString() ?? args[0]['port']?.toString();
          } else {
             model = args[0].toString().trim();
          }
        }
        if (model == 'null' || (model != null && model.isEmpty)) {
           model = null;
        }
        String checkedSource = model != null ? 'argument' : '';

        final methodLower = method.toLowerCase();
        final bool isExplicitLiveTv = methodLower == 'launchlivetv' || methodLower == 'openlivetv';

        if (isExplicitLiveTv || (model != null && (model.toLowerCase() == 'livetv' || model.toLowerCase() == 'live' || model.toLowerCase().contains('dish')))) {
          print('[FlutterBridge] Live TV requested ($method / $model) -> launching DishTV Live');
          try {
            await _tvChannel.invokeMethod('launchLiveTv');
            return {
              'success': true,
              'port': 'LiveTV',
              'checkedPort': 'LiveTV',
              'source': 'dish_live_tv',
              'message': 'DishTV Live TV launched successfully'
            };
          } catch (e) {
            print('[FlutterBridge] Error launching Live TV via channel: $e');
          }
        }

        if (model == null || model.isEmpty || model == 'null') {
          model = SharedPrefs.getString('selectedLiveTvPort');
          if (model != null && model.isNotEmpty && model != 'null') {
            checkedSource = 'saved_preference ($model)';
          }
        }

        if (model == null || model.isEmpty || model == 'null') {
          try {
            final rawConfig = SharedPrefs.getString(AppConstants.tvLoginDataKey);
            if (rawConfig != null && rawConfig.isNotEmpty) {
              final decoded = jsonDecode(rawConfig);
              if (decoded is Map) {
                final dMap = decoded['data'] is Map ? decoded['data'] as Map : decoded;
                model = dMap['selectedLiveTvPort']?.toString() ??
                        dMap['liveTvPort']?.toString() ??
                        dMap['package']?.toString() ??
                        (dMap['device'] is Map ? dMap['device']['tvInputPort']?.toString() : null);
                if (model != null && model.isNotEmpty && model != 'null') {
                  checkedSource = 'saved_config ($model)';
                }
              }
            }
          } catch (_) {}
        }

        if (model == null || model.isEmpty || model == 'null') {
          try {
            final dynamic inputsRes = await _tvChannel.invokeMethod('getLiveTvInputs');
            checkedSource = 'getLiveTvInputs';
            if (inputsRes is List && inputsRes.isNotEmpty) {
              final firstMap = Map<String, dynamic>.from(inputsRes.first as Map);
              model = firstMap['id']?.toString() ?? firstMap['model']?.toString();
            } else {
              checkedSource = 'getHdmiModels';
              final dynamic allInputs = await _tvChannel.invokeMethod('getHdmiModels');
              if (allInputs is List && allInputs.isNotEmpty) {
                final firstMap = Map<String, dynamic>.from(allInputs.first as Map);
                model = firstMap['id']?.toString() ?? firstMap['model']?.toString();
              }
            }
          } catch (_) {}
        }

        if (model == null || model.isEmpty || model == 'null') {
          model = 'HDMI 1';
          checkedSource = 'default_hdmi1_fallback';
        }
        final bool isTvInput = model.contains('/') ||
            model.toLowerCase().contains('tvinput') ||
            model.toLowerCase().contains('inputservice') ||
            model.toUpperCase().startsWith('HDMI') ||
            model.toUpperCase().startsWith('AV') ||
            model.toUpperCase().startsWith('TUNER') ||
            model.toUpperCase().startsWith('HW') ||
            !model.contains('.');

        try {
          if (model.toUpperCase() == 'IPTV') {
            print('[FlutterBridge] Launching IPTV (source: $checkedSource)');
            await _tvChannel.invokeMethod('launchIptv');
          } else if (isTvInput) {
            print('[FlutterBridge] Launching Live TV input port: $model (source: $checkedSource)');
            await _tvChannel.invokeMethod('launchHdmi', {'model': model});
          } else {
            // Standalone Android package name (e.g. "com.netflix.ninja")
            print('[FlutterBridge] Launching TV APP: $model (source: $checkedSource)');
            await _tvChannel.invokeMethod('launchApp', {'package': model, 'packageName': model});
          }
        } catch (e) {
          print('[FlutterBridge] Error in launchLiveTv/launchHdmi: $e');
        }
        return {
          'success': true,
          'port': model,
          'checkedPort': model,
          'source': checkedSource,
          'message': 'Checked and launched Live TV: $model'
        };

      case 'checkInternet':
        final result = await Connectivity().checkConnectivity();
        final isOnline = result.contains(ConnectivityResult.mobile) ||
            result.contains(ConnectivityResult.wifi) ||
            result.contains(ConnectivityResult.ethernet);
        return isOnline;

      case 'clearConfig':
        await _tvChannel.invokeMethod('clearConfig');
        return {'success': true};

      case 'getDeviceConfig':
        return SharedPrefs.getString(AppConstants.tvLoginDataKey) ?? '{}';

      case 'saveDeviceConfig':
      case 'saveRoomConfig':
      case 'saveConfiguration':
        if (args.isNotEmpty && args[0] != null) {
          final rawVal = args[0];
          try {
            final Map<String, dynamic> newMap = rawVal is String
                ? jsonDecode(rawVal) as Map<String, dynamic>
                : Map<String, dynamic>.from(rawVal as Map);

            final existingStr = SharedPrefs.getString(AppConstants.tvLoginDataKey);
            Map<String, dynamic> existingMap = {};
            if (existingStr != null && existingStr.isNotEmpty) {
              try {
                existingMap = jsonDecode(existingStr) as Map<String, dynamic>;
              } catch (_) {}
            }

            if (existingMap.isNotEmpty) {
              if (existingMap['data'] is Map) {
                final innerData = Map<String, dynamic>.from(existingMap['data'] as Map);
                newMap.forEach((k, v) {
                  if (k == 'room_no' || k == 'room') {
                    if (innerData['device'] is Map) {
                      final devMap = Map<String, dynamic>.from(innerData['device'] as Map);
                      devMap['room_no'] = v.toString();
                      innerData['device'] = devMap;
                    }
                    innerData['room_no'] = v.toString();
                  } else {
                    innerData[k] = v;
                  }
                });
                existingMap['data'] = innerData;
              } else {
                newMap.forEach((k, v) => existingMap[k] = v);
              }
              await SharedPrefs.setString(AppConstants.tvLoginDataKey, jsonEncode(existingMap));
            } else {
              await SharedPrefs.setString(AppConstants.tvLoginDataKey, jsonEncode(newMap));
            }

            final roomNo = newMap['room_no'] ?? newMap['room'] ?? (newMap['device'] is Map ? newMap['device']['room_no'] : null);
            if (roomNo != null && roomNo.toString().isNotEmpty) {
              await SharedPrefs.setString('saved_room_no', roomNo.toString());
            }

            final portVal = newMap['selectedLiveTvPort'] ??
                            newMap['selectedPort'] ??
                            newMap['package'] ??
                            newMap['tvInputPort'] ??
                            newMap['liveTvPort'];
            if (portVal != null && portVal.toString().isNotEmpty && portVal.toString() != 'null') {
              await SharedPrefs.setString('selectedLiveTvPort', portVal.toString());
              print('[FlutterBridge] Saved selectedLiveTvPort from saveDeviceConfig: $portVal');
            }

            await TemplateManagerService.regenerateDataJson();
          } catch (e) {
            print('[FlutterBridge] Error merging saveConfiguration: $e');
            final String configStr = rawVal is String ? rawVal : jsonEncode(rawVal);
            await SharedPrefs.setString(AppConstants.tvLoginDataKey, configStr);
          }
        }
        return {'success': true};

      case 'getHdmiModels':
      case 'getTvInputs':
      case 'getLiveTvInputs':
        try {
          final dynamic res = await _tvChannel.invokeMethod('getHdmiModels');
          if (res != null) {
            List<Map<String, dynamic>> allList = [];
            if (res is List) {
              allList = res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            } else if (res is Map) {
              res.forEach((key, val) {
                allList.add({
                  'name': key.toString(),
                  'label': key.toString(),
                  'id': val.toString(),
                  'value': val.toString(),
                  'model': val.toString(),
                  'type': 'HDMI',
                });
              });
            }
            // Strict HDMI Filter: Exclude AV, Tuner, TV, Composite, Component, DisplayPort
            final hdmiOnly = allList.where((p) {
              final name = (p['name'] ?? p['label'] ?? p['id'] ?? '').toString().toUpperCase();
              final portName = (p['portName'] ?? '').toString().toUpperCase();
              final type = (p['type'] ?? '').toString().toUpperCase();
              return (name.contains('HDMI') || portName.contains('HDMI') || type == 'HDMI') &&
                     !name.contains('AV') &&
                     !name.contains('TUNER') &&
                     !name.contains('TV (TUNER)') &&
                     !name.contains('COMPOSITE') &&
                     !name.contains('COMPONENT');
            }).toList();

            return hdmiOnly;
          }
        } catch (e) {
          print('[FlutterBridge] Error fetching HDMI models: $e');
        }

        return [];

      case 'setLanguage':
      case 'changeLanguage':
      case 'selectLanguage':
        if (args.isNotEmpty && args[0] != null) {
          final lang = args[0].toString();
          final langFile = lang.endsWith('.json') ? lang : '$lang.json';
          await SharedPrefs.setString('selectedLangFile', langFile);
          await SharedPrefs.setString('selectedLangCode', lang.replaceAll('.json', ''));
        }
        return {'success': true};

      case 'getLanguages':
      case 'getLanguageList':
        return [
          {'name': 'English', 'code': 'english', 'file': 'english.json'},
          {'name': 'Hindi', 'code': 'hindi', 'file': 'hindi.json'},
          {'name': 'Arabic', 'code': 'arabic', 'file': 'arabic.json'},
          {'name': 'Spanish', 'code': 'spanish', 'file': 'spanish.json'},
          {'name': 'French', 'code': 'french', 'file': 'french.json'},
          {'name': 'German', 'code': 'german', 'file': 'german.json'},
          {'name': 'Russian', 'code': 'russian', 'file': 'russian.json'},
          {'name': 'Chinese', 'code': 'chinese', 'file': 'chinese.json'},
          {'name': 'Gujarati', 'code': 'gujrati', 'file': 'gujrati.json'},
          {'name': 'Marathi', 'code': 'marathi', 'file': 'marathi.json'},
          {'name': 'Bengali', 'code': 'bengali', 'file': 'bengali.json'},
          {'name': 'Tamil', 'code': 'tamil', 'file': 'tamil.json'},
          {'name': 'Telugu', 'code': 'telugu', 'file': 'telugu.json'},
          {'name': 'Kannada', 'code': 'kannada', 'file': 'kannada.json'},
          {'name': 'Malayalam', 'code': 'malayalam', 'file': 'malayalam.json'},
          {'name': 'Punjabi', 'code': 'punjabi', 'file': 'punjabi.json'},
          {'name': 'Urdu', 'code': 'urdu', 'file': 'urdu.json'},
        ];

      case 'launchIptv':
        final package = args.isNotEmpty ? args[0] as String? : null;
        if (package == null) return {'success': false, 'message': 'package is required'};
        try {
          await _tvChannel.invokeMethod('launchApp', {'package': package});
        } catch (_) {}
        return {'success': true};

      case 'getPictureList':
        return [];

      case 'syncFlights':
      case 'syncWeather':
      case 'getFlightData':
      case 'getFlights':
        return [];

      default:
        return {'status': false, 'message': 'Method $method not implemented'};
    }
  }

  Future<void> _resolve(int id, dynamic result) async {
    await controller.runJavaScript(
      'window.flutterBridge._resolve($id, ${jsonEncode(result)});',
    );
  }

  Future<void> _reject(int id, String error) async {
    await controller.runJavaScript(
      "window.flutterBridge._reject($id, '${error.replaceAll("'", "\\'")}');",
    );
  }
}
