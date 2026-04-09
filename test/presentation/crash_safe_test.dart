import 'package:flutter_test/flutter_test.dart';

import 'package:fearflipgame/data/services/analytics_service.dart';
import 'package:fearflipgame/data/services/crash_reporting_service.dart';
import 'package:fearflipgame/presentation/controllers/game_controller.dart';

class _ThrowingAnalytics implements AnalyticsService {
  @override
  Future<void> flipUsage({required int flips}) async =>
      throw StateError('boom');

  @override
  Future<void> gameOver({
    required int durationSeconds,
    required bool flipped,
  }) async {
    throw StateError('boom');
  }

  @override
  Future<void> gameStart() async {}

  @override
  Future<void> levelDuration({
    required String levelId,
    required int durationSeconds,
  }) async {
    throw StateError('boom');
  }

  @override
  Future<void> rageQuit({required int durationSeconds}) async =>
      throw StateError('boom');
}

class _RecordingCrashReporter implements CrashReportingService {
  int count = 0;

  @override
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    String? reason,
  }) async {
    count += 1;
  }
}

void main() {
  test('controller reports analytics exception via crash reporter', () async {
    final crash = _RecordingCrashReporter();
    final controller = GameController(
      analytics: _ThrowingAnalytics(),
      crashReporting: crash,
    );

    await controller.start(seed: 42);
    // Force game over quickly so analytics path is exercised.
    await controller.tick(60);

    expect(crash.count, greaterThan(0));
    controller.dispose();
  });
}
