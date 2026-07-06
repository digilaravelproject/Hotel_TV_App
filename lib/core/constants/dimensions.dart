import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class Dimensions {
  // Screen dimensions using responsive_sizer
  static double get screenHeight => 100.h;
  static double get screenWidth => 100.w;

  // Dynamic height padding and margin
  static double get height4 => 0.5.h;    // ~4px on standard screen
  static double get height5 => 0.6.h;    // ~5px on standard screen
  static double get height8 => 1.0.h;    // ~8px
  static double get height10 => 1.2.h;   // ~10px
  static double get height15 => 1.8.h;   // ~15px
  static double get height16 => 1.9.h;   // ~16px
  static double get height20 => 2.4.h;   // ~20px
  static double get height30 => 3.6.h;   // ~30px
  static double get height45 => 5.4.h;   // ~45px
  static double get height50 => 6.0.h;   // ~50px
  static double get height60 => 7.2.h;   // ~60px

  // Dynamic width padding and margin
  static double get width4 => 1.1.w;     // ~4px
  static double get width5 => 1.4.w;     // ~5px
  static double get width10 => 2.8.w;    // ~10px
  static double get width15 => 4.2.w;    // ~15px
  static double get width16 => 4.4.w;    // ~16px
  static double get width20 => 5.6.w;    // ~20px
  static double get width30 => 8.3.w;    // ~30px
  static double get width40 => 11.1.w;   // ~40px
  static double get width50 => 13.9.w;   // ~50px

  // Padding values (commonly used)
  static double get padding4 => 0.5.h;
  static double get padding8 => 1.0.h;
  static double get padding12 => 1.4.h;
  static double get padding16 => 1.9.h;
  static double get padding20 => 2.4.h;
  static double get padding24 => 2.9.h;

  // Font sizes using responsive_sizer
  static double get font10 => 10.sp;
  static double get font12 => 12.sp;
  static double get font14 => 14.sp;
  static double get font16 => 16.sp;
  static double get font18 => 18.sp;
  static double get font20 => 20.sp;
  static double get font22 => 22.sp;
  static double get font24 => 24.sp;
  static double get font26 => 26.sp;
  static double get font28 => 28.sp;

  // Border Radius using responsive_sizer
  static double get radius8 => 8.sp;
  static double get radius12 => 12.sp;
  static double get radius15 => 15.sp;
  static double get radius20 => 20.sp;
  static double get radius25 => 25.sp;
  static double get radius30 => 30.sp;

  // Icon sizes using responsive_sizer
  static double get iconSize12 => 12.sp;
  static double get iconSize14 => 14.sp;
  static double get iconSize16 => 16.sp;
  static double get iconSize18 => 18.sp;
  static double get iconSize20 => 20.sp;
  static double get iconSize24 => 24.sp;
  static double get iconSize28 => 28.sp;
  static double get iconSize32 => 32.sp;

  // Button sizes
  static double get buttonHeight => 6.5.h;      // ~55px
  static double get buttonHeightSmall => 5.0.h; // ~42px
  static double get buttonHeightLarge => 7.5.h; // ~63px
  static double get buttonWidth => 45.w;        // ~170px
  static double get buttonWidthFull => 90.w;    // Full width with margins

  // List view sizes
  static double get listViewImgSize => 25.w;         // ~90px
  static double get listViewImgSizeSmall => 20.w;    // ~72px
  static double get listViewImgSizeLarge => 30.w;    // ~108px
  static double get listViewTextContSize => 65.w;    // Remaining width

  // Card sizes
  static double get cardHeight => 20.h;        // ~168px
  static double get cardWidth => 42.w;         // ~151px

  // Bottom Navigation Bar
  static double get bottomNavHeight => 8.h;    // ~67px

  // App Bar
  static double get appBarHeight => 7.h;       // ~59px

  // Common spacing
  static double get spacingXS => 0.5.h;        // Extra small spacing
  static double get spacingS => 1.h;           // Small spacing
  static double get spacingM => 2.h;           // Medium spacing
  static double get spacingL => 3.h;           // Large spacing
  static double get spacingXL => 4.h;          // Extra large spacing

  // Device type helpers
  static bool get isMobile => Device.screenType == ScreenType.mobile;
  static bool get isTablet => Device.screenType == ScreenType.tablet;
  static bool get isDesktop => Device.screenType == ScreenType.desktop;

  // Orientation helpers
  static bool get isPortrait => Device.orientation == Orientation.portrait;
  static bool get isLandscape => Device.orientation == Orientation.landscape;
}
