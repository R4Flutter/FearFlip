import 'package:flutter_test/flutter_test.dart';

import 'package:fearflipgame/domain/progression/progression_manager.dart';

void main() {
  test('progression increases score and level over sessions', () {
    final manager = ProgressionManager();

    final first = manager.recordSession(secondsSurvived: 60, flipsUsed: 4);
    final second = manager.recordSession(secondsSurvived: 180, flipsUsed: 12);

    expect(second.totalScore, greaterThan(first.totalScore));
    expect(second.currentLevel, greaterThanOrEqualTo(first.currentLevel));
  });

  test('unlockables are granted by thresholds', () {
    final manager = ProgressionManager();
    manager.recordSession(secondsSurvived: 500, flipsUsed: 20);
    final snap = manager.snapshot();

    expect(snap.unlocks, contains('skin_neon_runner'));
  });

  test('difficulty scalar is bounded', () {
    final manager = ProgressionManager();
    for (var i = 0; i < 200; i++) {
      manager.recordSession(secondsSurvived: 120, flipsUsed: 10);
    }
    final snap = manager.snapshot();
    expect(snap.difficultyScalar, inInclusiveRange(1, 3));
  });
}
