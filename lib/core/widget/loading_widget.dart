import 'package:flutter/material.dart';

enum LoadingType { indicator, fullScreen, overlay }

class LoadingWidget extends StatelessWidget {
  final Color? color;
  final double? size;
  final double? strokeWidth;
  final LoadingType type;

  const LoadingWidget({
    Key? key,
    this.color,
    this.size,
    this.strokeWidth,
    this.type = LoadingType.indicator,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case LoadingType.fullScreen:
        return _buildFullScreen(context);
      case LoadingType.overlay:
        return _buildOverlay(context);
      case LoadingType.indicator:
      default:
        return _buildIndicator(context);
    }
  }

  Widget _buildIndicator(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SizedBox(
        width: size ?? 40,
        height: size ?? 40,
        child: CircularProgressIndicator(
          color: color ?? theme.colorScheme.primary,
          strokeWidth: strokeWidth ?? 3,
        ),
      ),
    );
  }

  Widget _buildFullScreen(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: _buildIndicator(context),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Opacity(
          opacity: 0.3,
          child: ModalBarrier(
            dismissible: false,
            color: isDark ? Colors.black : Colors.white,
          ),
        ),
        Center(child: _buildIndicator(context)),
      ],
    );
  }
}
