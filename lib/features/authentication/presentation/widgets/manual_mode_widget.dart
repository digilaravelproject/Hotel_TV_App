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
                borderColor: theme.dividerColor,
                borderRadius: 8,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: TextStyle(color: colorScheme.onSurface, fontSize: 13),
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
                borderColor: theme.dividerColor,
                borderRadius: 8,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: TextStyle(color: colorScheme.onSurface, fontSize: 13),
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

              // Save & Start button
              // Navigation handled via submitFocus.onKey in tv_login_screen.dart
              SizedBox(
                width: double.infinity,
                height: 40,
                child: TvFocusable(
                  focusNode: submitFocus,
                  scaleFactor: 1.04,
                  onTap: onSaveAndStart,
                  child: CustomButton(
                    text: AppText.saveAndStart,
                    onPressed: onSaveAndStart,
                    buttonType: ButtonStyleType.gradient,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF6366F1),
                        Color(0xFF3B82F6),
                      ],
                    ),
                    textColor: Colors.white,
                    borderRadius: 8,
                    height: 40,
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
