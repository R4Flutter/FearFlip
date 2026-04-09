class ProgressionSnapshot {
  const ProgressionSnapshot({
    required this.totalScore,
    required this.currentLevel,
    required this.sessionReward,
    required this.unlocks,
    required this.difficultyScalar,
  });

  final int totalScore;
  final int currentLevel;
  final int sessionReward;
  final List<String> unlocks;
  final double difficultyScalar;
}

class ProgressionManager {
  int _totalScore = 0;
  int _currentLevel = 1;
  final List<String> _unlocks = <String>[];

  ProgressionSnapshot recordSession({
    required int secondsSurvived,
    required int flipsUsed,
  }) {
    final base = secondsSurvived;
    final bonus = (flipsUsed / 2).floor();
    final reward = (base + bonus).clamp(0, 5000);

    _totalScore += reward;
    _currentLevel = (_totalScore ~/ 300).clamp(1, 999);

    if (_totalScore >= 500 && !_unlocks.contains('skin_neon_runner')) {
      _unlocks.add('skin_neon_runner');
    }
    if (_totalScore >= 1200 && !_unlocks.contains('skin_phantom_gold')) {
      _unlocks.add('skin_phantom_gold');
    }

    return snapshot(sessionReward: reward);
  }

  ProgressionSnapshot snapshot({int sessionReward = 0}) {
    final scalar = (1 + (_currentLevel - 1) * 0.03).clamp(1, 3).toDouble();
    return ProgressionSnapshot(
      totalScore: _totalScore,
      currentLevel: _currentLevel,
      sessionReward: sessionReward,
      unlocks: List<String>.unmodifiable(_unlocks),
      difficultyScalar: scalar,
    );
  }
}
