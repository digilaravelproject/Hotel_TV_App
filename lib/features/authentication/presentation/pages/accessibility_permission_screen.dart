import 'package:flutter/material.dart';
import '../../../../core/services/device/accessibility_service.dart';
import '../../../../core/widget/custom_app_text.dart';
import '../../../../core/widget/tv_focusable.dart';
import '../../../../core/widget/tv_network_status_header.dart';
import '../../../../core/utils/ui_spacer.dart';
import '../../../../core/constants/app_constants.dart';

class AccessibilityPermissionScreen extends StatefulWidget {
  final VoidCallback onGranted;

  const AccessibilityPermissionScreen({Key? key, required this.onGranted})
      : super(key: key);

  @override
  State<AccessibilityPermissionScreen> createState() =>
      _AccessibilityPermissionScreenState();
}

class _AccessibilityPermissionScreenState
    extends State<AccessibilityPermissionScreen> with WidgetsBindingObserver {
  bool _isAgreeChecked = true;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final enabled = await AccessibilityService.isAccessibilityEnabled();
    if (enabled && mounted) {
      widget.onGranted();
    }
  }

  String? _errorMessage;

  Future<void> _handleEnableClicked() async {
    if (!_isAgreeChecked) return;
    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    bool opened = false;
    try {
      opened = await AccessibilityService.openAccessibilitySettings();
    } catch (e) {
      _errorMessage = "Unable to open TV Settings: $e";
    }

    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        _isChecking = false;
      });
      if (!opened) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _errorMessage ?? "Could not launch TV Settings. Please open TV Settings manually.",
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF150A21),
              Color(0xFF09040E),
              Color(0xFF1B0715),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Ambient glow top right
            Positioned(
              top: -50,
              right: -80,
              child: Container(
                width: 550,
                height: 550,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFE11D48).withOpacity(0.35),
                      const Color(0xFF9333EA).withOpacity(0.20),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            // Ambient glow bottom right
            Positioned(
              bottom: -100,
              right: 50,
              child: Container(
                width: 500,
                height: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFC084FC).withOpacity(0.25),
                      const Color(0xFFE11D48).withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Ambient glow top left
            Positioned(
              top: -100,
              left: -50,
              child: Container(
                width: 450,
                height: 450,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF4F46E5).withOpacity(0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 24,
              right: 32,
              child: const TvNetworkStatusHeader(),
            ),

            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0),
                child: Container(
                  width: 620,
                  padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 24.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B0F2A).withOpacity(0.75),
                    borderRadius: BorderRadius.circular(22.0),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with App Logo
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            clipBehavior: Clip.antiAlias,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                          UiSpacer.hSpace(12),
                          CustomAppText(
                            AppConstants.appName,
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ],
                      ),
                      UiSpacer.vSpace(16),

                      const CustomAppText(
                        'This app uses Accessibility services',
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        textAlign: TextAlign.center,
                      ),
                      UiSpacer.vSpace(12),

                      Text(
                        'Accessibility permissions are used to detect when your device\'s remote control home button is pressed and allows you to remap its action to launch this app conveniently.\n\n'
                        'Should you choose to DENY the permission, you can still use our app but without home button remapping.\n\n'
                        'We do NOT collect or share any personal or sensitive data using accessibility capabilities.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12.5,
                          height: 1.38,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      UiSpacer.vSpace(16),

                      // Checkbox Row with TvFocusable for TV remote OK key toggle
                      TvFocusable(
                        scaleFactor: 1.02,
                        onTap: () {
                          setState(() {
                            _isAgreeChecked = !_isAgreeChecked;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Transform.scale(
                                scale: 0.8,
                                child: Checkbox(
                                  value: _isAgreeChecked,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  activeColor: Colors.white,
                                  checkColor: Colors.black,
                                  onChanged: (val) {
                                    setState(() {
                                      _isAgreeChecked = val ?? false;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 4),
                              const CustomAppText(
                                'I Agree to terms and service permission',
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ],
                          ),
                        ),
                      ),
                      UiSpacer.vSpace(12),

                      Text(
                        'Please navigate to Settings > Accessibility > Hotel TV Launcher and choose Enable',
                        style: TextStyle(
                          color: const Color(0xFFFB7185),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      UiSpacer.vSpace(24),

                      // Enable Button & Skip Button Row / Column
                      Column(
                        children: [
                          SizedBox(
                            width: 280,
                            height: 44,
                            child: TvFocusable(
                              autofocus: true,
                              scaleFactor: 1.04,
                              onTap: _isAgreeChecked && !_isChecking ? _handleEnableClicked : () {},
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _isAgreeChecked ? Colors.white : Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: _isAgreeChecked
                                      ? [
                                          BoxShadow(
                                            color: Colors.white.withOpacity(0.25),
                                            blurRadius: 16,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: _isChecking
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.black,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : CustomAppText(
                                        'Enable',
                                        color: _isAgreeChecked ? Colors.black : Colors.white38,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                              ),
                            ),
                          ),
                          UiSpacer.vSpace(12),
                          SizedBox(
                            width: 280,
                            height: 40,
                            child: TvFocusable(
                              scaleFactor: 1.04,
                              onTap: widget.onGranted,
                              child: Container(
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: const CustomAppText(
                                  'Skip & Continue',
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
