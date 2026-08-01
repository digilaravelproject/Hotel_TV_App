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
  StreamSubscription? _connectivitySub;

  static DateTime? _lastHdmiLaunchTime;

  FlutterBridgeHandler(this.controller)
      : _tvChannel = const MethodChannel('com.digiemperor.hotel/tv_control');

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
      case 'getInstalledApps':
      case 'getApps':
      case 'getAppList':
        final installedAppsRaw = await _tvChannel.invokeMethod<List>('getInstalledApps') ?? [];
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
          return [];
        }

        // Return ONLY apps from active_ott that are physically INSTALLED on the TV device
        final List<Map<String, dynamic>> resultApps = [];
        for (var ott in activeOttList) {
          final String ottPackage = ott['package_name']?.toString() ?? ott['package']?.toString() ?? ott['packageName']?.toString() ?? '';
          final String ottId = ott['id']?.toString().toLowerCase() ?? '';
          final String ottName = ott['name']?.toString() ?? ottId;

          if (ottPackage.isEmpty && ottId.isEmpty) continue;

          final matchingInstalled = installedApps.firstWhere(
            (app) {
              final pkg = (app['package'] ?? app['packageName'] ?? '').toString().toLowerCase();
              final target = ottPackage.toLowerCase();
              final id = ottId.toLowerCase();
              final name = ottName.toLowerCase();
              if (pkg.isEmpty) return false;

              // 1. Exact package match
              if (target.isNotEmpty && pkg == target) return true;

              // 2. Sub-package contains match
              if (target.isNotEmpty && (target.contains(pkg) || pkg.contains(target))) return true;

              // 3. Dynamic match by OTT ID (e.g. 'youtube', 'jiocinema', 'hotstar')
              if (id.length > 2 && pkg.contains(id)) return true;

              // 4. Dynamic match by cleaned app name (e.g. 'YouTube' -> 'youtube')
              final cleanName = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
              if (cleanName.length > 3 && pkg.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').contains(cleanName)) return true;

              return false;
            },
            orElse: () => {},
          );

          // Include ONLY physically installed apps with real native icons and names
          if (matchingInstalled.isNotEmpty) {
            final realPackage = matchingInstalled['packageName'] ?? matchingInstalled['package'] ?? ottPackage;
            resultApps.add({
              'name': matchingInstalled['name'] ?? matchingInstalled['appName'] ?? ottName,
              'label': matchingInstalled['name'] ?? matchingInstalled['appName'] ?? ottName,
              'package': realPackage,
              'packageName': realPackage,
              'package_name': realPackage,
              'icon': matchingInstalled['icon'] ?? matchingInstalled['appIcon'] ?? '',
            });
          }
        }

        return resultApps;

      case 'launchApp':
        final package = args[0] as String?;
        if (package == null) throw ArgumentError('package is required');
        await _tvChannel.invokeMethod('launchApp', {'package': package});
        return {'success': true};

      case 'openSettings':
      case 'openAndroidSettings':
        await _tvChannel.invokeMethod('openSettings');
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
        final info = await DeviceInfoService.getFullDeviceInfo();
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
        if (saved != null && saved.isNotEmpty && saved != 'null') {
          return {'selectedPort': saved, 'port': saved};
        }
        final dynamic inputsRes = await _tvChannel.invokeMethod('getLiveTvInputs');
        if (inputsRes is List && inputsRes.isNotEmpty) {
          final firstMap = Map<String, dynamic>.from(inputsRes.first as Map);
          final firstPort = firstMap['id']?.toString() ?? firstMap['model']?.toString() ?? firstMap['label']?.toString() ?? '';
          return {'selectedPort': firstPort, 'port': firstPort};
        }
        return {'selectedPort': '', 'port': ''};

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

        String? model = (args.isNotEmpty && args[0] != null && args[0].toString().trim().isNotEmpty && args[0].toString() != 'null')
            ? args[0].toString().trim()
            : null;
        String checkedSource = model != null ? 'argument' : '';

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
        }

        if (model == null || model.isEmpty || model == 'null') {
          model = 'HDMI 1';
          checkedSource = 'default_fallback';
        }
        print('[FlutterBridge] Launching Live TV input port: $model (source: $checkedSource)');
        await _tvChannel.invokeMethod('launchHdmi', {'model': model});
        return {
          'success': true,
          'port': model,
          'checkedPort': model,
          'source': checkedSource,
          'message': 'Checked and launched Live TV port: $model'
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
        final dynamic res = await _tvChannel.invokeMethod('getHdmiModels');
        if (res == null) return [];
        List allList = [];
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
            });
          });
        }

        // Filter only physically connected input sources
        final connectedInputs = allList.where((item) {
          if (item is Map && item.containsKey('isConnected')) {
            return item['isConnected']?.toString() == 'true';
          }
          return true;
        }).toList();

        return connectedInputs.isNotEmpty ? connectedInputs : allList;

      case 'getLiveTvInputs':
        final dynamic res = await _tvChannel.invokeMethod('getHdmiModels');
        if (res == null || res is! List) return [];
        // Filter strictly active connected STB/TV tuner ports for Live TV
        final connectedList = res.where((e) {
          if (e is Map) {
            final isConn = e['isConnected']?.toString() == 'true';
            return isConn;
          }
          return false;
        }).map((e) => Map<String, dynamic>.from(e as Map)).toList();

        return connectedList;

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
        final package = args[0] as String?;
        if (package == null) throw ArgumentError('package is required');
        await _tvChannel.invokeMethod('launchApp', {'package': package});
        return {'success': true};

      case 'getPictureList':
        return [];

      case 'rotateImage':
        return {'success': false, 'error': 'Not implemented'};

      default:
        throw UnimplementedError('Method $method not implemented');
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
