import 'dart:developer' as developer;
import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

class Logger {
  static void d(String message, {String tag = AppConstants.defaultTag}) {
    _log('DEBUG', message, tag);
  }

  static void i(String message, {String tag = AppConstants.defaultTag}) {
    _log('INFO', message, tag);
  }

  static void w(String message, {String tag = AppConstants.defaultTag}) {
    _log('WARNING', message, tag);
  }

  static void e(
    String message, {
    String tag = AppConstants.defaultTag,
    dynamic error,
  }) {
    _log('ERROR', message, tag);
    if (error != null) {
      _log('ERROR', error.toString(), tag);
    }
  }

  static void _log(String level, String message, String tag) {
    developer.log('[$level] $message', name: tag);
    debugPrint('[$tag][$level] $message');
  }
}
