import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'tv_focusable.dart';

class TvNetworkStatusHeader extends StatefulWidget {
  const TvNetworkStatusHeader({Key? key}) : super(key: key);

  @override
  State<TvNetworkStatusHeader> createState() => _TvNetworkStatusHeaderState();
}

class _TvNetworkStatusHeaderState extends State<TvNetworkStatusHeader> {
  bool _isConnected = true;
  bool _isEthernet = false;
  int _signalLevel = 4; // 0 to 4
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      _checkStatus();
    });

    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkStatus();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    const channel = MethodChannel('com.digiemperor.hotel/tv_control');
    try {
      final dynamic rawData =
          await channel.invokeMethod('getWifiSignalStrength');
      if (rawData is Map) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(rawData);
        final bool connected = data['connected'] == true;
        final String type = data['type']?.toString() ?? 'none';
        final int level = (data['level'] as num?)?.toInt() ?? (connected ? 4 : 0);

        if (mounted) {
          setState(() {
            _isConnected = connected;
            _isEthernet = type == 'ethernet';
            _signalLevel = level;
          });
        }
        return;
      }
    } catch (_) {}

    // Fallback to connectivity_plus if native channel fails
    try {
      final List<ConnectivityResult> results =
          await Connectivity().checkConnectivity();
      final bool isConnected = results.any((r) => r != ConnectivityResult.none);
      final bool isEthernet = results.contains(ConnectivityResult.ethernet);

      if (mounted) {
        setState(() {
          _isConnected = isConnected;
          _isEthernet = isEthernet;
          _signalLevel = isConnected ? 4 : 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _openNetworkSettings() async {
    const channel = MethodChannel('com.digiemperor.hotel/tv_control');
    try {
      final bool? success =
          await channel.invokeMethod<bool>('openWifiSettings');
      if (success != true) {
        await channel.invokeMethod('openSettings');
      }
    } catch (_) {
      try {
        await channel.invokeMethod('openSettings');
      } catch (_) {}
    }
  }

  IconData _getSignalIcon() {
    if (!_isConnected) {
      return Icons.wifi_off_rounded;
    }
    if (_isEthernet) {
      return Icons.lan_rounded;
    }

    switch (_signalLevel) {
      case 4:
        return Icons.wifi_rounded;
      case 3:
        return Icons.network_wifi_3_bar_rounded;
      case 2:
        return Icons.network_wifi_2_bar_rounded;
      case 1:
        return Icons.network_wifi_1_bar_rounded;
      default:
        return Icons.wifi_rounded;
    }
  }

  Color _getSignalColor() {
    if (!_isConnected) {
      return const Color(0xFFEF4444); // Red
    }
    if (_isEthernet) {
      return const Color(0xFF22C55E); // Green for LAN
    }

    switch (_signalLevel) {
      case 4:
      case 3:
        return const Color(0xFF22C55E); // Green (Strong)
      case 2:
        return const Color(0xFFF59E0B); // Amber / Yellow (Medium)
      case 1:
        return const Color(0xFFF97316); // Orange (Weak)
      default:
        return const Color(0xFF22C55E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _getSignalColor();
    final IconData statusIcon = _getSignalIcon();

    return TvFocusable(
      scaleFactor: 1.1,
      onTap: _openNetworkSettings,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF1B0F2A).withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(
            color: statusColor.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.25),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: Icon(
            statusIcon,
            size: 20,
            color: statusColor,
          ),
        ),
      ),
    );
  }
}
