import '../../domain/entities/player.dart';

class PlayerComponentAdapter {
  const PlayerComponentAdapter();

  Player syncFromEngine(Player player) {
    // Adapter seam: map domain Player <-> Flame component state.
    return player;
  }
}
