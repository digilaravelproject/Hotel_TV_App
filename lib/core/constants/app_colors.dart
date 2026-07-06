import 'package:flutter/material.dart';

class AppColors {
  // Dynamic Theme Colors (will be set from JSON)
  static Color primaryColor = const Color(0xFF0084FF); // Modern blue (like Messenger)
  static Color secondaryColor = const Color(0xFF00D856); // Fresh green
  static Color darkPrimaryColor = const Color(0xFF0084FF); // Same blue for consistency
  static Color darkSecondaryColor = const Color(0xFF00D856); // Same green

  // Common Light Theme Colors (Static)
  static const Color backgroundColor = Color(0xFFF8F9FA); // Softer white
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color scaffoldBackgroundColor = Color(0xFFFFFFFF); // Pure white (like WhatsApp)
  static const Color textColorPrimary = Color(0xFF000000); // True black
  static const Color textColorSecondary = Color(0xFF667781); // WhatsApp gray
  static const Color textColorHint = Color(0xFF8696A0);
  static const Color borderColor = Color(0xFFE9EDEF); // Light border
  static const Color dividerColor = Color(0xFFE9EDEF);

  // Common Dark Theme Colors (Static)
  static const Color darkBackgroundColor = Color(0xFF0B141A); // WhatsApp dark bg
  static const Color darkCardColor = Color(0xFF202C33); // WhatsApp dark card
  static const Color darkScaffoldBackgroundColor = Color(0xFF0B141A);
  static const Color darkTextColorPrimary = Color(0xFFE9EDEF); // Light text
  static const Color darkTextColorSecondary = Color(0xFF8696A0); // Muted text
  static const Color darkTextColorHint = Color(0xFF667781);
  static const Color darkBorderColor = Color(0xFF2A3942);
  static const Color darkDividerColor = Color(0xFF2A3942);

  // Common Status Colors (Static)
  static const Color errorColor = Color(0xFFEA4335); // Google red
  static const Color successColor = Color(0xFF34C759); // iOS green
  static const Color warningColor = Color(0xFFFF9500); // iOS orange
  static const Color infoColor = Color(0xFF0084FF); // Messenger blue

  // Additional Communication App Colors
  static const Color onlineStatusColor = Color(0xFF00D856); // Online green
  static const Color typingIndicatorColor = Color(0xFF0084FF); // Typing blue
  static const Color unreadBadgeColor = Color(0xFF00D856); // Unread badge
  static const Color messageBackgroundSent = Color(0xFF0084FF); // Sent message
  static const Color messageBackgroundReceived = Color(0xFFE9EDEF); // Received (light)
  static const Color darkMessageBackgroundReceived = Color(0xFF202C33); // Received (dark)


}