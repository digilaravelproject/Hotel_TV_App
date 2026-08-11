import 'package:flutter/material.dart';
import '../../../../core/services/device/accessibility_service.dart';

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

  Future<void> _handleEnableClicked() async {
    if (!_isAgreeChecked) return;
    setState(() {
      _isChecking = true;
    });
    await AccessibilityService.openAccessibilitySettings();
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          child: Container(
            width: 640,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.accessibility_new_rounded,
                  size: 44,
                  color: Color(0xFF38BDF8),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This app uses Accessibility services',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Accessibility permissions are used to detect when your device\'s remote control home button is pressed and allows you to remap its action, should you choose to, in order to conveniently launch this app using the home button for ease of navigation and functionality.\n\n'
                  'Once you agree to enable Hotel TV Launcher accessibility service, we will prompt you, once again, for specific permission to remap your home button when it\'s used for first time.\n\n'
                  'Should you choose to DENY the permission, you can still use our app but without this functionality.\n\n'
                  'Please note that we do NOT collect and/or share personal or sensitive data using the accessibility service capabilities.',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: _isAgreeChecked,
                      activeColor: const Color(0xFF0284C7),
                      onChanged: (val) {
                        setState(() {
                          _isAgreeChecked = val ?? false;
                        });
                      },
                    ),
                    const Text(
                      'I Agree',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please note that at any time you can disable this accessibility service.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Once you press ENABLE below we will redirect you to your device settings',
                  style: TextStyle(
                    color: Color(0xFFF87171),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'In device settings, please navigate to Device Preferences or System > Accessibility > Hotel TV Launcher and choose Enable',
                  style: TextStyle(color: Color(0xFFF87171), fontSize: 10),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      autofocus: true,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isAgreeChecked && !_isChecking
                          ? _handleEnableClicked
                          : null,
                      child: _isChecking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'ENABLE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
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
    );
  }
}
