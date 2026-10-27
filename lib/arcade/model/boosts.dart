import 'package:flutter/foundation.dart';

/// Power-ups: found in the maze (used on the spot) or carried into a stage
/// from the inventory (bought with souls, won from chests and daily rewards).
enum BoostType {
  /// Blocks one catch by the Devil or one collapsing floor.
  shield,

  /// +20 seconds on the clock.
  hourglass,

  /// Freezes the Devil where it stands.
  frost,

  /// Lights the way to the next key, or to the exit once it is open.
  seer,
}

@immutable
class BoostInfo {
  const BoostInfo({
    required this.type,
    required this.name,
    required this.text,
    required this.price,
  });

  final BoostType type;
  final String name;
  final String text;

  /// Souls in the shop.
  final int price;

  String get id => type.name;
}

abstract final class Boosts {
  /// Seconds an hourglass adds.
  static const int hourglassSeconds = 20;

  /// Seconds the frost rune holds the Devil.
  static const double frostSeconds = 6;

  /// Seconds the seer's eye shows the way.
  static const double seerSeconds = 7;

  /// Boosts a player may carry into one stage.
  static const int maxPerStage = 2;

  static const Map<BoostType, BoostInfo> info = <BoostType, BoostInfo>{
    BoostType.shield: BoostInfo(
      type: BoostType.shield,
      name: 'Holy Ward',
      text: 'Blocks one Devil catch or one falling floor.',
      price: 140,
    ),
    BoostType.hourglass: BoostInfo(
      type: BoostType.hourglass,
      name: 'Sand of Time',
      text: '+$hourglassSeconds seconds on the clock.',
      price: 90,
    ),
    BoostType.frost: BoostInfo(
      type: BoostType.frost,
      name: 'Frost Rune',
      text: 'Freezes the Devil for 6 seconds.',
      price: 110,
    ),
    BoostType.seer: BoostInfo(
      type: BoostType.seer,
      name: "Seer's Eye",
      text: 'Lights the path to the next key or the exit.',
      price: 110,
    ),
  };

  static BoostType? byId(String id) {
    for (final type in BoostType.values) {
      if (type.name == id) return type;
    }
    return null;
  }
}
