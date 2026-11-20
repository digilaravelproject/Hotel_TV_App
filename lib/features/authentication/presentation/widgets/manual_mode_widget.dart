import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/widget/tv_focusable.dart';
import '../../../../core/widget/custom_text_field.dart';
import '../../../../core/widget/custom_app_text.dart';
import '../../../../core/utils/ui_spacer.dart';

class ManualModeWidget extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController licenseKeyController;
  final TextEditingController roomNoController;
  final FocusNode licenseKeyFocus;
  final FocusNode roomNoFocus;
  final FocusNode submitFocus;
  final FocusNode manualTabFocus;
  final VoidCallback onSaveAndStart;

  const ManualModeWidget({
    Key? key,
    required this.formKey,
    required this.licenseKeyController,
    required this.roomNoController,
    required this.licenseKeyFocus,
    required this.roomNoFocus,
    required this.submitFocus,
    required this.manualTabFocus,
    required this.onSaveAndStart,
  }) : super(key: key);

  Widget _buildStepBadge(String text) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.amber.shade300.withOpacity(0.18),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.amber.shade300.withOpacity(0.60),
          width: 1.4,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.amber.shade300,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
          width: 0.9,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.amber.shade300, size: 20),
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
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 12.5,
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

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          key: const ValueKey('manual_mode'),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── LEFT COLUMN: REGISTRATION INSTRUCTIONS ───────────
              SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Step Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStepBadge("i"),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Need to register your hotel?",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.75),
                                    fontSize: 13.5,
                                    height: 1.4,
                                  ),
                                  children: [
                                    const TextSpan(text: "Visit "),
                                    TextSpan(
                                      text: registerUrlWithoutScheme,
                                      style: TextStyle(
                                        color: Colors.amber.shade300,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 3 Step Guide Cards
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStepCard(
                          icon: Icons.hotel_rounded,
                          title: "1. Register Hotel Account",
                          subtitle: "Enter hotel name, manager name & email",
                        ),
                        const SizedBox(height: 10),
                        _buildStepCard(
                          icon: Icons.key_rounded,
                          title: "2. Receive TV License Key",
                          subtitle: "Get your activation key for this room",
                        ),
                        const SizedBox(height: 10),
                        _buildStepCard(
                          icon: Icons.tv_rounded,
                          title: "3. Sign In on TV",
                          subtitle: "Enter key under Use Remote on the right",
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── VERTICAL DIVIDER ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Container(
                  width: 1,
                  height: 280,
                  color: Colors.white.withOpacity(0.12),
                ),
              ),

              // ── RIGHT COLUMN: MANUAL INPUT FORM ───────────────────
              SizedBox(
                width: 360,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CustomAppText(
                        AppText.manualInstruction,
                        fontSize: 14.5,
                        height: 1.4,
                      ),
                      UiSpacer.vSpace(16),

                      // Hotel ID / License Key field
                      CustomTextField(
                        controller: licenseKeyController,
                        focusNode: licenseKeyFocus,
                        hintText: AppText.hotelIdHint,
                        borderRadius: 14,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                        textStyle: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 15.5),
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => roomNoFocus.requestFocus(),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return AppText.requiredFieldValidation;
                          }
                          return null;
                        },
                      ),
                      UiSpacer.vSpace(14),

                      // Room No field
                      CustomTextField(
                        controller: roomNoController,
                        focusNode: roomNoFocus,
                        hintText: AppText.roomNoHint,
                        borderRadius: 14,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                        textStyle: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 15.5),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => submitFocus.requestFocus(),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return AppText.requiredFieldValidation;
                          }
                          return null;
                        },
                      ),
                      UiSpacer.vSpace(18),

                      // Confirm button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: TvFocusable(
                          focusNode: submitFocus,
                          scaleFactor: 1.03,
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent) {
                              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                roomNoFocus.requestFocus();
                                return KeyEventResult.handled;
                              }
                            }
                            return KeyEventResult.ignored;
                          },
                          onTap: onSaveAndStart,
                          child: Container(
                            height: 50,
                            width: double.infinity,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.2),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const CustomAppText(
                              'Confirm',
                              color: Colors.black,
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
