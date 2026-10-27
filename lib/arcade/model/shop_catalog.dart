import 'dart:ui';

import 'package:flutter/foundation.dart';

enum ShopCategory { runner, lantern, trail }

/// How an item is unlocked when it can't simply be bought.
enum UnlockRoute { free, souls, loginDay7, achievement }

/// The colours of a runner sprite (drawn in code, see pixel_sprites.dart).
@immutable
class RunnerPalette {
  const RunnerPalette({
    required this.hood,
    required this.hoodShade,
    required this.cloth,
    required this.clothShade,
    this.skin = const Color(0xFFF0C9A0),
    this.skinShade = const Color(0xFFC9946A),
    this.boots = const Color(0xFF3E2A20),
    this.trim = const Color(0xFFF0E6D2),
  });

  final Color hood;
  final Color hoodShade;
  final Color cloth;
  final Color clothShade;
  final Color skin;
  final Color skinShade;
  final Color boots;
  final Color trim;
}

enum TrailStyle { none, dust, embers, wisps, sparkles, bones }

@immutable
class ShopItem {
  const ShopItem({
    required this.id,
    required this.category,
    required this.name,
    required this.text,
    this.price = 0,
    this.route = UnlockRoute.souls,
    this.palette,
    this.light,
    this.trail,
  });

  final String id;
  final ShopCategory category;
  final String name;
  final String text;
  final int price;
  final UnlockRoute route;

  /// Runner items.
  final RunnerPalette? palette;

  /// Lantern items: the colour of the runner's light.
  final Color? light;

  /// Trail items.
  final TrailStyle? trail;

  bool get buyable => route == UnlockRoute.souls;
}

abstract final class ShopCatalog {
  static const String defaultRunner = 'runner_lantern_kid';
  static const String defaultLantern = 'lantern_amber';
  static const String defaultTrail = 'trail_dust';

  static const List<ShopItem> runners = <ShopItem>[
    ShopItem(
      id: defaultRunner,
      category: ShopCategory.runner,
      name: 'Lantern Kid',
      text: 'Scared, small, still running.',
      route: UnlockRoute.free,
      palette: RunnerPalette(
        hood: Color(0xFFC98A2E),
        hoodShade: Color(0xFF9C5A2B),
        cloth: Color(0xFF55627E),
        clothShade: Color(0xFF3B4660),
      ),
    ),
    ShopItem(
      id: 'runner_moss_scout',
      category: ShopCategory.runner,
      name: 'Moss Scout',
      text: 'Knows every crack in the crypt.',
      price: 400,
      palette: RunnerPalette(
        hood: Color(0xFF6E8A4E),
        hoodShade: Color(0xFF4A5E34),
        cloth: Color(0xFF6B3F24),
        clothShade: Color(0xFF3E2A20),
      ),
    ),
    ShopItem(
      id: 'runner_frost_wisp',
      category: ShopCategory.runner,
      name: 'Frost Wisp',
      text: 'Cold hands, colder nerves.',
      price: 700,
      palette: RunnerPalette(
        hood: Color(0xFF9CC8F0),
        hoodShade: Color(0xFF6A94C0),
        cloth: Color(0xFFE4F2FF),
        clothShade: Color(0xFFA3AEC4),
        trim: Color(0xFF55627E),
      ),
    ),
    ShopItem(
      id: 'runner_crimson_hood',
      category: ShopCategory.runner,
      name: 'Crimson Hood',
      text: 'The Devil hates this colour.',
      price: 1000,
      palette: RunnerPalette(
        hood: Color(0xFFB0202A),
        hoodShade: Color(0xFF7A1520),
        cloth: Color(0xFF34344A),
        clothShade: Color(0xFF23222F),
      ),
    ),
    ShopItem(
      id: 'runner_gravedigger',
      category: ShopCategory.runner,
      name: 'Gravedigger',
      text: 'Has dug a way out before.',
      price: 1500,
      palette: RunnerPalette(
        hood: Color(0xFF5E4636),
        hoodShade: Color(0xFF3E2A20),
        cloth: Color(0xFF7884A0),
        clothShade: Color(0xFF55627E),
        boots: Color(0xFF23222F),
      ),
    ),
    ShopItem(
      id: 'runner_violet_seer',
      category: ShopCategory.runner,
      name: 'Violet Seer',
      text: 'Sees the flip before it comes.',
      price: 2200,
      palette: RunnerPalette(
        hood: Color(0xFF6B4A85),
        hoodShade: Color(0xFF45294F),
        cloth: Color(0xFF2B1A33),
        clothShade: Color(0xFF16151F),
        trim: Color(0xFFFFE08A),
      ),
    ),
    ShopItem(
      id: 'runner_candle_keeper',
      category: ShopCategory.runner,
      name: 'Candle Keeper',
      text: 'Reward for a full week of nights (day 7).',
      route: UnlockRoute.loginDay7,
      palette: RunnerPalette(
        hood: Color(0xFFF0E6D2),
        hoodShade: Color(0xFFB39572),
        cloth: Color(0xFFF2B544),
        clothShade: Color(0xFFC98A2E),
        trim: Color(0xFF7A1520),
      ),
    ),
    ShopItem(
      id: 'runner_bone_prince',
      category: ShopCategory.runner,
      name: 'Bone Prince',
      text: "Unlocked by conquering the Devil's Throne.",
      route: UnlockRoute.achievement,
      palette: RunnerPalette(
        hood: Color(0xFFD8C3A0),
        hoodShade: Color(0xFF8A6B50),
        cloth: Color(0xFFFFE08A),
        clothShade: Color(0xFFC98A2E),
        skin: Color(0xFFD3D9E4),
        skinShade: Color(0xFFA3AEC4),
        trim: Color(0xFFB0202A),
      ),
    ),
  ];

