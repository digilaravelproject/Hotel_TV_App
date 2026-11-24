import 'package:flutter/material.dart';
import '../controllers/screensaver_controller.dart';
import 'screensaver_header_view.dart';
import 'screensaver_clock_view.dart';
import 'screensaver_wallpaper_view.dart';

class ScreensaverOverlayWidget extends StatelessWidget {
  final ScreensaverController controller;

  const ScreensaverOverlayWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      top: controller.isVisible ? 0 : -MediaQuery.of(context).size.height - 50,
      left: 0,
      right: 0,
      bottom: controller.isVisible ? 0 : MediaQuery.of(context).size.height + 50,
      child: GestureDetector(
        onTap: controller.resetInactivityTimer,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Wallpapers Rotator
              AnimatedSwitcher(
                duration: const Duration(seconds: 1),
                child: ScreensaverWallpaperView(
                  cachedFiles: controller.cachedWallpaperFiles,
                  networkUrls: controller.networkWallpaperUrls,
                  fallbackBgPath: controller.fallbackBgFilePath,
                  currentIndex: controller.wallpaperIndex,
                ),
              ),

              // Ambient Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),

              // Top-Left Hotel Logo & Greeting
              const Positioned(
                top: 48,
                left: 48,
                child: ScreensaverHeaderView(),
              ),

              // Bottom-Right Clock & Ambient Meta
              Positioned(
                right: 48,
                bottom: 48,
                child: ScreensaverClockView(
                  timeStr: controller.timeStr,
                  temperatureStr: controller.temperatureStr,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
