import 'package:flutter/material.dart';
import '../constants/dimensions.dart';
import '../utils/ui_spacer.dart';
import 'custom_app_text.dart';
import 'custom_button.dart';

class RetryWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final IconData icon;
  final double? iconSize;
  final Color? iconColor;
  final Color? textColor;
  final String retryText;

  const RetryWidget({
    Key? key,
    required this.message,
    required this.onRetry,
    this.icon = Icons.error_outline,
    this.iconSize,
    this.iconColor,
    this.textColor,
    this.retryText = 'Retry',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: Dimensions.width20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: iconSize ?? Dimensions.iconSize32 * 2, // 64sp equivalent
              color:
                  iconColor ??
                  (isDark
                      ? theme.colorScheme.error.withOpacity(0.7)
                      : theme.colorScheme.error.withOpacity(0.8)),
            ),
            UiSpacer.verticalSpace(),
            CustomAppText(
              message,
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.bodyLarge?.copyWith(
                    fontSize: Dimensions.font16,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ) ??
                  TextStyle(
                    fontSize: Dimensions.font16,
                    color:
                        textColor ??
                        theme.textTheme.bodyLarge?.color?.withOpacity(0.87),
                    fontWeight: FontWeight.w500,
                  ),
            ),
            UiSpacer.verticalSpace(),
            CustomButton(text: retryText, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
