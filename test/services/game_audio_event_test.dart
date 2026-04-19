import 'package:flutter_test/flutter_test.dart';

import 'package:fearflipgame/services/game_audio_event.dart';

void main() {
  group('AudioDebugSnapshot.initial', () {
    test('exposes the strict six-bus gain map', () {
      final gains = AudioDebugSnapshot.initial.busGains;

      expect(gains.length, 6);
      expect(
        gains.keys,
        orderedEquals(<AudioBus>[
          AudioBus.master,
          AudioBus.bgm,
          AudioBus.ambient,
          AudioBus.enemy,
          AudioBus.ui,
          AudioBus.action,
        ]),
      );

      for (final value in gains.values) {
        expect(value, 1.0);
      }
    });
  });

  group('GameAudioEventPayload factories', () {
    test('flipTriggered carries frameId for dedupe parity', () {
      final payload = GameAudioEventPayload.flipTriggered(frameId: 42);

      expect(payload.type, GameAudioEvent.flipTriggered);
      expect(payload.frameId, 42);
      expect(payload.secondsLeft, isNull);
    });

    test('devilDistanceChanged carries distance and immunity flags', () {
      final payload = GameAudioEventPayload.devilDistanceChanged(
        distanceTiles: 3,
        devilEnabled: true,
        safeZoneImmune: false,
      );

      expect(payload.type, GameAudioEvent.devilDistanceChanged);
      expect(payload.devilDistanceTiles, 3);
      expect(payload.devilEnabled, isTrue);
      expect(payload.safeZoneImmune, isFalse);
    });

    test('effectiveTimestamp respects explicit timestamp', () {
      final explicit = DateTime(2026, 4, 18, 10, 30, 0);
      final payload = GameAudioEventPayload(
        GameAudioEvent.matchStart,
        timestamp: explicit,
      );

      expect(payload.effectiveTimestamp, explicit);
    });
  });
}
