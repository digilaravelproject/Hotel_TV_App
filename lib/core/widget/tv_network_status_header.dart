import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'tv_focusable.dart';

class TvNetworkStatusHeader extends StatefulWidget {
  final bool showSettings;
  final FocusNode? settingsFocusNode;
  final FocusNode? wifiFocusNode;

  const TvNetworkStatusHeader({
    Key? key,
    this.showSettings = true,
    this.settingsFocusNode,
    this.wifiFocusNode,
  }) : super(key: key);

  @override
  State<TvNetworkStatusHeader> createState() => _TvNetworkStatusHeaderState();
}

class _TvNetworkStatusHeaderState extends State<TvNetworkStatusHeader> {
  bool _isConnected = true;
  bool _isEthernet = false;
  int _signalLevel = 4; // 0 to 4
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _pollingTimer;

  static const _channel = MethodChannel('com.paxtv.hospitality/tv_control');

  @override
  void initState() {
    super.initState();
    _checkStatus();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        _subscription = Connectivity()
            .onConnectivityChanged
            .listen((List<ConnectivityResult> results) {
          _checkStatus();
        }, onError: (err) {});
      } catch (_) {}
    }

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
    try {
      final dynamic rawData =
          await _channel.invokeMethod('getWifiSignalStrength');
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
    try {
      final bool? success =
          await _channel.invokeMethod<bool>('openWifiSettings');
      if (success != true) {
        await _channel.invokeMethod('openSettings');
      }
    } catch (_) {
      try {
        await _channel.invokeMethod('openSettings');
      } catch (_) {}
    }
  }

  Future<void> _openDeviceSettings() async {
    try {
      await _channel.invokeMethod('openSettings');
    } catch (_) {}
  }

  Future<void> _openAppDetailsSettings() async {
    try {
      await _channel.invokeMethod('openAppDetailsSettings');
    } catch (_) {
      _openDeviceSettings();
    }
  }

  Future<void> _openHomeSettings() async {
    try {
      await _channel.invokeMethod('openHomeSettings');
    } catch (_) {
      _openDeviceSettings();
    }
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF160E2A).withOpacity(0.96),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade400.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.shade400.withOpacity(0.4),
                        ),
                      ),
                      child: Icon(
                        Icons.settings_suggest_rounded,
                        color: Colors.amber.shade300,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "TV & App Settings",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            "Quick system control & launcher management",
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 16),

                // Option 1: Open Device Settings
                _buildActionTile(
                  icon: Icons.settings_rounded,
                  iconColor: const Color(0xFF38BDF8),
                  title: "Open Device Settings",
                  subtitle: "Android TV system settings (Wi-Fi, Bluetooth, Device)",
                  autofocus: true,
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _openDeviceSettings();
                  },
                ),
                const SizedBox(height: 10),

                // Option 2: App Info & Uninstall
                _buildActionTile(
                  icon: Icons.delete_outline_rounded,
                  iconColor: const Color(0xFFEF4444),
                  title: "App Info & Uninstall",
                  subtitle: "Clear defaults, force stop, or uninstall PAX TV",
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _openAppDetailsSettings();
                  },
                ),
                const SizedBox(height: 10),

                // Option 3: Switch Default Launcher
                _buildActionTile(
                  icon: Icons.home_repair_service_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: "Switch / Reset Default Launcher",
                  subtitle: "Choose factory TV launcher or change home default",
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _openHomeSettings();
                  },
                ),
                const SizedBox(height: 10),

                // Option 4: Network Settings
                _buildActionTile(
                  icon: Icons.wifi_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: "Network & Wi-Fi Settings",
                  subtitle: "Configure wireless or ethernet connection",
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _openNetworkSettings();
                  },
                ),
                const SizedBox(height: 16),

                // Close Button
                Align(
                  alignment: Alignment.centerRight,
                  child: TvFocusable(
                    onTap: () => Navigator.pop(dialogContext),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Text(
                        "Close",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool autofocus = false,
  }) {
    return TvFocusable(
      autofocus: autofocus,
      scaleFactor: 1.02,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(0.4),
              size: 20,
            ),
          ],
        ),
      ),
    );
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showSettings) ...[
          // Settings Button (⚙️)
          TvFocusable(
            focusNode: widget.settingsFocusNode,
            scaleFactor: 1.1,
            onTap: () => _showSettingsDialog(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF1B0F2A).withOpacity(0.85),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.35),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.10),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.settings_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],

        // Wi-Fi / Network Button (📶)
        TvFocusable(
          focusNode: widget.wifiFocusNode,
          scaleFactor: 1.1,
          onTap: _openNetworkSettings,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF1B0F2A).withOpacity(0.85),
              shape: BoxShape.circle,
              border: Border.all(
                color: statusColor.withOpacity(0.7),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.25),
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
        ),
      ],
    );
  }
}
