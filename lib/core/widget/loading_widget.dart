import 'package:flutter/material.dart';

enum LoadingType { indicator, fullScreen, overlay, tvScreen }

class LoadingWidget extends StatelessWidget {
  final Color? color;
  final double? size;
  final double? strokeWidth;
  final LoadingType type;
  final String? title;
  final String? subtitle;

  const LoadingWidget({
    Key? key,
    this.color,
    this.size,
    this.strokeWidth,
    this.type = LoadingType.indicator,
    this.title,
    this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case LoadingType.fullScreen:
        return _buildFullScreen(context);
      case LoadingType.overlay:
        return _buildOverlay(context);
      case LoadingType.tvScreen:
        return _buildTvScreen(context);
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

  Widget _buildTvScreen(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size ?? 80,
              height: size ?? 80,
              child: CircularProgressIndicator(
                color: color ?? const Color(0xFF6366F1),
                strokeWidth: strokeWidth ?? 6,
              ),
            ),
            if (title != null) ...[
              const SizedBox(height: 32),
              Text(
                title!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 18,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
