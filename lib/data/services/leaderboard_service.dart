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
    int limit = 30,
  }) {
    return _delegate.getLeaderboard(mode: mode, limit: limit);
  }

  Future<void> upsertGlobalPanicProgress({
    required int maxStage,
    required int totalTrophies,
    String? playerName,
  }) {
    return _delegate.upsertGlobalPanicProgress(
      maxStage: maxStage,
      totalTrophies: totalTrophies,
      playerName: playerName,
    );
  }

  Future<infra.LeaderboardSnapshot> getGlobalPanicLeaderboard({
    int limit = 30,
  }) {
    return _delegate.getGlobalPanicLeaderboard(limit: limit);
  }

  /// Real-time stream of Global Panic standings. The stream seeds from the
  /// offline cache immediately, then updates with live Firestore data.
  Stream<infra.LeaderboardSnapshot> globalPanicLeaderboardStream({
    int limit = 30,
  }) {
    return _delegate.globalPanicLeaderboardStream(limit: limit);
  }

  Future<int?> getGlobalPanicRank() {
    return _delegate.getGlobalPanicRank();
  }
}
