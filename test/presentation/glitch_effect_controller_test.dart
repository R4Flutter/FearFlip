import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fearflipgame/presentation/gameplay/glitch_effect_controller.dart';

void main() {
  test('disabled glitch controller never activates', () {
    final controller = GlitchEffectController(effectsEnabled: false);

    controller.trigger();
    controller.update(0.1);

    expect(controller.isActive, isFalse);
    expect(controller.channelOpacity, 0);
    expect(controller.rgbShiftPx, 0);
  });

  test('active glitch controller clears after duration', () {
    final controller = GlitchEffectController();

    controller.trigger(durationSeconds: 0.3);
    expect(controller.isActive, isTrue);

    controller.update(0.4);

    expect(controller.isActive, isFalse);
  });

  testWidgets('active glitch overlay renders a keyed child once', (
    tester,
  ) async {
    final controller = GlitchEffectController();
    final key = GlobalKey();

    controller.trigger(durationSeconds: 0.3);

    await tester.pumpWidget(
      MaterialApp(
        home: GlitchEffectOverlay(
          controller: controller,
          child: SizedBox(key: key, width: 24, height: 24),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(key), findsOneWidget);
  });
}
