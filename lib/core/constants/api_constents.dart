import 'app_constants.dart';

class ApiConstants {
  // Base URL
  static String baseUrl = AppConstants.baseUrl;

  // API
  static const String apiVersion = '';
  static const String loginUri = '/api/tv/login';
  static const String generatePairCodeUri = '/api/tv/generate-pair-code';
  static const String pairStatusUri = '/api/tv/pair-status';
  static const String checkTemplateVersionUri = '/api/tv/template/check-version';
}
