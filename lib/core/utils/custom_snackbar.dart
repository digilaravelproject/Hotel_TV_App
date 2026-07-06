import 'package:flutter/material.dart';
import '../../main.dart';
import '../constants/app_colors.dart';
import '../widget/custom_app_text.dart';

class CustomSnackbar {
  static void _show({
    required String title,
    required String message,
    required Color backgroundColor,
    required IconData icon,
    Color? textColor,
  }) {
    final context = rootScaffoldMessengerKey.currentContext;
    if (context == null) return;

    final Color effectiveTextColor =
        textColor ??
            (backgroundColor.computeLuminance() > 0.5
                ? Colors.black
                : Colors.white);

    final snackBar = SnackBar(
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: effectiveTextColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomAppText(
                  title,
                  style: TextStyle(
                    color: effectiveTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                CustomAppText(
                  message,
                  style: TextStyle(color: effectiveTextColor, fontSize: 14),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () =>
                rootScaffoldMessengerKey.currentState?.hideCurrentSnackBar(),
            child: CustomAppText(
              "DISMISS",
              style: TextStyle(
                color: effectiveTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    rootScaffoldMessengerKey.currentState?.showSnackBar(snackBar);
  }

  static void showSuccess( {required String message,String title = 'Success'}) {
    _show(
      title: title,
      message: message,
      backgroundColor: AppColors.successColor,
      icon: Icons.check_circle,
    );
  }

  static void showError({required String message,String title = 'Error'}) {
    _show(
      title: title,
      message: message,
      backgroundColor: AppColors.errorColor,
      icon: Icons.error,
    );
  }

  static void showInfo({required String message,String title = 'Info'}) {
    _show(
      title: title,
      message: message,
      backgroundColor: AppColors.infoColor,
      icon: Icons.info,
    );
  }

  static void showWarning({required String message,String title = 'Warning'}) {
    _show(
      title: title,
      message: message,
      backgroundColor: AppColors.warningColor,
      icon: Icons.warning,
    );
  }

  static void showFavoriteStatus({
    required bool isFavorite,
  }) {
    final title = 'Favorites';

    final message = !isFavorite
        ? 'Added to favorites'
        : 'Removed from favorites';

    final Color backgroundColor = !isFavorite
        ? AppColors.successColor.withOpacity(0.9)
        : AppColors.errorColor.withOpacity(0.9);

    final IconData icon = !isFavorite ? Icons.favorite : Icons.favorite_border;

    _show(
      title: title,
      message: message,
      backgroundColor: backgroundColor,
      icon: icon,
    );
  }
}
