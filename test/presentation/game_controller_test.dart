import 'package:flutter_test/flutter_test.dart';

import 'package:fearflipgame/domain/input/input_event.dart';
import 'package:fearflipgame/presentation/controllers/game_controller.dart';

void main() {
  test('controller starts and exposes state', () async {
    final controller = GameController();

    await controller.start(seed: 42);
    expect(controller.state, isNotNull);
    expect(controller.isPaused, isFalse);

    controller.dispose();
  });

  test('controller pause/resume toggles lifecycle', () async {
    final controller = GameController();
    await controller.start(seed: 42);

    controller.pause();
    expect(controller.isPaused, isTrue);

    controller.resume();
    expect(controller.isPaused, isFalse);

    controller.dispose();
  });

  test('controller maps input and ticks engine', () async {
    final controller = GameController();
    await controller.start(seed: 42);

    final before = controller.state!.controlsInverted;
    await controller.submitInput(
      const InputEvent(type: InputEventType.buttonFlip),
    );
    await controller.tick(0.016);
    final after = controller.state!.controlsInverted;

    expect(after, isNot(before));
    controller.dispose();
  });
}
