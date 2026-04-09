import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fearflipgame/data/database/local_session_database.dart';
import 'package:fearflipgame/domain/usecases/start_survival_use_case.dart';
import 'package:fearflipgame/presentation/gameplay/game_screen.dart';
import 'package:fearflipgame/presentation/providers/app_flow_provider.dart';

class _LandingToGameHarness extends StatefulWidget {
  const _LandingToGameHarness();

  @override
  State<_LandingToGameHarness> createState() => _LandingToGameHarnessState();
}

class _LandingToGameHarnessState extends State<_LandingToGameHarness> {
  bool _showGame = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: _showGame
            ? const GameScreen()
            : Center(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showGame = true;
                    });
                  },
                  child: const Text('START SURVIVAL'),
                ),
              ),
      ),
    );
  }
}

void main() {
  testWidgets('GameScreen renders game surface', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));
    await tester.pump();
    debugDumpApp();

    expect(find.byKey(GameScreen.gameSurfaceKey), findsOneWidget);
  });

  testWidgets('Start button navigates to GameScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const _LandingToGameHarness());

    expect(find.text('START SURVIVAL'), findsOneWidget);
    await tester.tap(find.text('START SURVIVAL'));
    await tester.pump();

    expect(find.byKey(GameScreen.gameSurfaceKey), findsOneWidget);
  });

  testWidgets('Restart action is wired and executable', (
    WidgetTester tester,
  ) async {
    var restartCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          onRestartWithAd: () async {
            restartCalls += 1;
            return true;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(restartCalls, 1);
  });

  testWidgets('Controller settings persist in provider', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final first = AppFlowProvider(
      sessionDatabase: LocalSessionDatabase(),
      startSurvivalUseCase: StartSurvivalUseCase(
        sessionDatabase: LocalSessionDatabase(),
      ),
      enableAuthBootstrap: false,
    );
    await first.updateJoystickSize(150);
    await first.updateUseArrowController(true);

    final second = AppFlowProvider(
      sessionDatabase: LocalSessionDatabase(),
      startSurvivalUseCase: StartSurvivalUseCase(
        sessionDatabase: LocalSessionDatabase(),
      ),
      enableAuthBootstrap: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    expect(second.useArrowController, isTrue);
    expect(second.joystickSize, 150);

    first.dispose();
    second.dispose();
  });

  testWidgets('Character selection persists in provider', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final first = AppFlowProvider(
      sessionDatabase: LocalSessionDatabase(),
      startSurvivalUseCase: StartSurvivalUseCase(
        sessionDatabase: LocalSessionDatabase(),
      ),
      enableAuthBootstrap: false,
    );
    await first.updateSelectedCharacter(1);

    final second = AppFlowProvider(
      sessionDatabase: LocalSessionDatabase(),
      startSurvivalUseCase: StartSurvivalUseCase(
        sessionDatabase: LocalSessionDatabase(),
      ),
      enableAuthBootstrap: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    expect(second.selectedCharacterIndex, 1);

    first.dispose();
    second.dispose();
  });
}
