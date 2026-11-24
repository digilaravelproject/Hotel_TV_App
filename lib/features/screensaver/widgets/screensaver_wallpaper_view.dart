import 'dart:io';
import 'package:flutter/material.dart';

class ScreensaverWallpaperView extends StatelessWidget {
  final List<File> cachedFiles;
  final List<String> networkUrls;
  final String? fallbackBgPath;
  final int currentIndex;

  const ScreensaverWallpaperView({
    super.key,
    required this.cachedFiles,
    required this.networkUrls,
    this.fallbackBgPath,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (cachedFiles.isNotEmpty) {
      final file = cachedFiles[currentIndex % cachedFiles.length];
      return Image.file(
        file,
        key: ValueKey(file.path + '$currentIndex'),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0F172A)),
      );
    }

    if (networkUrls.isNotEmpty) {
      final url = networkUrls[currentIndex % networkUrls.length];
      return Image.network(
        url,
        key: ValueKey(url + '$currentIndex'),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0F172A)),
      );
    }

    if (fallbackBgPath != null && File(fallbackBgPath!).existsSync()) {
      return Image.file(
        File(fallbackBgPath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF020617)],
        ),
      ),
    );
  }
}
