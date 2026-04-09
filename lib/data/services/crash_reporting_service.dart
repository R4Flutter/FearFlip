import 'package:firebase_crashlytics/firebase_crashlytics.dart';

abstract class CrashReportingService {
  Future<void> recordError(Object error, StackTrace stack, {String? reason});
}

class FirebaseCrashReportingService implements CrashReportingService {
  FirebaseCrashReportingService({FirebaseCrashlytics? crashlytics})
    : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  final FirebaseCrashlytics _crashlytics;

  @override
  Future<void> recordError(Object error, StackTrace stack, {String? reason}) {
    return _crashlytics.recordError(error, stack, reason: reason, fatal: false);
  }
}

class NoopCrashReportingService implements CrashReportingService {
  @override
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    String? reason,
  }) async {}
}
