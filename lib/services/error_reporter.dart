import 'dart:convert';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized error reporting for swallowed or non-fatal exceptions.
class ErrorReporter {
  static void report({
    required String reason,
    required Object error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const <String, Object?>{},
    bool fatal = false,
  }) {
    if (kDebugMode) {
      debugPrint('[ErrorReporter] $reason: $error');
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }

    if (kIsWeb) {
      return;
    }

    try {
      final crashlytics = FirebaseCrashlytics.instance;
      if (context.isNotEmpty) {
        final safeContext = context.map(
          (key, value) => MapEntry(key, value?.toString() ?? 'null'),
        );
        crashlytics.setCustomKey('context', jsonEncode(safeContext));
      }
      crashlytics.log(reason);
      crashlytics.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: fatal,
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[ErrorReporter] Failed to report error: $error');
        debugPrint(stackTrace.toString());
      }
    }
  }
}
