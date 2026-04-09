class Player {
  const Player({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
  });

  final double x;
  final double y;
  final double vx;
  final double vy;

  Player copyWith({double? x, double? y, double? vx, double? vy}) {
    return Player(
      x: x ?? this.x,
      y: y ?? this.y,
      vx: vx ?? this.vx,
      vy: vy ?? this.vy,
    );
  }
}
