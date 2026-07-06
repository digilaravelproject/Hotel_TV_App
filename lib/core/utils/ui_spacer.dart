import 'package:flutter/material.dart';

import '../constants/dimensions.dart';

class UiSpacer {
  // Basic spacing with default responsive values
  static Widget hSpace([double? space]) =>
      SizedBox(width: space ?? Dimensions.width20);

  static Widget vSpace([double? space]) =>
      SizedBox(height: space ?? Dimensions.height20);

  // Vertical spacing variants
  static Widget verticalSpace({double? space}) =>
      SizedBox(height: space ?? Dimensions.height20);

  static Widget smallVerticalSpace() =>
      SizedBox(height: Dimensions.height10);

  static Widget mediumVerticalSpace() =>
      SizedBox(height: Dimensions.height20);

  static Widget largeVerticalSpace() =>
      SizedBox(height: Dimensions.height30);

  static Widget extraLargeVerticalSpace() =>
      SizedBox(height: Dimensions.height45);

  // Horizontal spacing variants
  static Widget horizontalSpace({double? space}) =>
      SizedBox(width: space ?? Dimensions.width20);

  static Widget smallHorizontalSpace() =>
      SizedBox(width: Dimensions.width10);

  static Widget mediumHorizontalSpace() =>
      SizedBox(width: Dimensions.width20);

  static Widget largeHorizontalSpace() =>
      SizedBox(width: Dimensions.width30);

  // Form spacing
  static Widget formVerticalSpace({double? space}) =>
      SizedBox(height: space ?? Dimensions.height15);

  static Widget formFieldSpace() =>
      SizedBox(height: Dimensions.height15);

  // Empty and expanded spaces
  static Widget emptySpace() => const SizedBox.shrink();

  static Widget expandedSpace() => const Expanded(
    child: SizedBox.shrink(),
  );

  // Dividers with responsive dimensions
  static Widget divider({
    double? height,
    double? thickness,
    Color? color,
  }) =>
      Divider(
        height: height ?? Dimensions.height10,
        thickness: thickness ?? 1,
        color: color,
      );

  static Widget verticalDivider({
    double? width,
    double? thickness,
    Color? color,
  }) =>
      VerticalDivider(
        width: width ?? Dimensions.width10,
        thickness: thickness ?? 1,
        color: color,
      );

  // Slide indicator for bottom sheets
  static Widget slideIndicator({Color? color}) => Container(
    width: Dimensions.width50 * 2, // ~100 responsive
    height: Dimensions.height5 * 0.8, // ~4 responsive
    margin: EdgeInsets.only(bottom: Dimensions.height10),
    decoration: BoxDecoration(
      color: color ?? Colors.grey.shade400,
      borderRadius: BorderRadius.circular(Dimensions.radius8 / 2),
    ),
  );

  // Padding helpers
  static EdgeInsets horizontalPadding({double? padding}) =>
      EdgeInsets.symmetric(horizontal: padding ?? Dimensions.width20);

  static EdgeInsets verticalPadding({double? padding}) =>
      EdgeInsets.symmetric(vertical: padding ?? Dimensions.height20);

  static EdgeInsets allPadding({double? padding}) =>
      EdgeInsets.all(padding ?? Dimensions.width15);

  static EdgeInsets customPadding({
    double? left,
    double? right,
    double? top,
    double? bottom,
  }) =>
      EdgeInsets.only(
        left: left ?? 0,
        right: right ?? 0,
        top: top ?? 0,
        bottom: bottom ?? 0,
      );

  // Screen padding (safe area aware)
  static EdgeInsets screenPadding() => EdgeInsets.symmetric(
    horizontal: Dimensions.width20,
    vertical: Dimensions.height20,
  );

  // Card padding
  static EdgeInsets cardPadding() => EdgeInsets.all(Dimensions.width15);

  // List item padding
  static EdgeInsets listItemPadding() => EdgeInsets.symmetric(
    horizontal: Dimensions.width15,
    vertical: Dimensions.height10,
  );

  // Button padding
  static EdgeInsets buttonPadding() => EdgeInsets.symmetric(
    horizontal: Dimensions.width30,
    vertical: Dimensions.height15,
  );
}
