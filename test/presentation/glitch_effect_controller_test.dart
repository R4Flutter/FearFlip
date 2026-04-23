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
}
