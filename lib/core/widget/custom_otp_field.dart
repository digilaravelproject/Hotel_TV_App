import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'custom_app_text.dart';

class CustomOtpField extends StatefulWidget {
  final int length;
  final bool isOutlined;
  final bool? isValid;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final Color? successColor;
  final Color? errorColor;
  final Color? backgroundColor;
  final Color? textColor;
  final double borderWidth;
  final double borderRadius;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  const CustomOtpField({
    Key? key,
    this.length = 4,
    this.isOutlined = true,
    this.isValid,
    this.borderColor,
    this.focusedBorderColor,
    this.successColor,
    this.errorColor,
    this.backgroundColor,
    this.textColor,
    this.borderWidth = 1.5,
    this.borderRadius = 20.0,
    required this.controller,
    this.validator,
    this.onChanged,
    this.onCompleted,
  }) : super(key: key);

  @override
  State<CustomOtpField> createState() => _CustomOtpFieldState();
}

class _CustomOtpFieldState extends State<CustomOtpField> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) {
      final node = FocusNode();
      node.addListener(() {
        setState(() {}); // focus change पर UI अपडेट
      });
      return node;
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // Border बनाने का function
  InputBorder _buildBorder({
    required bool isFocused,
    required bool isFilled,
    required ThemeData theme,
  }) {
    if (!widget.isOutlined) {
      // Filled mode rounded background
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        borderSide: BorderSide.none,
      );
    }

    final effectiveBorderColor = widget.borderColor ?? theme.dividerColor;
    final effectiveFocusedColor = widget.focusedBorderColor ?? theme.colorScheme.primary;
    final effectiveSuccessColor = widget.successColor ?? Colors.green;
    final effectiveErrorColor = widget.errorColor ?? theme.colorScheme.error;

    Color borderColor;
    if (widget.isValid == true) {
      borderColor = effectiveSuccessColor;
    } else if (widget.isValid == false) {
      borderColor = effectiveErrorColor;
    } else if (isFocused) {
      borderColor = effectiveFocusedColor;
    } else if (isFilled) {
      borderColor = effectiveFocusedColor.withOpacity(0.8);
    } else {
      borderColor = effectiveBorderColor;
    }

    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      borderSide: BorderSide(
        color: borderColor,
        width: isFocused ? widget.borderWidth + 0.5 : widget.borderWidth,
      ),
    );
  }

  // Decoration बनाने का function
  InputDecoration _buildDecoration(int index, ThemeData theme) {
    bool isFocused = _focusNodes[index].hasFocus;
    bool isFilled = _controllers[index].text.isNotEmpty;

    final isDark = theme.brightness == Brightness.dark;
    final effectiveFocusedColor = widget.focusedBorderColor ?? theme.colorScheme.primary;
    final effectiveSuccessColor = widget.successColor ?? Colors.green;
    final effectiveErrorColor = widget.errorColor ?? theme.colorScheme.error;

    Color fillColor = widget.backgroundColor ??
        (isDark ? theme.cardColor : Colors.grey.shade200);

    if (widget.isValid == true) {
      fillColor = effectiveSuccessColor.withOpacity(0.15);
    } else if (widget.isValid == false) {
      fillColor = effectiveErrorColor.withOpacity(0.15);
    } else if (isFocused || isFilled) {
      fillColor = effectiveFocusedColor.withOpacity(0.15);
    }

    return InputDecoration(
      contentPadding: EdgeInsets.zero,
      filled: !widget.isOutlined, // ✅ Outlined mode me false
      fillColor: !widget.isOutlined ? fillColor : null, // ✅ Sirf filled mode me color
      enabledBorder: _buildBorder(isFocused: false, isFilled: isFilled, theme: theme),
      focusedBorder: _buildBorder(isFocused: true, isFilled: isFilled, theme: theme),
      border: _buildBorder(isFocused: false, isFilled: isFilled, theme: theme),
    );
  }

  // Main controller text update
  void _updateMainController() {
    widget.controller.text = _controllers.map((c) => c.text).join();
    widget.onChanged?.call(widget.controller.text);

    if (widget.controller.text.length == widget.length &&
        !widget.controller.text.contains(' ')) {
      widget.onCompleted?.call(widget.controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveTextColor = widget.textColor ?? theme.textTheme.bodyLarge?.color ?? Colors.black;

    return FormField<String>(
      validator: widget.validator,
      builder: (fieldState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(widget.length, (index) {
                return SizedBox(
                  width: 55,
                  height: 60,
                  child: RawKeyboardListener(
                    focusNode: FocusNode(),
                    onKey: (event) {
                      if (event.isKeyPressed(LogicalKeyboardKey.backspace) &&
                          _controllers[index].text.isEmpty &&
                          index > 0) {
                        _focusNodes[index - 1].requestFocus();
                        _controllers[index - 1].clear();
                        _updateMainController();
                      }
                    },
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      showCursor: false, // caret hide
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: effectiveTextColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(1),
                      ],
                      decoration: _buildDecoration(index, theme),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < widget.length - 1) {
                          _focusNodes[index + 1].requestFocus();
                        }
                        _updateMainController();
                      },
                    ),
                  ),
                );
              }),
            ),
            if (fieldState.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: CustomAppText(
                  fieldState.errorText!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
