import 'package:flutter/material.dart';
import '../../../../core/services/device/accessibility_service.dart';
import '../../../../core/widget/custom_app_text.dart';
import '../../../../core/widget/tv_focusable.dart';
import '../../../../core/widget/tv_network_status_header.dart';
import '../../../../core/utils/ui_spacer.dart';
import '../../../../core/constants/app_constants.dart';

class DefaultLauncherPermissionScreen extends StatefulWidget {
  final VoidCallback onProceed;

  const DefaultLauncherPermissionScreen({Key? key, required this.onProceed})
      : super(key: key);

  @override
  State<DefaultLauncherPermissionScreen> createState() =>
      _DefaultLauncherPermissionScreenState();
}

class _DefaultLauncherPermissionScreenState
    extends State<DefaultLauncherPermissionScreen> {
  bool _isProcessing = false;

  Future<void> _handleAllowClicked() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await AccessibilityService.requestDefaultLauncher();
    } catch (_) {}

    if (mounted) {
      widget.onProceed();
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
                  width: 580,
                  padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 28.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B0F2A).withOpacity(0.85),
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
                      // App Logo & Name Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
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
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ],
                      ),
                      UiSpacer.vSpace(20),

                      const CustomAppText(
                        'Set PAX TV Hospitality as your default home app?',
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        textAlign: TextAlign.center,
                      ),
                      UiSpacer.vSpace(14),

                      Text(
                        'Allow PAX TV Hospitality to be set as your Default Home App so pressing the Home button on your TV remote automatically opens this app.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      UiSpacer.vSpace(28),

                      // ALLOW & DENY Buttons Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // DENY Button
                          SizedBox(
                            width: 160,
                            height: 46,
                            child: TvFocusable(
                              scaleFactor: 1.04,
                              onTap: widget.onProceed,
                              child: Container(
                                height: 46,
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
                                  'DENY',
                                  color: Colors.white70,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          UiSpacer.hSpace(16),

                          // ALLOW Button
                          SizedBox(
                            width: 180,
                            height: 46,
                            child: TvFocusable(
                              autofocus: true,
                              scaleFactor: 1.04,
                              onTap: _isProcessing ? () {} : _handleAllowClicked,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 46,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.3),
                                      blurRadius: 16,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: _isProcessing
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.black,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const CustomAppText(
                                        'ALLOW',
                                        color: Colors.black,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
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
