import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../res/assets_res.dart';

class DemoPreviewWidget extends StatelessWidget {
  const DemoPreviewWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        key: const ValueKey('demo_mode_preview'),
        width: 410,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF190D2D).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.amber.shade500.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.12),
              blurRadius: 36,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
              blurRadius: 40,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top Trial Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4.5),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.amber.shade400.withValues(alpha: 0.55),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, color: Colors.amber.shade400, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    "FREE DEMO TRIAL",
                    style: TextStyle(
                      color: Colors.amber.shade300,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Colorful Smart TV Vector Artwork
            SvgPicture.asset(
              AppAssets.demoShowcaseVector,
              width: 140,
              height: 105,
            ),
            const SizedBox(height: 14),

            // Title
            const Text(
              "Instant Hotel TV Demo",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 5),

            // Subtitle Description
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                "Test all IPTV guest features, amenities, and room controls instantly with zero setup or credentials.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Feature Highlights Tags using Wrap to guarantee NO overflow
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildTag(Icons.tv_rounded, "IPTV Channels"),
                _buildTag(Icons.room_service_rounded, "Room Dining"),
                _buildTag(Icons.auto_awesome_rounded, "Zero Setup"),
              ],
            ),
            const SizedBox(height: 14),

            // Remote Action Cue
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.amber.shade400.withValues(alpha: 0.32),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade400,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "OK",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Press OK on remote to start demo",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.amber.shade300, size: 12),
          const SizedBox(width: 4.5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
