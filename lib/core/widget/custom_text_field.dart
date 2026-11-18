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
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField>
    with WidgetsBindingObserver {
  bool _isEditing = false;
  late final FocusNode _effectiveFocusNode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _effectiveFocusNode = widget.focusNode ?? FocusNode();
    _effectiveFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.focusNode == null) {
      _effectiveFocusNode.dispose();
    } else {
      _effectiveFocusNode.removeListener(_handleFocusChange);
    }
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_effectiveFocusNode.hasFocus && _isEditing) {
      setState(() => _isEditing = false);
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // When the soft keyboard is dismissed (e.g. Back button pressed on remote),
    // bottom viewInsets becomes 0. Exit editing mode so D-pad navigation resumes.
    final bottomInset = View.of(context).viewInsets.bottom;
    if (bottomInset == 0 && _isEditing) {
      setState(() => _isEditing = false);
    }
  }

  void _startEditing() {
    if (!_isEditing) {
      setState(() => _isEditing = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SystemChannels.textInput.invokeMethod('TextInput.show');
      });
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
      return Focus(
        canRequestFocus: false,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            // When field is focused but not editing, pressing OK / Select / Enter enters editing mode
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
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 13,
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
      );
    }

    return AnimatedBuilder(
      animation: _effectiveFocusNode,
      builder: (context, _) => buildField(_effectiveFocusNode.hasFocus),
    );
  }
}
