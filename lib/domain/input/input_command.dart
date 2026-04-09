enum InputCommandType { jump, flip, move }

class InputCommand {
  const InputCommand._({required this.type, this.dx = 0, this.dy = 0});

  const InputCommand.jump() : this._(type: InputCommandType.jump);

  const InputCommand.flip() : this._(type: InputCommandType.flip);

  const InputCommand.move({required double dx, required double dy})
    : this._(type: InputCommandType.move, dx: dx, dy: dy);

  final InputCommandType type;
  final double dx;
  final double dy;
}
