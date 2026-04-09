import 'input_command.dart';
import 'input_event.dart';

abstract class InputHandler {
  const InputHandler();

  List<InputCommand> map(InputEvent event);
}

class StandardInputHandler extends InputHandler {
  const StandardInputHandler();

  @override
  List<InputCommand> map(InputEvent event) {
    switch (event.type) {
      case InputEventType.tap:
      case InputEventType.buttonJump:
      case InputEventType.swipeUp:
        return const <InputCommand>[InputCommand.jump()];
      case InputEventType.buttonFlip:
      case InputEventType.swipeLeft:
      case InputEventType.swipeRight:
      case InputEventType.swipeDown:
        return const <InputCommand>[InputCommand.flip()];
      case InputEventType.joystick:
        return <InputCommand>[
          InputCommand.move(
            dx: event.dx.clamp(-1, 1),
            dy: event.dy.clamp(-1, 1),
          ),
        ];
    }
  }
}
