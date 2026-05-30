import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../config/app_runtime_config.dart';
import 'error_reporter.dart';

class AdsDiagnostics {
  AdsDiagnostics._();

  static bool get _verbose => kDebugMode || AppRuntimeConfig.adsVerboseLogging;
  static bool get _analyticsEnabled => AppRuntimeConfig.adsAnalyticsLogging;

  static void log(String message, {Map<String, Object?>? data}) {
    final formatted = _format(message, data);
    if (_verbose) {
      debugPrint(formatted);
    }
    if (kReleaseMode && !kIsWeb && AppRuntimeConfig.adsVerboseLogging) {
      _logToCrashlytics(formatted);
    }
  }

  static void event(String name, {Map<String, Object?>? params}) {
    if (!_analyticsEnabled) {
      return;
    }
    final sanitized = _sanitize(params);
    try {
      FirebaseAnalytics.instance.logEvent(name: name, parameters: sanitized);
    } catch (error, stackTrace) {
      ErrorReporter.report(
        reason: 'ads_event_failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'event': name},
      );
    }
  }

  static void error(
    String message,
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) {
    final formatted = _format(message, {
      if (data != null) ...data,
      'error': error.toString(),
    });
    debugPrint(formatted);
    if (kReleaseMode && !kIsWeb) {
      try {
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          reason: message,
        );
      } catch (reportError, reportStackTrace) {
        ErrorReporter.report(
          reason: 'ads_error_report_failed',
          error: reportError,
          stackTrace: reportStackTrace,
        );
      }
    }
  }

  static void _logToCrashlytics(String message) {
    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (error, stackTrace) {
      ErrorReporter.report(
        reason: 'ads_log_failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'message': message},
      );
    }
  }

  static String _format(String message, Map<String, Object?>? data) {
    if (data == null || data.isEmpty) {
      return '[Ads] $message';
    }
    final payload = data.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    return '[Ads] $message | $payload';
  }

  static Map<String, Object>? _sanitize(Map<String, Object?>? params) {
    if (params == null || params.isEmpty) {
      return null;
    }
    final sanitized = <String, Object>{};
    for (final entry in params.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      if (value is String && value.length > 100) {
        sanitized[entry.key] = value.substring(0, 100);
        continue;
      }
      sanitized[entry.key] = value;
    }
    return sanitized.isEmpty ? null : sanitized;
  }
}
