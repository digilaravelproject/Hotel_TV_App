import 'package:flutter_test/flutter_test.dart';
import 'package:hotel/core/constants/app_constants.dart';
import 'package:hotel/core/constants/api_constents.dart';

void main() {
  group('Smart TV Demo System Constants & Endpoints', () {
    test('Demo constants are properly defined', () {
      expect(AppConstants.isDemoModeKey, equals('is_demo_mode'));
      expect(AppConstants.demoExpiresAtKey, equals('demo_expires_at'));
      expect(AppConstants.demoDaysLeftKey, equals('demo_days_left'));
    });

    test('Demo API endpoint is properly defined', () {
      expect(ApiConstants.demoLoginUri, equals('/api/tv/demo-login'));
    });
  });
}
