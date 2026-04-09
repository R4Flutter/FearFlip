import '../../services/leaderboard_service.dart' as infra;

class LeaderboardDataService {
  LeaderboardDataService({infra.LeaderboardService? delegate})
    : _delegate = delegate ?? infra.StubLeaderboardService();

  final infra.LeaderboardService _delegate;

  Future<void> submitRun({required int scoreSeconds, required String mode}) {
    return _delegate.submitRun(scoreSeconds: scoreSeconds, mode: mode);
  }

  Future<infra.LeaderboardSnapshot> getLeaderboard({
    required String mode,
    int limit = 20,
  }) {
    return _delegate.getLeaderboard(mode: mode, limit: limit);
  }
}
