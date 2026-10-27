import 'package:flutter/foundation.dart';

/// What makes a world play differently from the one before it.
enum WorldTwist {
  /// Flips, the Devil, spirit candles and the key hunt: the basics.
  none,

  /// More cracked floors; a second step on one drops you.
  crumbling,

  /// The walls move on every stage, not just every sixth.
  shifting,

  /// The lantern light shrinks: you see far less of the maze.
  blackout,

  /// The Devil sprints in bursts when it is far behind you.
  rage,
}

/// One of the five worlds the 100 stages are split into. Each brings a new
/// twist so the campaign keeps changing (the old run was one long stretch of
/// identical 17×17 mazes from stage 8 to 100).
@immutable
class WorldInfo {
  const WorldInfo({
    required this.index,
    required this.name,
    required this.tagline,
    required this.twist,
    required this.twistText,
    required this.accent,
  });

  /// 0-based.
  final int index;
  final String name;
  final String tagline;
  final WorldTwist twist;

  /// One line shown when the world opens and on its map header.
  final String twistText;

  /// ARGB accent for its map header and nodes.
  final int accent;

  int get firstStage => index * Worlds.stagesPerWorld + 1;
  int get lastStage => firstStage + Worlds.stagesPerWorld - 1;
  int get number => index + 1;

  bool contains(int stage) => stage >= firstStage && stage <= lastStage;
}

abstract final class Worlds {
  static const int stagesPerWorld = 20;
  static const int maxStage = 100;

  static const List<WorldInfo> all = <WorldInfo>[
    WorldInfo(
      index: 0,
      name: 'Lantern Halls',
      tagline: 'Where every nightmare starts',
      twist: WorldTwist.none,
      twistText: 'Learn the flip. Hide in blue candles. Find the keys.',
      accent: 0xFFF2B544,
    ),
    WorldInfo(
      index: 1,
      name: 'Bone Crypt',
      tagline: 'The floor remembers your steps',
      twist: WorldTwist.crumbling,
      twistText: 'Cracked floors everywhere. Never step on one twice.',
      accent: 0xFFD8C3A0,
    ),
    WorldInfo(
      index: 2,
      name: 'Shifting Catacombs',
      tagline: 'The walls are alive',
      twist: WorldTwist.shifting,
      twistText: 'The maze rearranges itself on every stage.',
      accent: 0xFF9CC8F0,
    ),
    WorldInfo(
      index: 3,
      name: 'Blackout Depths',
      tagline: 'Your light is all you have',
      twist: WorldTwist.blackout,
      twistText: 'Your lantern burns low. Trust the arrows.',
      accent: 0xFF7884A0,
    ),
    WorldInfo(
      index: 4,
      name: "Devil's Throne",
      tagline: 'It is done waiting',
      twist: WorldTwist.rage,
      twistText: 'The Devil sprints when it falls behind. Keep moving.',
      accent: 0xFFE03A32,
    ),
  ];

  static WorldInfo forStage(int stage) {
    final clamped = stage.clamp(1, maxStage);
    return all[(clamped - 1) ~/ stagesPerWorld];
  }

  /// Every 10th stage is a gate: a harder stage that pays a chest.
  static bool isGate(int stage) => stage % 10 == 0;

  /// The first stage of a world (shows the world's intro card).
  static bool opensWorld(int stage) => (stage - 1) % stagesPerWorld == 0;
}
