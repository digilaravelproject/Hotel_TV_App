import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../constants/app_constants.dart';

class Logger {
  static final List<String> recentLogs = [];
  static const int _maxLogs = 30;
  static String lastExitOrErrorReason = '';

  static void d(String message, {String tag = AppConstants.defaultTag}) {
    _log('DEBUG', message, tag);
  }

  static void i(String message, {String tag = AppConstants.defaultTag}) {
    _log('INFO', message, tag);
  }

  static void w(String message, {String tag = AppConstants.defaultTag}) {
    _log('WARNING', message, tag);
    try {
      FirebaseCrashlytics.instance.log('[$tag][WARN] $message');
    } catch (_) {}
  }

  static void e(
    String message, {
    String tag = AppConstants.defaultTag,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _log('ERROR', message, tag);
    lastExitOrErrorReason = message;
    if (error != null) {
      _log('ERROR', error.toString(), tag);
    }
    try {
      FirebaseCrashlytics.instance.log('[$tag][ERROR] $message: ${error ?? ''}');
      if (error != null) {
        FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: message);
      }
    } catch (_) {}
  }

  static void _log(String level, String message, String tag) {
    developer.log('[$level] $message', name: tag);
    debugPrint('[$tag][$level] $message');
    final time = DateTime.now().toIso8601String().substring(11, 19);
    recentLogs.add('[$time][$tag][$level] $message');
    if (recentLogs.length > _maxLogs) {
      recentLogs.removeAt(0);
    }
  }
}

