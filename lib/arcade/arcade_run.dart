import 'package:flutter/foundation.dart';

import 'arcade_controller.dart';

/// What the maze needs from the menus for one session: the services, the
/// session itself and the ways out.
@immutable
class ArcadeRun {
  const ArcadeRun({
    required this.arcade,
    required this.session,
    required this.onExit,
    required this.onOpenMap,
  });

  final ArcadeController arcade;
  final GameSession session;

  /// Back to the menu.
  final VoidCallback onExit;

  /// Back to the world map, showing [stage].
  final void Function(int stage) onOpenMap;
}
