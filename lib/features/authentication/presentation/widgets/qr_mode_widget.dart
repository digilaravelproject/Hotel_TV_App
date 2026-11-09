import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widget/custom_app_text.dart';
import '../../../../core/widget/tv_focusable.dart';
import '../../../../core/utils/ui_spacer.dart';

class QrModeWidget extends StatelessWidget {
  final String pairCode;
  final int remainingSeconds;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRefresh;
  final VoidCallback? onSignUpNow;
  final FocusNode? signUpFocus;

  const QrModeWidget({
    Key? key,
    required this.pairCode,
    required this.remainingSeconds,
    required this.isLoading,
    this.errorMessage,
    required this.onRefresh,
    this.onSignUpNow,
    this.signUpFocus,
  }) : super(key: key);

  String _formatCode(String code) {
    if (code.isEmpty) return "••••••••";
    if (code.length == 8 && !code.contains('-')) {
      return "${code.substring(0, 4)}-${code.substring(4)}";
    }
    return code;
  }

  Widget _buildStepBadge(String number) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.30),
          width: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        number,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qrUrl = AppConstants.getQrUrl(pairCode);

    if (isLoading) {
      return SizedBox(
        key: const ValueKey('qr_mode_loading'),
        height: 260,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2.8,
              ),
              UiSpacer.vSpace(18),
              const CustomAppText(
                "Generating Pairing Code...",
                textAlign: TextAlign.center,
                fontSize: 14,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null && pairCode.isEmpty) {
      return SizedBox(
        key: const ValueKey('qr_mode_error'),
        height: 260,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.redAccent.shade100, size: 40),
              UiSpacer.vSpace(10),
              CustomAppText(
                errorMessage!,
                textAlign: TextAlign.center,
                fontSize: 13,
                color: Colors.redAccent.shade100,
              ),
              UiSpacer.vSpace(16),
              TvFocusable(
                onTap: onRefresh,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white30, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      CustomAppText('Retry', color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox.expand(
      key: const ValueKey('qr_mode_netflix'),
      child: Stack(
        children: [
          // ── CENTER AREA: STEP 1 (QR) & STEP 2 (CODE) ───────────────
          Align(
            alignment: const Alignment(0.0, -0.2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── STEP 1: SCAN QR CODE ──────────────────────────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Step 1 Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStepBadge("1"),
                          const SizedBox(width: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  height: 1.4,
                                ),
                                children: [
                                  const TextSpan(
                                    text: "Use your phone or tablet's camera\nand point to this code, or go to\n",
                                  ),
                                  TextSpan(
                                    text: "app.paxtvlauncher.com/hotel/devices",
                                    style: TextStyle(
                                      color: Colors.amber.shade300,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // White Rounded QR Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.45),
                              blurRadius: 30,
                              spreadRadius: 2,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: qrUrl,
                          version: QrVersions.auto,
                          size: 190.0,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 80),

                  // ── STEP 2: CONFIRM CODE ──────────────────────────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Step 2 Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStepBadge("2"),
                          const SizedBox(width: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: const Text(
                              "Confirm this code on your phone or\ntablet",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Large Pairing Code (Netflix Style)
                      CustomAppText(
                        _formatCode(pairCode),
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4.0,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── BOTTOM-RIGHT (NETFLIX STYLE): SIGN UP & NEED HELP ─────────
          Positioned(
            bottom: 0,
            right: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Do not have an account?",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TvFocusable(
                  focusNode: signUpFocus,
                  onTap: onSignUpNow ?? () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.20),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      "Sign up now",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  "Need help signing in?",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.50),
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Visit ${AppConstants.helpUrl}",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
