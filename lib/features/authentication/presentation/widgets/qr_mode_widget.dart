import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/widget/custom_app_text.dart';
import '../../../../core/utils/ui_spacer.dart';

import '../../../../core/services/device/device_info_service.dart';

class QrModeWidget extends StatelessWidget {
  const QrModeWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: DeviceInfoService.getDeviceId(),
      builder: (context, snapshot) {
        final deviceId = snapshot.data ?? 'loading';
        return Column(
          key: const ValueKey('qr_mode'),
          children: [
            // White rounded QR container (always white for scanning contrast)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D856).withOpacity(0.25),
                    blurRadius: 25,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: QrImageView(
                data: '${AppConstants.qrSyncBaseUrl}$deviceId',
                version: QrVersions.auto,
                size: 125.0,
              ),
            ),
            UiSpacer.vSpace(12),
            // Helper text below QR
            const CustomAppText(
              AppText.scanQrInstruction,
              textAlign: TextAlign.center,
              fontSize: 14,
              height: 1.4,
            ),
          ],
        );
      },
    );
  }
}
