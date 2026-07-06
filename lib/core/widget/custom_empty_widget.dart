import 'package:flutter/material.dart';

import '../utils/ui_spacer.dart';
import 'custom_app_text.dart';
import 'custom_button.dart';

class CustomEmptyWidget extends StatelessWidget {
  final IconData icon;
  final String message;
  final double iconSize;
  final Color? iconColor;
  final Color? textColor;
  final double spacing;
  final bool showBackButton;

  const CustomEmptyWidget({
    Key? key,
    required this.icon,
    required this.message,
    this.iconSize = 64,
    this.iconColor,
    this.textColor,
    this.spacing = 16,
    this.showBackButton = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: iconSize,
            color: iconColor ??
                (isDark
                    ? theme.colorScheme.onSurface.withOpacity(0.3)
                    : Colors.grey[400]),
          ),
          SizedBox(height: spacing),
          CustomAppText(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 18,
              color: textColor ??
                  (isDark
                      ? theme.colorScheme.onSurface.withOpacity(0.5)
                      : Colors.grey[600]),
            ),
          ),
          UiSpacer.verticalSpace(),
           if(showBackButton)
           CustomButton(
              width: 100,
              height: 45,
              borderRadius: 50,
              text: "Back", onPressed: () {
            Navigator.pop(context);
          }),
        ],
      ),
    );
  }
}
