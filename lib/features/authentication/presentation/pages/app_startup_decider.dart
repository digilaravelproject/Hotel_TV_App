import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/storage/shared_prefs.dart';
import '../../../../core/services/storage/token_manger.dart';
import '../../../../core/services/template/template_manager_service.dart';
import '../../../../core/widget/loading_widget.dart';
import '../../../dashboard/presentation/pages/tv_webview_screen.dart';
import 'tv_login_screen.dart';

class AppStartupDecider extends StatefulWidget {
  const AppStartupDecider({Key? key}) : super(key: key);

  @override
  State<AppStartupDecider> createState() => _AppStartupDeciderState();
}

class _AppStartupDeciderState extends State<AppStartupDecider> {
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
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
        _navigateToWebview();
        // Background silent check without showing any UI or blocking
        TemplateManagerService.checkAndUpdateTemplateSilent();
        return;
      }

      setState(() => _statusMessage = 'Installing...');
      await TemplateManagerService.checkAndUpdateTemplateSilent(
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _statusMessage =
                'Installing: ${(progress * 100).toStringAsFixed(0)}%';
          });
        },
      );

      if (!mounted) return;
      final nowDownloaded = await TemplateManagerService.isTemplateDownloaded();
      if (nowDownloaded) {
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: LoadingWidget(
        type: LoadingType.tvScreen,
        subtitle: _statusMessage,
      ),
    );
  }
}
