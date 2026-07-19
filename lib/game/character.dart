import 'package:flame/cache.dart';
import 'package:flame/components.dart';

// ── Frame-set mapping ────────────────────────────────────────────────────────
// There are 4 seven-frame PNG sets on disk (devil / phantom / sentinel /
// void_ripper) but 6 selectable in-game character ids. Each id is mapped to the
// on-disk set whose silhouette best fits its theme:
//
//   devil          -> devil        (horned menace — the obvious one)
//   turban_fighter -> sentinel     (armored, grounded guardian gait)
//   spear_raider   -> void_ripper  (lean, forward-lunging aggressor)
//   sword_knight   -> sentinel     (heavy knightly stride, shares sentinel)
//   pink_shadow    -> phantom      (translucent drifting ghost)
//   ember_rogue    -> void_ripper  (fast fiery skirmisher, shares void_ripper)
//
// Files load as assets/images/<set>_frames/<set>1.png … <set>7.png.

class FearFlipCharacter {
  const FearFlipCharacter({required this.id, required this.name});

  final String id;
  final String name;

  static final List<FearFlipCharacter> catalog = <FearFlipCharacter>[
    FearFlipCharacter(id: 'devil', name: 'Devil'),
    FearFlipCharacter(id: 'turban_fighter', name: 'Turban Fighter'),
    FearFlipCharacter(id: 'spear_raider', name: 'Spear Raider'),
    FearFlipCharacter(id: 'sword_knight', name: 'Sword Knight'),
    FearFlipCharacter(id: 'pink_shadow', name: 'Pink Shadow'),
    FearFlipCharacter(id: 'ember_rogue', name: 'Ember Rogue'),
  ];
}

/// Value object holding the 7 walk-cycle [Sprite]s for one character, plus the
/// timing knob ([stepPeriod]) that tunes how long a single foot-step lasts.
///
/// Frames are loaded once from disk (via [load]) and never reallocated; the
/// render loop reads them through [frameAt] with a plain index (no list literal,
/// no allocation).
class CharacterSpriteSet {
  CharacterSpriteSet(this.frames, {required this.stepPeriod});

  /// The 7 walk frames, in cycle order.
  final List<Sprite> frames;

  /// Seconds for one full step at reference speed. Bigger, heavier characters
  /// (the devil) use a longer period so their gait reads as slow and weighty.
  final double stepPeriod;

  int get frameCount => frames.length;

  Sprite frameAt(int index) => frames[index];

  static const int framesPerSet = 7;

  static const String defaultFrameSet = 'devil';

  static const Map<String, String> frameSetForId = <String, String>{
    'devil': 'devil',
    'turban_fighter': 'sentinel',
    'spear_raider': 'void_ripper',
    'sword_knight': 'sentinel',
    'pink_shadow': 'phantom',
    'ember_rogue': 'void_ripper',
  };

  /// On-disk frame set backing an in-game character id (see mapping comment).
  static String frameSetFor(String characterId) =>
      frameSetForId[characterId] ?? defaultFrameSet;

  /// Lazily loads the 7 `<frameSet>N.png` sprites through Flame's image cache.
  /// Safe to call repeatedly per frame set — [Images] caches the decoded images.
  static Future<CharacterSpriteSet> load(
    Images images,
    String frameSet, {
    double stepPeriod = 0.46,
  }) async {
    final loaded = <Sprite>[];
    for (var i = 1; i <= framesPerSet; i++) {
      final image = await images.load('${frameSet}_frames/$frameSet$i.png');
      loaded.add(Sprite(image));
    }
    return CharacterSpriteSet(loaded, stepPeriod: stepPeriod);
  }
}
