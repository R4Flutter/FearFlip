import 'package:firebase_analytics/firebase_analytics.dart';

abstract class AnalyticsService {
  Future<void> gameStart();
  Future<void> gameOver({required int durationSeconds, required bool flipped});
  Future<void> levelDuration({
    required String levelId,
    required int durationSeconds,
  });
  Future<void> flipUsage({required int flips});
  Future<void> rageQuit({required int durationSeconds});
}

class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService({FirebaseAnalytics? analytics})
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> gameStart() {
    return _analytics.logEvent(name: 'game_start');
  }

  @override
  Future<void> gameOver({required int durationSeconds, required bool flipped}) {
    return _analytics.logEvent(
      name: 'game_over',
      parameters: <String, Object>{
        'duration_seconds': durationSeconds,
        'flipped': flipped ? 1 : 0,
      },
    );
  }

  @override
  Future<void> levelDuration({
    required String levelId,
    required int durationSeconds,
  }) {
    return _analytics.logEvent(
      name: 'level_duration',
      parameters: <String, Object>{
        'level_id': levelId,
        'duration_seconds': durationSeconds,
      },
    );
  }

  @override
  Future<void> flipUsage({required int flips}) {
    return _analytics.logEvent(
      name: 'flip_usage',
      parameters: <String, Object>{'flips': flips},
    );
  }

  @override
  Future<void> rageQuit({required int durationSeconds}) {
    return _analytics.logEvent(
      name: 'rage_quit',
      parameters: <String, Object>{'duration_seconds': durationSeconds},
    );
  }
}

class NoopAnalyticsService implements AnalyticsService {
  @override
  Future<void> gameOver({
    required int durationSeconds,
    required bool flipped,
  }) async {}

  @override
  Future<void> gameStart() async {}

  @override
  Future<void> levelDuration({
    required String levelId,
    required int durationSeconds,
  }) async {}

  @override
  Future<void> rageQuit({required int durationSeconds}) async {}

  @override
  Future<void> flipUsage({required int flips}) async {}
}
