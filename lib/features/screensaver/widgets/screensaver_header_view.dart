import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/storage/shared_prefs.dart';
import '../../../../core/widget/custom_image_widget.dart';
import '../../../../shared/models/hotel_profile_model.dart';

class ScreensaverHeaderView extends StatelessWidget {
  const ScreensaverHeaderView({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    String timeOfDay = 'Good Afternoon';
    if (hour >= 5 && hour < 12) {
      timeOfDay = 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      timeOfDay = 'Good Afternoon';
    } else if (hour >= 17 && hour < 22) {
      timeOfDay = 'Good Evening';
    } else {
      timeOfDay = 'Good Night';
    }

    try {
      final rawData = SharedPrefs.getString(AppConstants.tvLoginDataKey);
      if (rawData != null && rawData.isNotEmpty) {
        final decoded = jsonDecode(rawData);
        final dataMap = decoded['data'] ?? decoded;
        final guest = dataMap['guest_name'] ?? dataMap['guest']?['name'] ?? 'Guest';
        return '$timeOfDay, $guest';
      }
    } catch (_) {}
    return '$timeOfDay, Guest';
  }

  Widget _buildLogo(HotelProfileModel hotel) {
    Widget imageChild;
    final logoUrl = hotel.media.logoImage;
    if (logoUrl.isNotEmpty && logoUrl.startsWith('http')) {
      imageChild = CustomImageWidget(
        imagePath: logoUrl,
        width: 52,
        height: 52,
        fit: BoxFit.contain,
        placeHolder: 'assets/logo.png',
      );
    } else {
      imageChild = Image.asset(
        'assets/logo.png',
        width: 52,
        height: 52,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.hotel_outlined, color: Color(0xFFb38a2d), size: 30),
      );
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0xFFb38a2d), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: Padding(
          padding: const EdgeInsets.all(3.0),
          child: imageChild,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hotel = HotelProfileModel.current();

    return Row(
      children: [
        _buildLogo(hotel),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hotel.name.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFb38a2d),
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            Text(
              _getGreeting(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
