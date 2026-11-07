class AppConstants {
  static const String appName = 'PAX TV Hospitality';
  static const String baseUrl = 'https://app.paxtvlauncher.com';
  static const String fontFamily = 'Poppins';
  static const String defaultTag = 'Softfix';
  static const String qrSyncBaseUrl = '$baseUrl/sync-device?id=';
  static const String qrDeviceUrl = '$baseUrl/hotel/devices';
  static const String qrPairCodeUrl = '$baseUrl/hotel/devices?code=';

  static String getQrUrl([String? pairCode]) {
    if (pairCode != null && pairCode.isNotEmpty) {
      return '$qrPairCodeUrl$pairCode';
    }
    return qrDeviceUrl;
  }

  // Storage Keys
  static const String tvLoginDataKey = 'tv_login_data';
  static const String templateVersionKey = 'template_version';
  static const String userDataPref = 'user_data_pref';
  static const String isLoggedInPref = 'is_logged_in_pref';
  static const String isDemoModeKey = 'is_demo_mode';
  static const String demoExpiresAtKey = 'demo_expires_at';
  static const String demoDaysLeftKey = 'demo_days_left';
}

class AppAssets {
  AppAssets._();
  static const String logo = 'assets/logo.png';
  static const String demoIcon = 'assets/demo_icon.svg';
  static const String demoPreview = 'assets/demo_preview.jpg';
  static const String demoShowcaseVector = 'assets/demo_showcase_vector.svg';
}
