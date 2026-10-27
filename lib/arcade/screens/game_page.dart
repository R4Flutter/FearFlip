import 'package:flutter/material.dart';

import '../../presentation/gameplay/game_screen.dart';
import '../arcade_controller.dart';
import '../arcade_run.dart';
import '../ui/kit.dart';
import 'world_map_screen.dart';

/// The maze, full screen, for one [GameSession].
class GamePage extends StatelessWidget {
  const GamePage({required this.session, super.key});

  final GameSession session;

  @override
  Widget build(BuildContext context) {
    final arcade = ArcadeScope.of(context);
    final progress = arcade.progress;
    final navigator = Navigator.of(context);
    return PopScope(
      canPop: false,
      child: GameScreen(
        arcadeRun: ArcadeRun(
          arcade: arcade,
          session: session,
          onExit: () => navigator.pop(),
          onOpenMap: (stage) {
            navigator.popUntil((route) => route.isFirst);
            navigator.push(fadeRoute<void>(WorldMapScreen(focusStage: stage)));
          },
        ),
        joystickSize: progress.padSize,
        useArrowController: progress.arrowPad,
      ),
    );
  }
}
