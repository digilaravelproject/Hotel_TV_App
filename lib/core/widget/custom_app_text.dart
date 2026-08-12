import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum TextTransform {
  none,
  uppercase,
  lowercase,
  capitalize,
  capitalizeEachWord,
}

class CustomAppText extends StatelessWidget {
  final String text;

  /// Direct TextStyle
  final TextStyle? style;

  // Style overrides
  final double? fontSize;
  final FontWeight? fontWeight;
  final FontStyle? fontStyle;
  final Color? color;
  final String? fontFamily;
  final double? letterSpacing;
  final double? height;
  final List<Shadow>? shadows;
  final TextDecoration? decoration;

  // Layout
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool softWrap;
  final double? textScaleFactor;

  // Behavior
  final VoidCallback? onTap;
  final bool selectable;
  final TextTransform transform;

  const CustomAppText(
      this.text, {
        super.key,
        this.style,
        this.fontSize,
        this.fontWeight,
        this.fontStyle,
        this.color,
        this.fontFamily,
        this.letterSpacing,
        this.height,
        this.shadows,
        this.decoration,
        this.textAlign,
        this.maxLines,
        this.overflow,
        this.softWrap = true,
        this.textScaleFactor,
        this.onTap,
        this.selectable = false,
        this.transform = TextTransform.none,
      });

  String _applyTransform(String value) {
    switch (transform) {
      case TextTransform.uppercase:
        return value.toUpperCase();
      case TextTransform.lowercase:
        return value.toLowerCase();
      case TextTransform.capitalize:
        if (value.isEmpty) return value;
        return value[0].toUpperCase() + value.substring(1).toLowerCase();
      case TextTransform.capitalizeEachWord:
        return value
            .split(' ')
            .map((e) => e.isEmpty
            ? e
            : e[0].toUpperCase() + e.substring(1).toLowerCase())
            .join(' ');
      case TextTransform.none:
      default:
        return value;
    }
  }

  TextStyle _buildStyle(BuildContext context) {
    final base =
        style ?? Theme.of(context).textTheme.bodyMedium ?? GoogleFonts.poppins(fontWeight: FontWeight.w400);

    return GoogleFonts.poppins(
      fontSize: fontSize ?? base.fontSize,
      fontWeight: fontWeight ?? FontWeight.w400,
      fontStyle: fontStyle ?? base.fontStyle,
      color: color ?? base.color,
      letterSpacing: letterSpacing ?? base.letterSpacing,
      height: height ?? base.height,
      decoration: decoration ?? base.decoration,
      shadows: shadows ?? base.shadows,
    );
  }

  @override
  Widget build(BuildContext context) {
    String finalText = _applyTransform(text);

    // 3. Build text style
    final textStyle = _buildStyle(context);

    // 4. Selectable or normal text
    final widget = selectable
        ? SelectableText(
      finalText,
      style: textStyle,
      textAlign: textAlign,
      maxLines: maxLines,
    )
        : Text(
      finalText,
      style: textStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      textScaleFactor: textScaleFactor,
    );

    // 5. Gesture
    return onTap != null ? GestureDetector(onTap: onTap, child: widget) : widget;
  }

}
