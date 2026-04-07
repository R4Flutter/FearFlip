import '../../data/database/local_session_database.dart';
import '../../game/game.dart';

class StartSurvivalUseCase {
  StartSurvivalUseCase({required LocalSessionDatabase sessionDatabase})
    : _sessionDatabase = sessionDatabase;

  final LocalSessionDatabase _sessionDatabase;

  Future<void> call(FearFlipGame game) async {
    _sessionDatabase.markRunStarted();
  }
}
