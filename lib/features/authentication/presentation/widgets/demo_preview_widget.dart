import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widget/tv_focusable.dart';

class DemoPreviewWidget extends StatelessWidget {
  final VoidCallback? onStartDemo;
  final bool isLoading;
  final FocusNode? demoActionFocus;

  const DemoPreviewWidget({
    super.key,
    this.onStartDemo,
    this.isLoading = false,
    this.demoActionFocus,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        key: const ValueKey('demo_mode_preview'),
        width: 450,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
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
                  Icon(Icons.bolt_rounded, color: Colors.amber.shade400, size: 16),
                  const SizedBox(width: 5),
                  Text(
                    "FREE DEMO TRIAL",
                    style: TextStyle(
                      color: Colors.amber.shade300,
                      fontSize: 11.5,
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
              height: 100,
            ),
            const SizedBox(height: 14),

            // Title
            const Text(
              "Instant Hotel TV Demo",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),

            // Subtitle Description
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                "Test all IPTV guest features, amenities, and room controls instantly with zero setup or credentials.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Feature Highlights Tags
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
            const SizedBox(height: 18),

            // Interactive Remote Action Button
            TvFocusable(
              focusNode: demoActionFocus,
              onTap: onStartDemo ?? () {},
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade400,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.35),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading) ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ] else ...[
                      const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      isLoading ? "Activating Demo..." : "Start Free Demo",
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.amber.shade300, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
