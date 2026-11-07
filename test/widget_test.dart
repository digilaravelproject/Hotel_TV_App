import 'package:flutter_test/flutter_test.dart';
import 'package:hotel/core/constants/app_constants.dart';

void main() {
  test('App smoke test: appName and basic configuration', () {
    expect(AppConstants.appName, isNotEmpty);
  });
}
