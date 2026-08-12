import 'package:flutter/material.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/widget/tv_focusable.dart';
import '../../../../core/widget/custom_text_field.dart';
import '../../../../core/widget/custom_app_text.dart';
import '../../../../core/widget/custom_button.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Container(
        key: const ValueKey('manual_mode'),
        width: 320,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CustomAppText(
                AppText.manualInstruction,
                fontSize: 12,
                height: 1.4,
              ),
              UiSpacer.vSpace(16),

              // Hotel ID / License Key field
              // Navigation handled via licenseKeyFocus.onKey (D-Pad) + onFieldSubmitted (keyboard Enter/Next)
              CustomTextField(
                controller: licenseKeyController,
                focusNode: licenseKeyFocus,
                hintText: AppText.hotelIdHint,
                borderRadius: 14,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                textStyle: const TextStyle(color: Colors.white, fontSize: 13.5),
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => roomNoFocus.requestFocus(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return AppText.requiredFieldValidation;
                  }
                  return null;
                },
              ),
              UiSpacer.vSpace(16),

              // Room No field
              // Navigation handled via roomNoFocus.onKey (D-Pad) + onFieldSubmitted (keyboard Enter/Done)
              CustomTextField(
                controller: roomNoController,
                focusNode: roomNoFocus,
                hintText: AppText.roomNoHint,
                borderRadius: 14,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                textStyle: const TextStyle(color: Colors.white, fontSize: 13.5),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => submitFocus.requestFocus(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return AppText.requiredFieldValidation;
                  }
                  return null;
                },
              ),
              UiSpacer.vSpace(22),

              // Confirm button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TvFocusable(
                  focusNode: submitFocus,
                  scaleFactor: 1.03,
                  onTap: onSaveAndStart,
                  child: Container(
                    height: 48,
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
