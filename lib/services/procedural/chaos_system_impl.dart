import 'dart:math';

import '../../domain/procedural/level_config.dart';
import '../../domain/procedural/procedural_modules.dart';

class ChaosSystemImpl implements ChaosSystem {
  static const List<ChaosEventType> _pool = <ChaosEventType>[
    ChaosEventType.clone,
    ChaosEventType.fakeGoal,
    ChaosEventType.mazeShift,
  ];

  @override
  List<ChaosEventType> selectChaos({
    required double difficulty,
    required int seed,
  }) {
    final clampedDifficulty = difficulty.clamp(0.0, 1.0);
    final count = clampedDifficulty < 0.3
        ? 0
        : (clampedDifficulty < 0.6 ? 1 : 2);
    if (count == 0) {
      return const <ChaosEventType>[];
    }

    final random = Random(seed);
    final values = List<ChaosEventType>.from(_pool);
    values.shuffle(random);
    return values.take(count.clamp(0, 2)).toList(growable: false);
  }
}
