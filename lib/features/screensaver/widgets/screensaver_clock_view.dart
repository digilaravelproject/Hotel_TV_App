import 'package:flutter/material.dart';

class ScreensaverClockView extends StatelessWidget {
  final String timeStr;
  final String temperatureStr;

  const ScreensaverClockView({
    super.key,
    required this.timeStr,
    required this.temperatureStr,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$temperatureStr ',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w300,
              ),
            ),
            const Icon(Icons.water_drop, color: Colors.cyanAccent, size: 24),
            const SizedBox(width: 24),
            Text(
              timeStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 72,
                fontWeight: FontWeight.w200,
                letterSpacing: 2,
                shadows: [
                  Shadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app_outlined, color: Color(0xFFb38a2d), size: 18),
              SizedBox(width: 8),
              Text(
                'Press any key to continue',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
