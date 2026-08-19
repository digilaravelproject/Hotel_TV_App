import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/storage/shared_prefs.dart';
import '../../../../core/services/storage/token_manger.dart';
import '../../../../core/services/template/template_manager_service.dart';
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
  bool _showLoader = true;
  bool _needsAccessibilityConsent = false;
  bool _needsLauncherConsent = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndProceed();
  }

  Future<void> _checkPermissionsAndProceed() async {
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

    _decideStartupFlow();
  }

  Future<void> _decideStartupFlow() async {
    try {
      final token = await TokenManager.getToken();
      final hasLoginData = SharedPrefs.containsKey(AppConstants.tvLoginDataKey);

      if (token.isEmpty || !hasLoginData) {
        _navigateToLogin();
        return;
      }

      final isDownloaded = await TemplateManagerService.isTemplateDownloaded();
      if (isDownloaded) {
        await TemplateManagerService.regenerateDataJson();
        _navigateToWebview();
        return;
      }

      setState(() {
        _showLoader = true;
        _statusMessage = 'Downloading template...';
      });

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
            _checkPermissionsAndProceed();
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
      backgroundColor: Colors.black,
      body: LoadingWidget(
        type: LoadingType.tvScreen,
        subtitle: _statusMessage,
      ),
    );
  }
}
