import 'dart:math';

import '../../domain/procedural/level_config.dart';
import '../../domain/procedural/procedural_modules.dart';

class BreathingSystemImpl implements BreathingSystem {
  static const List<BreathingEventType> _types = <BreathingEventType>[
    BreathingEventType.clearCorridor,
    BreathingEventType.noFlipWindow,
    BreathingEventType.slightSlowdown,
  ];

  @override
  List<BreathingEvent> buildPattern({
    required int seed,
    required double totalSeconds,
    required List<double> chaosSpikeTimes,
  }) {
    if (totalSeconds <= 0) {
      return const <BreathingEvent>[];
    }

    final random = Random(seed ^ 0x5F3759DF);
    final events = <BreathingEvent>[];
    var cursor = 8.0 + random.nextDouble() * 4.0;

    while (cursor < totalSeconds) {
      var candidate = cursor;

      // Avoid overlaps with chaos spikes within +-1.2s.
      while (_overlapsChaos(candidate, chaosSpikeTimes) &&
          candidate < totalSeconds) {
        candidate += 0.75;
      }

      if (candidate >= totalSeconds) {
        break;
      }

      events.add(
        BreathingEvent(
          timeSeconds: candidate,
          type: _types[random.nextInt(_types.length)],
        ),
      );

      cursor = candidate + 8.0 + random.nextDouble() * 4.0;
    }

    return events;
  }

  bool _overlapsChaos(double time, List<double> chaosSpikeTimes) {
    for (final spike in chaosSpikeTimes) {
      if ((spike - time).abs() < 1.2) {
        return true;
      }
    }
    return false;
  }
}
