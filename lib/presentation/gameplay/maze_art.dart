import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One row of equal animation frames (the layout tool/process_2d_assets.py
/// writes).
class SpriteStrip {
  SpriteStrip(this.image, this.frames);

  final ui.Image image;
  final int frames;

  double get frameWidth => image.width / frames;

  /// Source rect of frame [index], wrapping past the last frame.
  Rect frame(int index) => Rect.fromLTWH(
    (index % frames) * frameWidth,
    0,
    frameWidth,
    image.height.toDouble(),
  );

  /// The frame of a looping animation at [fps], [seconds] in.
  int loop(double seconds, double fps) => (seconds * fps).floor() % frames;
}

/// The delivered 2D art under assets/images/2d. Every strip is optional: a
/// missing or broken file leaves its slot null and the painter keeps drawing
/// the stand-in it has today.
class MazeArt {
  MazeArt._(this._strips);

  /// An empty set, for before [load] finishes.
  MazeArt.none() : _strips = const {};

  static const _dir = 'assets/images/2d';

  /// Path (under [_dir]) → frames in the strip.
  static const Map<String, int> _files = {
    'tiles/wake_tiles.png': 24,
    'tiles/nightmare_tiles.png': 24,
    'objects/start.png': 4,
    'objects/exit_wake.png': 4,
    'objects/exit_nightmare.png': 4,
    'objects/safe.png': 4,
    'objects/trap_wake.png': 4,
    'objects/trap_nightmare.png': 8,
    'objects/torch.png': 8,
    'objects/props_wake.png': 8,
    'objects/props_nightmare.png': 8,
    'fx/smoke.png': 5,
    'fx/debris.png': 5,
    'fx/sparkle.png': 4,
    'fx/wisp.png': 4,
    'fx/drip.png': 4,
    'fx/flip.png': 6,
    'fx/dust.png': 4,
    'ui/bone_arrow.png': 1,
  };

  final Map<String, SpriteStrip> _strips;

  SpriteStrip? get wakeTiles => _strips['tiles/wake_tiles.png'];
  SpriteStrip? get nightmareTiles => _strips['tiles/nightmare_tiles.png'];
  SpriteStrip? get start => _strips['objects/start.png'];
  SpriteStrip? get exitWake => _strips['objects/exit_wake.png'];
  SpriteStrip? get exitNightmare => _strips['objects/exit_nightmare.png'];
  SpriteStrip? get safe => _strips['objects/safe.png'];
  SpriteStrip? get trapWake => _strips['objects/trap_wake.png'];
  SpriteStrip? get trapNightmare => _strips['objects/trap_nightmare.png'];
  SpriteStrip? get torch => _strips['objects/torch.png'];
  SpriteStrip? get propsWake => _strips['objects/props_wake.png'];
  SpriteStrip? get propsNightmare => _strips['objects/props_nightmare.png'];
  SpriteStrip? get smoke => _strips['fx/smoke.png'];
  SpriteStrip? get debris => _strips['fx/debris.png'];
  SpriteStrip? get sparkle => _strips['fx/sparkle.png'];
  SpriteStrip? get wisp => _strips['fx/wisp.png'];
  SpriteStrip? get drip => _strips['fx/drip.png'];
  SpriteStrip? get flip => _strips['fx/flip.png'];
  SpriteStrip? get dust => _strips['fx/dust.png'];
  SpriteStrip? get boneArrow => _strips['ui/bone_arrow.png'];

  static Future<MazeArt> load({AssetBundle? bundle}) async {
    final source = bundle ?? rootBundle;
    final loaded = await Future.wait(
      _files.entries.map((e) => _strip(source, e.key, e.value)),
    );
    return MazeArt._({
      for (final s in loaded)
        if (s != null) s.key: s.value,
    });
  }

  static Future<MapEntry<String, SpriteStrip>?> _strip(
    AssetBundle bundle,
    String path,
    int frames,
  ) async {
    try {
      final data = await bundle.load('$_dir/$path');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      codec.dispose();
      return MapEntry(path, SpriteStrip(frame.image, frames));
    } catch (error) {
      // Expected until a sheet is delivered; the stand-in drawing covers it.
      debugPrint('[MazeArt] $path not loaded: $error');
      return null;
    }
  }

  void dispose() {
    for (final s in _strips.values) {
      s.image.dispose();
    }
  }
}
