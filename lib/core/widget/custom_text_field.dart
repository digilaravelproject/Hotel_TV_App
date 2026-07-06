import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;

  /// Text
  final String hintText;
  final String? labelText;

  /// UI
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final int? maxLength;
  final bool obscureText;
  final Color? borderColor;
  final double borderRadius;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? contentPadding;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  /// Validation
  final String? Function(String?)? validator;
  final Function(String)? onChanged;
  final bool enabled;
  final FocusNode? focusNode;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.maxLength,
    this.obscureText = false,
    this.borderColor,
    this.borderRadius = 12,
    this.textStyle,
    this.contentPadding,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.enabled = true,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveBorderColor = borderColor ?? theme.colorScheme.primary;

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      enabled: enabled,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      style: textStyle ?? theme.textTheme.bodyLarge,
      obscureText: obscureText,
      textCapitalization: TextCapitalization.none,
      onChanged: (value) {
        if (value.isEmpty) return;

        final capitalized =
            value[0].toUpperCase() + value.substring(1);

        if (capitalized != value) {
          controller.value = controller.value.copyWith(
            text: capitalized,
            selection: TextSelection.collapsed(offset: capitalized.length),
          );
        }

        onChanged?.call(capitalized);
      },
      maxLength: maxLength,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        counterText: "",
        contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: isDark
                ? theme.dividerColor
                : effectiveBorderColor.withOpacity(0.5),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Colors.amber.shade700,
            width: 3.0,
          ),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: theme.colorScheme.error,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: theme.colorScheme.error,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        filled: true,
        fillColor: theme.inputDecorationTheme.fillColor ??
            (isDark ? theme.cardColor : Colors.white),
      ),
    );
  }
}
