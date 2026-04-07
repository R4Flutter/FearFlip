abstract class LeaderboardService {
  Future<void> submitRun({required int scoreSeconds, required String mode});
}

class StubLeaderboardService implements LeaderboardService {
  @override
  Future<void> submitRun({
    required int scoreSeconds,
    required String mode,
  }) async {
    // Firebase leaderboard integration point.
  }
}
