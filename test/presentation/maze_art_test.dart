import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fearflipgame/presentation/gameplay/maze_art.dart';

/// The real asset bundle, minus [missing].
class _HolesBundle extends CachingAssetBundle {
  _HolesBundle(this.missing);

  final Set<String> missing;

  @override
  Future<ByteData> load(String key) {
    if (missing.contains(key)) {
      throw FlutterError('missing $key');
    }
    return rootBundle.load(key);
  }
}

void main() {
  testWidgets('loads every delivered strip at its frame size', (tester) async {
    final art = (await tester.runAsync(MazeArt.load))!;
    addTearDown(art.dispose);

    void expectStrip(SpriteStrip? strip, int frames, double w, double h) {
      expect(strip, isNotNull);
      expect(strip!.frames, frames);
      expect(strip.frame(0).size, Size(w, h));
    }

    expectStrip(art.wakeTiles, 24, 128, 128);
    expectStrip(art.nightmareTiles, 24, 128, 128);
    expectStrip(art.start, 4, 128, 128);
    expectStrip(art.exitWake, 4, 128, 128);
    expectStrip(art.exitNightmare, 4, 128, 128);
    expectStrip(art.safe, 4, 128, 128);
    expectStrip(art.trapWake, 4, 128, 128);
    expectStrip(art.trapNightmare, 8, 128, 128);
    expectStrip(art.torch, 8, 64, 128);
    expectStrip(art.propsWake, 8, 128, 128);
    expectStrip(art.propsNightmare, 8, 128, 128);
    expectStrip(art.smoke, 5, 160, 160);
    expectStrip(art.debris, 5, 128, 128);
    expectStrip(art.sparkle, 4, 96, 96);
    expectStrip(art.wisp, 4, 96, 96);
    expectStrip(art.drip, 4, 48, 128);
    expectStrip(art.flip, 6, 128, 128);
    expectStrip(art.dust, 4, 64, 64);
    expectStrip(art.boneArrow, 1, 160, 96);
  });

  testWidgets('a missing file empties only its own slot', (tester) async {
    final art = (await tester.runAsync(
      () => MazeArt.load(
        bundle: _HolesBundle({'assets/images/2d/objects/torch.png'}),
      ),
    ))!;
    addTearDown(art.dispose);

    expect(art.torch, isNull);
    expect(art.start, isNotNull);
    expect(art.wakeTiles, isNotNull);
  });

  testWidgets('frames wrap and loop over time', (tester) async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 64, 16), ui.Paint());
    final image = recorder.endRecording().toImageSync(64, 16);
    addTearDown(image.dispose);
    final strip = SpriteStrip(image, 4);

    expect(strip.frame(1), const Rect.fromLTWH(16, 0, 16, 16));
    expect(strip.frame(5), strip.frame(1));
    expect(strip.loop(0, 6), 0);
    expect(strip.loop(0.5, 6), 3);
    expect(strip.loop(1, 6), 2); // frame 6 of a 4-frame loop
  });
}
