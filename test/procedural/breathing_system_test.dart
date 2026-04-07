import 'package:flutter_test/flutter_test.dart';
import 'package:fearflipgame/services/procedural/breathing_system_impl.dart';

void main() {
  group('BreathingSystemImpl', () {
    final system = BreathingSystemImpl();

    test('schedules breathing events at roughly 8-12 second cadence', () {
      final events = system.buildPattern(
        seed: 77,
        totalSeconds: 70,
        chaosSpikeTimes: const <double>[],
      );

      for (var i = 1; i < events.length; i++) {
        final gap = events[i].timeSeconds - events[i - 1].timeSeconds;
        expect(gap >= 8, isTrue);
        expect(gap <= 13, isTrue);
      }
    });

    test('avoids overlap with chaos spikes', () {
      final spikes = <double>[10, 20, 30, 40];
      final events = system.buildPattern(
        seed: 42,
        totalSeconds: 45,
        chaosSpikeTimes: spikes,
      );

      for (final event in events) {
        final overlaps = spikes.any((s) => (s - event.timeSeconds).abs() < 1.2);
        expect(overlaps, isFalse);
      }
    });
  });
}
