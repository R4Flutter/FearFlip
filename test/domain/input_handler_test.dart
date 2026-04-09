import 'package:flutter_test/flutter_test.dart';

import 'package:fearflipgame/domain/input/input_command.dart';
import 'package:fearflipgame/domain/input/input_event.dart';
import 'package:fearflipgame/domain/input/input_handler.dart';

void main() {
  const handler = StandardInputHandler();

  test('tap maps to jump command', () {
    final commands = handler.map(const InputEvent(type: InputEventType.tap));
    expect(commands.single.type, InputCommandType.jump);
  });

  test('swipe maps to flip command', () {
    final commands = handler.map(
      const InputEvent(type: InputEventType.swipeRight),
    );
    expect(commands.single.type, InputCommandType.flip);
  });

  test('joystick maps to clamped move command', () {
    final commands = handler.map(
      const InputEvent(type: InputEventType.joystick, dx: 3, dy: -3),
    );
    final cmd = commands.single;
    expect(cmd.type, InputCommandType.move);
    expect(cmd.dx, 1);
    expect(cmd.dy, -1);
  });
}
