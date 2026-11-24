import 'dart:convert';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage/shared_prefs.dart';

class TvDeviceInfoModel {
  final String roomNo;
  final String deviceId;
  final String macAddress;
  final String ipAddress;
  final String model;
  final String brand;
  final String osVersion;
  final String tvDisplayName;
  final bool isDemo;
  final int demoDaysLeft;

  const TvDeviceInfoModel({
    this.roomNo = 'DEMO-001',
    this.deviceId = '',
    this.macAddress = '',
    this.ipAddress = '',
    this.model = 'Smart TV',
    this.brand = 'Panasonic',
    this.osVersion = '10',
    this.tvDisplayName = '',
    this.isDemo = false,
    this.demoDaysLeft = 0,
  });

  factory TvDeviceInfoModel.fromMap(Map<String, dynamic>? dataMap) {
    if (dataMap == null) return const TvDeviceInfoModel();
    final deviceMap = dataMap['device'] as Map<String, dynamic>? ?? {};
    final authMap = dataMap['auth'] as Map<String, dynamic>? ?? {};

    final room = deviceMap['room_no']?.toString() ?? dataMap['room_no']?.toString() ?? 'DEMO-001';
    final modelName = deviceMap['model']?.toString() ?? 'Smart TV';
    final brandName = deviceMap['brand']?.toString() ?? 'Panasonic';

    final savedDisplayName = SharedPrefs.getString('tv_display_name') ?? '';
    final computedDisplayName = savedDisplayName.isNotEmpty
        ? savedDisplayName
        : '$brandName $modelName (Room $room)';

    return TvDeviceInfoModel(
      roomNo: room,
      deviceId: deviceMap['device_id']?.toString() ?? '',
      macAddress: deviceMap['mac_address']?.toString() ?? '',
      ipAddress: deviceMap['ip_address']?.toString() ?? '',
      model: modelName,
      brand: brandName,
      osVersion: deviceMap['os_version']?.toString() ?? '10',
      tvDisplayName: computedDisplayName,
      isDemo: authMap['is_demo'] == true || SharedPrefs.getBool(AppConstants.isDemoModeKey) == true,
      demoDaysLeft: authMap['demo_days_left'] is int ? authMap['demo_days_left'] as int : 0,
    );
  }

  static TvDeviceInfoModel? _cachedInstance;

  static TvDeviceInfoModel current() {
    if (_cachedInstance != null) return _cachedInstance!;
    try {
      final rawData = SharedPrefs.getString(AppConstants.tvLoginDataKey);
      if (rawData != null && rawData.isNotEmpty) {
        final decoded = jsonDecode(rawData);
        final dataMap = decoded['data'] ?? decoded;
        if (dataMap is Map<String, dynamic>) {
          _cachedInstance = TvDeviceInfoModel.fromMap(dataMap);
          return _cachedInstance!;
        }
      }
    } catch (_) {}
    return const TvDeviceInfoModel();
  }

  static void invalidateCache() {
    _cachedInstance = null;
  }
}
