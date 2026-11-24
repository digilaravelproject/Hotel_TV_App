import 'package:flutter/material.dart';

class TvLoadingOverlay extends StatelessWidget {
  final String message;
  final double? progress;

  const TvLoadingOverlay({
    super.key,
    this.message = 'Loading Hotel TV Experience...',
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 52,
              height: 52,
              child: CircularProgressIndicator(
                strokeWidth: 3.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFb38a2d)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: 220,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFb38a2d)),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${((progress ?? 0) * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
