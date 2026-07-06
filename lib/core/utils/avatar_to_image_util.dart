// lib/core/utils/avatar_to_image_util.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:random_avatar/random_avatar.dart';

/// Utility to convert RandomAvatar widget to image file
class AvatarToImageUtil {
  /// Convert RandomAvatar to PNG file
  ///
  /// [avatarSeed] - The seed string for RandomAvatar
  /// [size] - Size of the output image (default: 512x512)
  static Future<File?> convertAvatarToImage({
    required String avatarSeed,
    double size = 512,
  }) async {
    try {
      print('🎨 Converting avatar to image...');
      print('🎨 Seed: $avatarSeed');
      print('🎨 Size: ${size}x$size');

      // Create a widget tree with the avatar
      final widget = RepaintBoundary(
        child: Container(
          width: size,
          height: size,
          color: Colors.transparent,
          child: RandomAvatar(
            avatarSeed,
            height: size,
            width: size,
          ),
        ),
      );

      // Render the widget to an image
      final image = await _widgetToImage(widget, size);

      if (image == null) {
        print('❌ Failed to render widget to image');
        return null;
      }

      // Convert image to PNG bytes
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        print('❌ Failed to convert image to bytes');
        return null;
      }

      final pngBytes = byteData.buffer.asUint8List();
      print('✅ Image converted: ${pngBytes.length} bytes');

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      await file.writeAsBytes(pngBytes);
      print('✅ Image saved: ${file.path}');
      print('✅ File size: ${(file.lengthSync() / 1024).toStringAsFixed(2)} KB');

      return file;
    } catch (e, stackTrace) {
      print('❌ Avatar to image conversion error: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Render widget to ui.Image
  static Future<ui.Image?> _widgetToImage(Widget widget, double size) async {
    try {
      // Create a RepaintBoundary
      final repaintBoundary = RenderRepaintBoundary();

      // Create render tree
      final renderView = RenderView(

        view: WidgetsBinding.instance.window,
        child: RenderPositionedBox(
          alignment: Alignment.center,
          child: repaintBoundary,
        ),
        configuration: ViewConfiguration(
          logicalConstraints: BoxConstraints(
            maxWidth: size,
            maxHeight: size,
          ),
          physicalConstraints: BoxConstraints(
            maxWidth: size,
            maxHeight: size,
          ),
          devicePixelRatio: 1.0,
        ),
      );

      // Create pipeline owner and attach
      final pipelineOwner = PipelineOwner();
      final buildOwner = BuildOwner(focusManager: FocusManager());

      pipelineOwner.rootNode = renderView;
      renderView.prepareInitialFrame();

      // Build the widget
      final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
        container: repaintBoundary,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: widget,
        ),
      ).attachToRenderTree(buildOwner);

      // Layout and paint
      buildOwner.buildScope(rootElement);
      buildOwner.finalizeTree();

      pipelineOwner.flushLayout();
      pipelineOwner.flushCompositingBits();
      pipelineOwner.flushPaint();

      // Capture image
      final image = await repaintBoundary.toImage(pixelRatio: 1.0);
      return image;
    } catch (e) {
      print('❌ Widget to image error: $e');
      return null;
    }
  }

  /// Alternative: Create avatar with specific background color
  static Future<File?> convertAvatarWithBackground({
    required String avatarSeed,
    Color backgroundColor = Colors.white,
    double size = 512,
  }) async {
    try {
      print('🎨 Converting avatar with background...');

      final widget = RepaintBoundary(
        child: Container(
          width: size,
          height: size,
          color: backgroundColor,
          child: RandomAvatar(
            avatarSeed,
            height: size,
            width: size,
          ),
        ),
      );

      final image = await _widgetToImage(widget, size);

      if (image == null) return null;

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/avatar_bg_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      await file.writeAsBytes(pngBytes);
      print('✅ Avatar with background saved: ${file.path}');

      return file;
    } catch (e) {
      print('❌ Error: $e');
      return null;
    }
  }
}