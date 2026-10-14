import 'package:flutter_test/flutter_test.dart';
import 'package:hotel/core/constants/app_constants.dart';
import 'package:hotel/core/constants/api_constents.dart';
import 'package:hotel/core/services/time/tv_time_service.dart';

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

  group('TvTimeService Offline Clock Calibration', () {
    test('Default timezone is IST (+05:30 = 330 mins)', () {
      expect(TvTimeService.defaultTimezoneOffsetMinutes, equals(330));
      expect(TvTimeService.defaultTimezoneName, equals('Asia/Kolkata'));
    });

    test('generateJsClockSyncPatch outputs valid JavaScript with Alpine patchers', () {
      final js = TvTimeService.generateJsClockSyncPatch();
      expect(js.contains('__getCalibratedDate'), isTrue);
      expect(js.contains('patchAlpineClock'), isTrue);
      expect(js.contains('updateClock'), isTrue);
      expect(js.contains('updateGreeting'), isTrue);
      expect(js.contains('targetTzMin: 330'), isTrue);
    });
  });
}
