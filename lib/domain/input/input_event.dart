enum InputEventType {
  tap,
  swipeUp,
  swipeDown,
  swipeLeft,
  swipeRight,
  joystick,
  buttonJump,
  buttonFlip,
}

class InputEvent {
  const InputEvent({required this.type, this.dx = 0, this.dy = 0});

  final InputEventType type;
  final double dx;
  final double dy;
}
