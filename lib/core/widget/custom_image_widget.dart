import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/image_constants.dart';


/// Enum to represent different image types
enum ImageType { svg, svgString, png, network, file, gif, unknown }

/// Extension to determine the type of image based on its path
extension ImageTypeExtension on String {
  ImageType get imageType {
    if (startsWith('<svg')) {
      return ImageType.svgString;
    } else if (startsWith('http') || startsWith('https')) {
      if (toLowerCase().endsWith('.gif')) {
        return ImageType.gif;
      }
      return ImageType.network;
    } else if (endsWith('.svg')) {
      return ImageType.svg;
    } else if (startsWith('file://')) {
      if (toLowerCase().endsWith('.gif')) {
        return ImageType.gif;
      }
      return ImageType.file;
    } else if (endsWith('.png') || endsWith('.jpg') || endsWith('.jpeg')) {
      return ImageType.png;
    } else if (endsWith('.gif')) {
      return ImageType.gif;
    } else {
      return ImageType.unknown;
    }
  }
}

/// A reusable custom image widget
class CustomImageWidget extends StatelessWidget {
  const CustomImageWidget({
    Key? key,
    this.imagePath,
    this.height,
    this.width,
    this.color,
    this.fit,
    this.alignment,
    this.onTap,
    this.radius,
    this.margin,
    this.border,
    this.placeHolder = ImageConstants.imageNotFound,
  }) : super(key: key);

  final String? imagePath;
  final double? height;
  final double? width;
  final Color? color;
  final BoxFit? fit;
  final String placeHolder;
  final Alignment? alignment;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? radius;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return alignment != null
        ? Align(
      alignment: alignment!,
      child: _buildWidget(context),
    )
        : _buildWidget(context);
  }

  Widget _buildWidget(BuildContext context) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: _buildCircleImage(context),
      ),
    );
  }

  Widget _buildCircleImage(BuildContext context) {
    if (radius != null) {
      return ClipRRect(
        borderRadius: radius!,
        child: _buildImageWithBorder(context),
      );
    }
    return _buildImageWithBorder(context);
  }

  Widget _buildImageWithBorder(BuildContext context) {
    if (border != null) {
      return Container(
        decoration: BoxDecoration(
          border: border,
          borderRadius: radius,
        ),
        child: _buildImageView(context),
      );
    }
    return _buildImageView(context);
  }

  Widget _buildImageView(BuildContext context) {
    final theme = Theme.of(context);
    final loaderColor = theme.colorScheme.primary;

    if (imagePath != null) {
      switch (imagePath!.imageType) {
        case ImageType.svg:
          return SvgPicture.asset(
            imagePath!,
            height: height,
            width: width,
            fit: fit ?? BoxFit.contain,
            colorFilter: color != null
                ? ColorFilter.mode(color!, BlendMode.srcIn)
                : null,
          );
        case ImageType.svgString:
          return SvgPicture.string(
            imagePath!,
            height: height,
            width: width,
            fit: fit ?? BoxFit.contain,
            colorFilter: color != null
                ? ColorFilter.mode(color!, BlendMode.srcIn)
                : null,
          );
        case ImageType.file:
          return Image.file(
            File(imagePath!),
            height: height,
            width: width,
            fit: fit ?? BoxFit.cover,
            color: color,
          );
        case ImageType.network:
          return CachedNetworkImage(
            height: height,
            width: width,
            fit: fit,
            imageUrl: imagePath!,
            color: color,
            placeholder: (context, url) => Center(
              child: SizedBox(
                height: 30,
                width: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: loaderColor,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Image.asset(
              placeHolder,
              height: height,
              width: width,
              fit: fit ?? BoxFit.cover,
            ),
          );
        case ImageType.png:
          return Image.asset(
            imagePath!,
            height: height,
            width: width,
            fit: fit ?? BoxFit.cover,
            color: color,
          );
        case ImageType.gif:
          if (imagePath!.startsWith('http')) {
            return FutureBuilder<File>(
              future: DefaultCacheManager().getSingleFile(imagePath!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: SizedBox(
                      height: 30,
                      width: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: loaderColor,
                      ),
                    ),
                  );
                } else if (snapshot.hasError || !snapshot.hasData) {
                  // Agar cache fail ho gaya to normal network image use karo
                  return Image.network(
                    imagePath!,
                    height: height,
                    width: width,
                    fit: fit ?? BoxFit.cover,
                    color: color,
                  );
                } else {
                  // Agar cache mil gaya to file se fast load
                  return Image.file(
                    snapshot.data!,
                    height: height,
                    width: width,
                    fit: fit ?? BoxFit.cover,
                    color: color,
                  );
                }
              },
            );
          } else if (imagePath!.startsWith('file://')) {
            return Image.file(
              File(imagePath!),
              height: height,
              width: width,
              fit: fit ?? BoxFit.cover,
              color: color,
            );
          } else {
            return Image.asset(
              imagePath!,
              height: height,
              width: width,
              fit: fit ?? BoxFit.cover,
              color: color,
            );
          }
        case ImageType.unknown:
        default:
          return Image.asset(
            placeHolder,
            height: height,
            width: width,
            fit: fit ?? BoxFit.cover,
          );
      }
    }
    return const SizedBox();
  }
}
