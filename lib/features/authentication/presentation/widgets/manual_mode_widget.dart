import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/widget/tv_focusable.dart';
import '../../../../core/widget/custom_text_field.dart';
import '../../../../core/widget/custom_app_text.dart';
import '../../../../core/widget/custom_button.dart';
import '../../../../core/utils/ui_spacer.dart';

class _TvFocusIntent extends Intent {
  const _TvFocusIntent(this.direction);
  final int direction; // -1: up, 1: down
}

class _TvFocusAction extends Action<_TvFocusIntent> {
  _TvFocusAction({required this.onInvoke});
  final void Function(int direction) onInvoke;

  @override
  void invoke(_TvFocusIntent intent) {
    onInvoke(intent.direction);
  }
}

class ManualModeWidget extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController licenseKeyController;
  final TextEditingController roomNoController;
  final FocusNode licenseKeyFocus;
  final FocusNode roomNoFocus;
  final FocusNode submitFocus;
  final VoidCallback onSaveAndStart;

  const ManualModeWidget({
    Key? key,
    required this.formKey,
    required this.licenseKeyController,
    required this.roomNoController,
    required this.licenseKeyFocus,
    required this.roomNoFocus,
    required this.submitFocus,
    required this.onSaveAndStart,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final tvFocusActions = Actions(
      actions: {
        _TvFocusIntent: _TvFocusAction(
          onInvoke: (direction) {
            if (direction == 1) {
              FocusScope.of(context).nextFocus();
            } else {
              FocusScope.of(context).previousFocus();
            }
          },
        ),
      },
      child: Container(
        key: const ValueKey('manual_mode'),
        width: 280,
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CustomAppText(
                AppText.manualInstruction,
                fontSize: 12,
                height: 1.4,
              ),
              UiSpacer.vSpace(16),

              // Hotel ID
              Shortcuts(
                shortcuts: {
                  LogicalKeySet(LogicalKeyboardKey.arrowDown): const _TvFocusIntent(1),
                  LogicalKeySet(LogicalKeyboardKey.arrowUp): const _TvFocusIntent(-1),
                },
                child: CustomTextField(
                  controller: licenseKeyController,
                  focusNode: licenseKeyFocus,
                  hintText: AppText.hotelIdHint,
                  borderColor: theme.dividerColor,
                  borderRadius: 8,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return AppText.requiredFieldValidation;
                    }
                    return null;
                  },
                ),
              ),
              UiSpacer.vSpace(16),

              // Room No
              Shortcuts(
                shortcuts: {
                  LogicalKeySet(LogicalKeyboardKey.arrowDown): const _TvFocusIntent(1),
                  LogicalKeySet(LogicalKeyboardKey.arrowUp): const _TvFocusIntent(-1),
                },
                child: CustomTextField(
                  controller: roomNoController,
                  focusNode: roomNoFocus,
                  hintText: AppText.roomNoHint,
                  borderColor: theme.dividerColor,
                  borderRadius: 8,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return AppText.requiredFieldValidation;
                    }
                    return null;
                  },
                ),
              ),
              UiSpacer.vSpace(22),

              // Save & Start Button
              Shortcuts(
                shortcuts: {
                  LogicalKeySet(LogicalKeyboardKey.arrowUp): const _TvFocusIntent(-1),
                },
                child: SizedBox(
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
                          Color(0xFF6366F1), // Purple
                          Color(0xFF3B82F6), // Blue
                        ],
                      ),
                      textColor: Colors.white,
                      borderRadius: 8,
                      height: 40,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return tvFocusActions;
  }
}
