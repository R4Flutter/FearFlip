/// The loss screen's near miss: how close the run came.
///
/// "4 TILES FROM THE EXIT · 1 KEY SHORT" for [tilesToExit] steps left and
/// [keysShort] keys missing.
String nearMissText({required int tilesToExit, int keysShort = 0}) {
  final where = tilesToExit <= 0
      ? 'AT THE EXIT'
      : '$tilesToExit TILE${tilesToExit == 1 ? '' : 'S'} FROM THE EXIT';
  if (keysShort <= 0) {
    return where;
  }
  return '$where · $keysShort KEY${keysShort == 1 ? '' : 'S'} SHORT';
}

/// "2 STAGES TO CHECKPOINT 25", or the final stage once [milestone] is the
/// last one ([maxStage]).
String checkpointProgressText({
  required int stage,
  required int milestone,
  required int maxStage,
}) {
  final remaining = milestone - stage;
  if (remaining <= 0) {
    return 'THE FINAL STAGE';
  }
  final stages = '$remaining STAGE${remaining == 1 ? '' : 'S'}';
  return milestone >= maxStage
      ? '$stages TO THE FINAL STAGE'
      : '$stages TO CHECKPOINT $milestone';
}
