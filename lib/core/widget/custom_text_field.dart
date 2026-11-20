import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextField extends StatefulWidget {
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
  final TextStyle? hintStyle;
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
    this.hintStyle,
    this.contentPadding,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.enabled = true,
    this.focusNode,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _isEditing = false;
  late final FocusNode _effectiveFocusNode;

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _effectiveFocusNode.dispose();
    }
    super.dispose();
  }

  void _startEditing() {
    if (!_isEditing) {
      setState(() => _isEditing = true);
    }
  }

  void _stopEditing() {
    if (_isEditing) {
      setState(() => _isEditing = false);
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget buildField(bool isFocused) {
      return PopScope(
        canPop: !_isEditing,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _isEditing) {
            _stopEditing();
          }
        },
        child: Focus(
          canRequestFocus: false,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              // Remote Back button closes editing mode
              if (_isEditing &&
                  (event.logicalKey == LogicalKeyboardKey.escape ||
                      event.logicalKey == LogicalKeyboardKey.goBack)) {
                _stopEditing();
                return KeyEventResult.handled;
              }

              // When selected via D-pad navigation, pressing OK / Select / Enter enters editing mode
              if (!_isEditing &&
                  (event.logicalKey == LogicalKeyboardKey.select ||
                      event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.space)) {
                _startEditing();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: Colors.amber.shade400.withOpacity(0.35),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: TextFormField(
              controller: widget.controller,
              focusNode: _effectiveFocusNode,
              keyboardType: widget.keyboardType,
              enabled: widget.enabled,
              readOnly: !_isEditing,
              showCursor: _isEditing,
              onTap: _startEditing,
              textInputAction: widget.textInputAction,
              onFieldSubmitted: (value) {
                _stopEditing();
                widget.onFieldSubmitted?.call(value);
              },
              style: widget.textStyle ?? theme.textTheme.bodyLarge,
              obscureText: widget.obscureText,
              textCapitalization: TextCapitalization.none,
              onChanged: (value) {
                if (value.isEmpty) return;

                final capitalized =
                    value[0].toUpperCase() + value.substring(1);

                if (capitalized != value) {
                  widget.controller.value = widget.controller.value.copyWith(
                    text: capitalized,
                    selection:
                        TextSelection.collapsed(offset: capitalized.length),
                  );
                }

                widget.onChanged?.call(capitalized);
              },
              maxLength: widget.maxLength,
              validator: widget.validator,
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: widget.hintStyle ??
                    TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: widget.textStyle?.fontSize ?? 15,
                    ),
                labelText: widget.labelText,
                prefixIcon: widget.prefixIcon,
                suffixIcon: widget.suffixIcon,
                counterText: "",
                contentPadding: widget.contentPadding ??
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isFocused
                        ? Colors.amber.shade300
                        : Colors.white.withOpacity(0.12),
                    width: isFocused ? 2.2 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.amber.shade300,
                    width: 2.2,
                  ),
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                ),
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.error,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.error,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                ),
                filled: true,
                fillColor: isFocused
                    ? Colors.white.withOpacity(0.12)
                    : Colors.white.withOpacity(0.06),
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _effectiveFocusNode,
      builder: (context, _) => buildField(_effectiveFocusNode.hasFocus),
    );
  }
}
