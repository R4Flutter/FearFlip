enum Direction8 {
  down,
  downLeft,
  left,
  upLeft,
  up,
  upRight,
  right,
  downRight,
}

extension Direction8Extension on Direction8 {
  bool get isDiagonal {
    return this == Direction8.downLeft ||
        this == Direction8.upLeft ||
        this == Direction8.upRight ||
        this == Direction8.downRight;
  }
}
