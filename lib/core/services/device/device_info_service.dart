import 'dart:io';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import '../storage/shared_prefs.dart';

class DeviceInfoService {
  static const _channel = MethodChannel('com.digiemperor.hotel/device_info');
  static Map<String, dynamic>? _cachedDeviceInfo;

  /// Clears in-memory device info cache
  static void clearCache() {
    _cachedDeviceInfo = null;
  }

  /// Fetches and caches the complete device details
  static Future<Map<String, dynamic>> getFullDeviceInfo({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _cachedDeviceInfo = null;
    }
    if (_cachedDeviceInfo != null) {
      return _cachedDeviceInfo!;
    }

    String deviceId = '';
    String model = '';
    String brand = '';
    String osVersion = '';
    String ipAddress = '';
    String macAddress = '';

    // Fetch IP Address
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            ipAddress = addr.address;
            break;
          }
        }
      }
    } catch (_) {}

    // Fetch native MAC address via MethodChannel
    try {
      if (Platform.isAndroid) {
        final String? nativeMac = await _channel.invokeMethod<String>('getMacAddress');
        if (nativeMac != null && nativeMac.isNotEmpty) {
          macAddress = nativeMac;
        }
      }
    } catch (_) {}

    // If native MAC address is not available due to OS restrictions,
    // generate and persist a unique MAC address for this device.
    if (macAddress.isEmpty) {
      final storedMac = SharedPrefs.getString('device_mac_address');
      if (storedMac != null && storedMac.isNotEmpty) {
        macAddress = storedMac;
      } else {
        final random = Random();
        final bytes = List<int>.generate(6, (_) => random.nextInt(256));
        // Set local administration bit (locally administered MAC)
        bytes[0] = (bytes[0] & 0xFC) | 0x02;
        final generatedMac = bytes
            .map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase())
            .join(':');
        await SharedPrefs.setString('device_mac_address', generatedMac);
        macAddress = generatedMac;
      }
    }

    String serial = '';

    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        // Fetch secure android_id natively
        try {
          final String? nativeAndroidId = await _channel.invokeMethod<String>('getAndroidId');
          if (nativeAndroidId != null && nativeAndroidId.isNotEmpty) {
            deviceId = nativeAndroidId;
          }
        } catch (_) {}
        if (deviceId.isEmpty) {
          deviceId = androidInfo.id;
        }

        // Fetch hardware serial number natively
        try {
          final String? nativeSerial = await _channel.invokeMethod<String>('getSerialNumber');
          if (nativeSerial != null && nativeSerial.isNotEmpty) {
            serial = nativeSerial;
          }
        } catch (_) {}
        if (serial.isEmpty || serial == 'unknown') {
          serial = deviceId;
        }

        model = androidInfo.model;
        brand = androidInfo.brand;
        osVersion = androidInfo.version.release;
      } else if (Platform.isIOS) {
        final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? '';
        model = iosInfo.model;
        brand = 'Apple';
        osVersion = iosInfo.systemVersion;
      } else if (Platform.isMacOS) {
        final MacOsDeviceInfo macInfo = await deviceInfo.macOsInfo;
        deviceId = macInfo.systemGUID ?? '';
        model = macInfo.model;
        brand = 'Apple';
        osVersion = macInfo.osRelease;
      }
    } catch (_) {}

    String gateway = '';
    String subnet = '';
    String dns = '';

    try {
      if (Platform.isAndroid) {
        final Map? netDetails = await _channel.invokeMethod<Map>('getNetworkDetails');
        if (netDetails != null) {
          gateway = netDetails['gateway']?.toString() ?? '';
          subnet = netDetails['subnet']?.toString() ?? '';
          dns = netDetails['dns']?.toString() ?? '';
        }
      }
    } catch (_) {}

    _cachedDeviceInfo = {
      'deviceId': deviceId,
      'serial': serial,
      'macAddress': macAddress,
      'ipAddress': ipAddress,
      'gateway': gateway,
      'subnet': subnet,
      'dns': dns,
      'model': model,
      'brand': brand,
      'osVersion': osVersion,
    };

    return _cachedDeviceInfo!;
  }

  /// Helper to get just the unique device ID
  static Future<String> getDeviceId() async {
    final info = await getFullDeviceInfo();
    return info['deviceId'] ?? '';
  }

  /// Fetches the real network connectivity type (WiFi, Ethernet, Mobile, etc.)
  static Future<String> getNetworkType() async {
    try {
      final dynamic connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult is List) {
        if (connectivityResult.isEmpty || connectivityResult.contains(ConnectivityResult.none)) {
          return 'Disconnected';
        }
        if (connectivityResult.contains(ConnectivityResult.ethernet)) {
          return 'Ethernet';
        }
        if (connectivityResult.contains(ConnectivityResult.wifi)) {
          return 'WiFi';
        }
        if (connectivityResult.contains(ConnectivityResult.mobile)) {
          return 'Mobile';
        }
        return 'Connected';
      } else {
        final ConnectivityResult result = connectivityResult as ConnectivityResult;
        if (result == ConnectivityResult.none) {
          return 'Disconnected';
        }
        if (result == ConnectivityResult.ethernet) {
          return 'Ethernet';
        }
        if (result == ConnectivityResult.wifi) {
          return 'WiFi';
        }
        if (result == ConnectivityResult.mobile) {
          return 'Mobile';
        }
        return 'Connected';
      }
    } catch (_) {
      return 'Connected';
    }
  }
}
