import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/storage/shared_prefs.dart';
import '../../../../core/services/storage/token_manger.dart';
import '../../../../core/services/template/template_manager_service.dart';
import '../../../../core/services/device/device_info_service.dart';
import '../../../../core/widget/loading_widget.dart';
import '../../../dashboard/presentation/pages/tv_webview_screen.dart';
import 'tv_login_screen.dart';
import '../../../../core/services/device/accessibility_service.dart';
import 'accessibility_permission_screen.dart';
import 'default_launcher_permission_screen.dart';

class AppStartupDecider extends StatefulWidget {
  const AppStartupDecider({Key? key}) : super(key: key);

  @override
  State<AppStartupDecider> createState() => _AppStartupDeciderState();
}

class _AppStartupDeciderState extends State<AppStartupDecider> {
  String _statusMessage = 'Initializing Hotel TV...';
  bool _needsAccessibilityConsent = false;
  bool _needsLauncherConsent = false;

  @override
  void initState() {
    super.initState();
    _decideStartupFlow();
  }

  Future<void> _decideStartupFlow() async {
    try {
      final token = await TokenManager.getToken();
      final hasLoginData = SharedPrefs.containsKey(AppConstants.tvLoginDataKey);

      // 1. Fresh Install / Logged Out: NEVER ask for any permissions. Go straight to login screen!
      if (token.isEmpty || !hasLoginData) {
        _navigateToLogin();
        return;
      }

      // 2. User IS logged in: Check if Demo Mode or Paid Mode
      final bool isDemo = SharedPrefs.getBool(AppConstants.isDemoModeKey) ?? false;
      if (isDemo) {
        // ❌ STRICT RULE: Skip Accessibility and Default Launcher consents in Demo Mode
        await _proceedToTemplateFlow();
        return;
      }

      // 3. Paid Mode (QR / Manual License Login): Ask for permissions if not already enabled/skipped
      if (!kIsWeb && Platform.isAndroid) {
        final bool isAccSkipped = SharedPrefs.getBool('accessibility_skipped') ?? false;
        if (!isAccSkipped) {
          final bool isAccessibilityEnabled = await AccessibilityService.isAccessibilityEnabled();
          if (!isAccessibilityEnabled) {
            if (mounted) {
              setState(() {
                _needsAccessibilityConsent = true;
              });
            }
            return;
          }
        }

        final bool isLauncherSkipped = SharedPrefs.getBool('launcher_skipped') ?? false;
        if (!isLauncherSkipped) {
          final bool isLauncherDefault = await AccessibilityService.isDefaultLauncher();
          if (!isLauncherDefault) {
            if (mounted) {
              setState(() {
                _needsLauncherConsent = true;
              });
            }
            return;
          }
        }
      }

      // 4. Permissions verified/granted -> proceed to template download / webview
      await _proceedToTemplateFlow();
    } catch (_) {
      _navigateToLogin();
    }
  }

  Future<void> _proceedToTemplateFlow() async {
    try {
      final isDownloaded = await TemplateManagerService.isTemplateDownloaded();
      if (isDownloaded) {
        // Android device name set karo (mobile cast list mein dikhne ke liye)
        _applyTvDeviceName();
        _navigateToWebview();
        return;
      }

      if (mounted) {
        setState(() {
          _statusMessage = 'Downloading template...';
        });
      }

      await TemplateManagerService.downloadTemplateFromSavedData(
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _statusMessage =
                'Installing: ${(progress * 100).toStringAsFixed(0)}%';
          });
        },
      );

      if (!mounted) return;
      final finalDownloaded = await TemplateManagerService.isTemplateDownloaded();
      if (finalDownloaded) {
        _navigateToWebview();
      } else {
        _navigateToLogin();
      }
    } catch (_) {
      _navigateToLogin();
    }
  }

  /// Android device name set karta hai jo mobile cast list mein dikhta hai
  void _applyTvDeviceName() {
    final tvDisplayName = SharedPrefs.getString('tv_display_name') ?? '';
    if (tvDisplayName.isNotEmpty) {
      DeviceInfoService.setDeviceName(tvDisplayName);
    }
  }

  void _navigateToWebview() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TvWebviewScreen()),
    );
  }

  void _navigateToLogin() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TvLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_needsAccessibilityConsent) {
      return AccessibilityPermissionScreen(
        onGranted: () async {
          await SharedPrefs.setBool('accessibility_skipped', true);
          if (mounted) {
            setState(() {
              _needsAccessibilityConsent = false;
            });
            _decideStartupFlow();
          }
        },
      );
    }

    if (_needsLauncherConsent) {
      return DefaultLauncherPermissionScreen(
        onProceed: () async {
          await SharedPrefs.setBool('launcher_skipped', true);
          if (mounted) {
            setState(() {
              _needsLauncherConsent = false;
            });
            _decideStartupFlow();
          }
        },
      );
    }

    return Scaffold(
      body: LoadingWidget(
        type: LoadingType.tvScreen,
        subtitle: _statusMessage,
      ),
    );
  }
}
