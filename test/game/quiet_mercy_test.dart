import 'package:fearflipgame/game/mercy/quiet_mercy.dart';
import 'package:fearflipgame/presentation/gameplay/near_miss_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuietMercy', () {
    test('helps from the third failure in a row on the same stage', () {
      final mercy = QuietMercy();
      mercy.recordFailure(7);
      mercy.recordFailure(7);
      expect(mercy.levelFor(7), 0);
      expect(mercy.bonusSecondsFor(7), 0);

      mercy.recordFailure(7);
      expect(mercy.levelFor(7), 1);
      expect(mercy.bonusSecondsFor(7), 10);
      expect(mercy.extraSafeZonesFor(7), 0);

      mercy.recordFailure(7);
      expect(mercy.levelFor(7), 2);
      expect(mercy.bonusSecondsFor(7), 20);
      expect(mercy.extraSafeZonesFor(7), 1);
    });

    test('is capped and only helps the stage the player is stuck on', () {
      final mercy = QuietMercy();
      for (var i = 0; i < 9; i++) {
        mercy.recordFailure(12);
      }
      expect(mercy.levelFor(12), 2);
      expect(mercy.levelFor(11), 0);
      expect(mercy.bonusSecondsFor(13), 0);
    });

    test('failing another stage starts the count over', () {
      final mercy = QuietMercy()
        ..recordFailure(4)
        ..recordFailure(4)
        ..recordFailure(5);
      expect(mercy.failuresOn(5), 1);
      expect(mercy.failuresOn(4), 0);
      expect(mercy.levelFor(5), 0);
    });

    test('clearing a stage resets it; disabled never helps', () {
      final mercy = QuietMercy()
        ..recordFailure(3)
        ..recordFailure(3)
        ..recordFailure(3);
      expect(mercy.levelFor(3), 1);
      mercy.clear();
      expect(mercy.levelFor(3), 0);

      final off = QuietMercy(enabled: false);
      for (var i = 0; i < 5; i++) {
        off.recordFailure(3);
      }
      expect(off.levelFor(3), 0);
    });
  });

  group('near-miss text', () {
    test('says how far from the exit and how many keys short', () {
      expect(nearMissText(tilesToExit: 4), '4 TILES FROM THE EXIT');
      expect(nearMissText(tilesToExit: 1), '1 TILE FROM THE EXIT');
      expect(
        nearMissText(tilesToExit: 6, keysShort: 1),
        '6 TILES FROM THE EXIT · 1 KEY SHORT',
      );
      expect(
        nearMissText(tilesToExit: 0, keysShort: 2),
        'AT THE EXIT · 2 KEYS SHORT',
      );
    });

    test('counts the stages to the next checkpoint', () {
      expect(
        checkpointProgressText(stage: 23, milestone: 25, maxStage: 100),
        '2 STAGES TO CHECKPOINT 25',
      );
      expect(
        checkpointProgressText(stage: 49, milestone: 50, maxStage: 100),
        '1 STAGE TO CHECKPOINT 50',
      );
      expect(
        checkpointProgressText(stage: 97, milestone: 100, maxStage: 100),
        '3 STAGES TO THE FINAL STAGE',
      );
      expect(
        checkpointProgressText(stage: 100, milestone: 100, maxStage: 100),
        'THE FINAL STAGE',
      );
    });
  });
}
