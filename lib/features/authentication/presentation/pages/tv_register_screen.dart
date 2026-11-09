import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widget/custom_app_text.dart';
import '../../../../core/widget/custom_base_widget.dart';
import '../../../../core/widget/tv_focusable.dart';
import '../../../../core/services/device/device_info_service.dart';
import '../../../../core/widget/tv_network_status_header.dart';

class TvRegisterScreen extends StatefulWidget {
  const TvRegisterScreen({Key? key}) : super(key: key);

  @override
  State<TvRegisterScreen> createState() => _TvRegisterScreenState();
}

class _TvRegisterScreenState extends State<TvRegisterScreen> {
  late final FocusNode backButtonFocus;

  @override
  void initState() {
    super.initState();
    backButtonFocus = FocusNode();
  }

  @override
  void dispose() {
    backButtonFocus.dispose();
    super.dispose();
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

  Widget _buildStepGuideItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: 330,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.amber.shade300, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.60),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final registerUrlWithoutScheme =
        AppConstants.hotelRegisterUrl.replaceAll('https://', '');

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.goBack ||
              event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(context);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: CustomBaseWidget(
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

              // Top Left Branding
              Positioned(
                top: 20,
                left: 36,
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 10),
                    const CustomAppText(
                      AppConstants.appName,
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ],
                ),
              ),

              // Top Right Network Header
              Positioned(
                top: 20,
                right: 36,
                child: const TvNetworkStatusHeader(),
              ),

              // Main Content Area (Netflix 2-Column Style)
              Positioned.fill(
                top: 48,
                bottom: 36,
                left: 36,
                right: 36,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Center Title
                    const CustomAppText(
                      "Register Your Property",
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                    const SizedBox(height: 6),

                    // Subtitle
                    Text(
                      "Follow these simple steps on your phone or computer to sign up your hotel",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.70),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 2-Column Netflix-Style Layout
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // ── PART 1: SCAN QR CODE ────────────────
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
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
                                                text: registerUrlWithoutScheme,
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
                                      data: AppConstants.hotelRegisterUrl,
                                      version: QrVersions.auto,
                                      size: 190.0,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(width: 70),

                              // ── PART 2: SIGN UP ON PHONE & RETURN ──
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildStepBadge("2"),
                                      const SizedBox(width: 12),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 340),
                                        child: const Text(
                                          "Complete hotel registration on your\nphone or computer",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13.5,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),

                                  // 3 Step Guide Cards
                                  _buildStepGuideItem(
                                    icon: Icons.hotel_rounded,
                                    title: "Register Property Account",
                                    subtitle: "Enter property name, manager name & email",
                                  ),
                                  const SizedBox(height: 10),
                                  _buildStepGuideItem(
                                    icon: Icons.key_rounded,
                                    title: "Receive TV License Key",
                                    subtitle: "Get your activation key for this room",
                                  ),
                                  const SizedBox(height: 10),
                                  _buildStepGuideItem(
                                    icon: Icons.tv_rounded,
                                    title: "Sign In on TV",
                                    subtitle: "Enter key under Use Remote or pair with phone",
                                  ),
                                  const SizedBox(height: 22),

                                  // TV Focusable Back Button (Compact & Simple)
                                  TvFocusable(
                                    focusNode: backButtonFocus,
                                    autofocus: true,
                                    scaleFactor: 1.03,
                                    onTap: () => Navigator.pop(context),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6.5),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.20),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.arrow_back_rounded, color: Colors.white, size: 13),
                                          SizedBox(width: 6),
                                          Text(
                                            "Back to Sign In",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
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

              // Bottom Left Device ID Badge
              Positioned(
                bottom: 16,
                left: 36,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CustomAppText(
                        "Device ID: ",
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                      FutureBuilder<String>(
                        future: DeviceInfoService.getDeviceId(),
                        builder: (context, snapshot) {
                          return CustomAppText(
                            snapshot.data ?? '...',
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Right Need Help Link
              Positioned(
                bottom: 16,
                right: 36,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Need help registering?",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.50),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Visit ${AppConstants.helpUrl}",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
