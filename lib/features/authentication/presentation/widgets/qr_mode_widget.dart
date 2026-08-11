import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/widget/custom_app_text.dart';
import '../../../../core/utils/ui_spacer.dart';

class QrModeWidget extends StatelessWidget {
  final String pairCode;
  final int remainingSeconds;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRefresh;

  const QrModeWidget({
    Key? key,
    required this.pairCode,
    required this.remainingSeconds,
    required this.isLoading,
    this.errorMessage,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final qrUrl = 'https://tvapp.digiemperor.com/hotel/devices?code=$pairCode';

    if (isLoading) {
      return Column(
        key: const ValueKey('qr_mode_loading'),
        children: [
          const SizedBox(height: 30),
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
          ),
          UiSpacer.vSpace(16),
          const CustomAppText(
            "Generating Pairing Code...",
            textAlign: TextAlign.center,
            fontSize: 13,
            color: Colors.white70,
          ),
          const SizedBox(height: 30),
        ],
      );
    }

    if (errorMessage != null && pairCode.isEmpty) {
      return Column(
        key: const ValueKey('qr_mode_error'),
        children: [
          const SizedBox(height: 20),
          Icon(Icons.error_outline, color: Colors.redAccent.shade100, size: 36),
          UiSpacer.vSpace(8),
          CustomAppText(
            errorMessage!,
            textAlign: TextAlign.center,
            fontSize: 12,
            color: Colors.redAccent.shade100,
          ),
          UiSpacer.vSpace(12),
          TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
            label: const CustomAppText('Retry', color: Colors.white, fontSize: 13),
          ),
        ],
      );
    }

    return Column(
      key: const ValueKey('qr_mode'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Large White rounded QR container with sleek glow
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
                spreadRadius: 2,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: QrImageView(
            data: pairCode.isNotEmpty ? qrUrl : 'https://tvapp.digiemperor.com/hotel/devices',
            version: QrVersions.auto,
            size: 230.0,
          ),
        ),
        UiSpacer.vSpace(20),

        // Pairing Code Pill / Instruction Badge (YouTube TV Compact Style)
        if (pairCode.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626), // YouTube Accent Red
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDC2626).withOpacity(0.35),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CustomAppText(
                  "Scan with your phone or enter code:",
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                ),
                const SizedBox(height: 2),
                CustomAppText(
                  pairCode,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.0,
                  color: Colors.white,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

