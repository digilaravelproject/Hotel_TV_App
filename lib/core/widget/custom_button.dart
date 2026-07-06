import 'package:flutter/material.dart';

import '../constants/dimensions.dart';
import 'custom_app_text.dart';

enum ButtonStyleType { filled, outlined, text, gradient }
enum GradientButtonType { filled, outlined, text }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final TextStyle? textStyle;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ButtonStyleType buttonType;
  final Color? borderColor;

  /// Gradient options
  final Gradient? gradient;
  final GradientButtonType? gradientType;

  const CustomButton({
    super.key,
    required this.text,
     this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
    this.borderRadius,
    this.padding,
    this.textStyle,
    this.prefixIcon,
    this.suffixIcon,
    this.buttonType = ButtonStyleType.filled,
    this.borderColor,
    this.gradient,
    this.gradientType,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius ?? Dimensions.radius8);
    final theme = Theme.of(context);

    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? Dimensions.buttonHeight,
      child: ElevatedButton(
        focusNode: FocusNode(skipTraversal: true),
        onPressed: isLoading ? null : onPressed,
        style: _getButtonStyle(radius, theme),
        child: isLoading
            ? SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: _getLoadingColor(theme),
          ),
        )
            : _buildChild(radius, theme),
      ),
    );
  }

  /// Get loading indicator color based on button type
  Color _getLoadingColor(ThemeData theme) {
    if (buttonType == ButtonStyleType.outlined || buttonType == ButtonStyleType.text) {
      return theme.colorScheme.primary;
    }
    return Colors.white;
  }

  /// child widget (normal / gradient variations)
  Widget _buildChild(BorderRadius radius, ThemeData theme) {
    if (buttonType == ButtonStyleType.gradient) {
      final mode = gradientType ?? GradientButtonType.filled;
      final g = gradient ??
          LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withOpacity(0.7),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );

      switch (mode) {
        case GradientButtonType.filled:
          return Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: g,
            ),
            child: Center(
              child: CustomAppText(
                text,
                style: textStyle ??
                    TextStyle(
                      color: textColor ?? Colors.white,
                      fontSize: Dimensions.font16,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          );

        case GradientButtonType.outlined:
          return Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(width: 2, color: Colors.transparent),
            ),
            child: Center(
              child: ShaderMask(
                shaderCallback: (bounds) => g.createShader(bounds),
                child: CustomAppText(
                  text,
                  style: textStyle ??
                      TextStyle(
                        fontSize: Dimensions.font16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white, // masked by shader
                      ),
                ),
              ),
            ),
          );

        case GradientButtonType.text:
          return Center(
            child: ShaderMask(
              shaderCallback: (bounds) => g.createShader(bounds),
              child: CustomAppText(
                text,
                style: textStyle ??
                    TextStyle(
                      fontSize: Dimensions.font16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white, // masked by shader
                    ),
              ),
            ),
          );
      }
    }

    // normal (filled / outlined / text)
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (prefixIcon != null) ...[
          prefixIcon!,
          SizedBox(width: Dimensions.width10),
        ],
        Flexible(
          child: CustomAppText(
            text,
            style: textStyle ??
                TextStyle(
                  color: _getTextColor(theme),
                  fontSize: Dimensions.font16,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        if (suffixIcon != null) ...[
          SizedBox(width: Dimensions.width10),
          suffixIcon!,
        ],
      ],
    );
  }

  /// text color based on theme
  Color _getTextColor(ThemeData theme) {
    if (textColor != null) return textColor!;
    return switch (buttonType) {
      ButtonStyleType.outlined || ButtonStyleType.text => theme.colorScheme.primary,
      _ => Colors.white,
    };
  }

  /// button style with theme support
  ButtonStyle _getButtonStyle(BorderRadius radius, ThemeData theme) {
    final base = ElevatedButton.styleFrom(
      padding: padding ?? EdgeInsets.symmetric(vertical: Dimensions.height15),
      shape: RoundedRectangleBorder(borderRadius: radius),
    );

    return switch (buttonType) {
      ButtonStyleType.outlined => base.copyWith(
        elevation: MaterialStateProperty.all(0),
        backgroundColor: MaterialStateProperty.all(Colors.transparent),
        side: MaterialStateProperty.all(
          BorderSide(
            color: borderColor ?? theme.colorScheme.primary,
            width: 1.5,
          ),
        ),
        foregroundColor: MaterialStateProperty.all(
          textColor ?? theme.colorScheme.primary,
        ),
      ),
      ButtonStyleType.text => base.copyWith(
        elevation: MaterialStateProperty.all(0),
        backgroundColor: MaterialStateProperty.all(Colors.transparent),
        foregroundColor: MaterialStateProperty.all(
          textColor ?? theme.colorScheme.primary,
        ),
      ),
      ButtonStyleType.gradient => base.copyWith(
        padding: MaterialStateProperty.all(EdgeInsets.zero),
        backgroundColor: MaterialStateProperty.all(Colors.transparent),
        shadowColor: MaterialStateProperty.all(Colors.black54),
        elevation: MaterialStateProperty.all(6),
      ),
      _ => base.copyWith(
        backgroundColor: MaterialStateProperty.resolveWith((states) =>
        states.contains(MaterialState.disabled)
            ? (backgroundColor ?? theme.colorScheme.primary).withOpacity(0.6)
            : backgroundColor ?? theme.colorScheme.primary),
        foregroundColor: MaterialStateProperty.all(textColor ?? Colors.white),
      ),
    };
  }
}