  static const List<ShopItem> lanterns = <ShopItem>[
    ShopItem(
      id: defaultLantern,
      category: ShopCategory.lantern,
      name: 'Amber Flame',
      text: 'A warm, honest light.',
      route: UnlockRoute.free,
      light: Color(0xFFF2B544),
    ),
    ShopItem(
      id: 'lantern_moonlight',
      category: ShopCategory.lantern,
      name: 'Moonlight',
      text: 'Pale and calm.',
      price: 300,
      light: Color(0xFFE4F2FF),
    ),
    ShopItem(
      id: 'lantern_spirit',
      category: ShopCategory.lantern,
      name: 'Spirit Fire',
      text: 'Burns blue like the safe candles.',
      price: 500,
      light: Color(0xFF9CC8F0),
    ),
    ShopItem(
      id: 'lantern_ember',
      category: ShopCategory.lantern,
      name: 'Ember Glow',
      text: 'Hot coals in an iron cage.',
      price: 800,
      light: Color(0xFFFF9A3C),
    ),
    ShopItem(
      id: 'lantern_ghostfire',
      category: ShopCategory.lantern,
      name: 'Ghostfire',
      text: 'A violet flame that never flickers.',
      price: 1200,
      light: Color(0xFFB48CF0),
    ),
    ShopItem(
      id: 'lantern_gold',
      category: ShopCategory.lantern,
      name: 'Royal Gold',
      text: 'Bright enough to scare shadows.',
      price: 1800,
      light: Color(0xFFFFE08A),
    ),
  ];

  static const List<ShopItem> trails = <ShopItem>[
    ShopItem(
      id: 'trail_none',
      category: ShopCategory.trail,
      name: 'No Trail',
      text: 'Leave nothing behind.',
      route: UnlockRoute.free,
      trail: TrailStyle.none,
    ),
    ShopItem(
      id: defaultTrail,
      category: ShopCategory.trail,
      name: 'Stone Dust',
      text: 'Footsteps kick up dust.',
      route: UnlockRoute.free,
      trail: TrailStyle.dust,
    ),
    ShopItem(
      id: 'trail_embers',
      category: ShopCategory.trail,
      name: 'Embers',
      text: 'Sparks from your lantern.',
      price: 250,
      trail: TrailStyle.embers,
    ),
    ShopItem(
      id: 'trail_wisps',
      category: ShopCategory.trail,
      name: 'Soul Wisps',
      text: 'Tiny spirits follow you.',
      price: 500,
      trail: TrailStyle.wisps,
    ),
    ShopItem(
      id: 'trail_sparkles',
      category: ShopCategory.trail,
      name: 'Starlight',
      text: 'Glittering steps.',
      price: 800,
      trail: TrailStyle.sparkles,
    ),
    ShopItem(
      id: 'trail_bones',
      category: ShopCategory.trail,
      name: 'Bone Chips',
      text: 'The crypt crumbles behind you.',
      price: 1200,
      trail: TrailStyle.bones,
    ),
  ];

  static const List<ShopItem> all = <ShopItem>[
    ...runners,
    ...lanterns,
    ...trails,
  ];

  static ShopItem? byId(String id) {
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }

  static List<ShopItem> of(ShopCategory category) => switch (category) {
    ShopCategory.runner => runners,
    ShopCategory.lantern => lanterns,
    ShopCategory.trail => trails,
  };

  static Set<String> get startingItems => {
    for (final item in all)
      if (item.route == UnlockRoute.free) item.id,
  };
}

/// What the runner looks like in a maze: the equipped items resolved.
@immutable
class RunnerLook {
  const RunnerLook({
    required this.palette,
    required this.light,
    required this.trail,
  });

  static final RunnerLook standard = RunnerLook.of(
    runnerId: ShopCatalog.defaultRunner,
    lanternId: ShopCatalog.defaultLantern,
    trailId: ShopCatalog.defaultTrail,
  );

  factory RunnerLook.of({
    required String runnerId,
    required String lanternId,
    required String trailId,
  }) {
    final runner =
        ShopCatalog.byId(runnerId)?.palette ??
        ShopCatalog.runners.first.palette!;
    final light =
        ShopCatalog.byId(lanternId)?.light ?? ShopCatalog.lanterns.first.light!;
    final trail = ShopCatalog.byId(trailId)?.trail ?? TrailStyle.dust;
    return RunnerLook(palette: runner, light: light, trail: trail);
  }

  final RunnerPalette palette;
  final Color light;
  final TrailStyle trail;
}
