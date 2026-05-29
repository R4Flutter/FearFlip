import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/in_memory_game_repository.dart';
import '../../data/services/analytics_service.dart';
import '../../data/services/crash_reporting_service.dart';
import '../../data/services/monetization_service.dart';
import '../../domain/entities/game_state.dart';
import '../../domain/input/input_event.dart';
import '../../domain/input/input_handler.dart';
import '../../domain/progression/progression_manager.dart';
import '../../engine/fear_flip_game.dart';
import '../../engine/systems/frame_budget_monitor.dart';
import '../../services/ads_facade.dart';

class GameController extends ChangeNotifier {
  GameController({
    FearFlipGameEngine? engine,
    InputHandler? inputHandler,
    AnalyticsService? analytics,
    CrashReportingService? crashReporting,
    MonetizationService? monetization,
    ProgressionManager? progression,
    FrameBudgetMonitor? frameBudget,
  }) : _engine =
           engine ?? FearFlipGameEngine(repository: InMemoryGameRepository()),
       _inputHandler = inputHandler ?? const StandardInputHandler(),
       _analytics = analytics ?? NoopAnalyticsService(),
       _crashReporting = crashReporting ?? NoopCrashReportingService(),
      _monetization = monetization ?? AdsFacade.instance.monetization,
       _progression = progression ?? ProgressionManager(),
       _frameBudget = frameBudget ?? const FrameBudgetMonitor();

  final FearFlipGameEngine _engine;
  final InputHandler _inputHandler;
  final AnalyticsService _analytics;
  final CrashReportingService _crashReporting;
  final MonetizationService _monetization;
  final ProgressionManager _progression;
  final FrameBudgetMonitor _frameBudget;

  Timer? _loop;
  DateTime? _startedAt;
  bool _paused = false;
  int _flipCount = 0;
  GameState? _last;

  GameState? get state => _last;
  bool get isPaused => _paused;
  ProgressionSnapshot get progression => _progression.snapshot();

  Future<void> start({int seed = 42}) async {
    try {
      _startedAt = DateTime.now();
      _flipCount = 0;
      await _engine.start(seed: seed);
      _last = _engine.state;
      await _analytics.gameStart();
      _startLoop();
      notifyListeners();
    } catch (error, stack) {
      await _crashReporting.recordError(error, stack, reason: 'game_start');
    }
  }

  void pause() {
    _paused = true;
    _loop?.cancel();
    notifyListeners();
  }

  void resume() {
    if (!_paused) {
      return;
    }
    _paused = false;
    _startLoop();
    notifyListeners();
  }

  Future<void> restart({int seed = 42}) async {
    _loop?.cancel();
    await start(seed: seed);
  }

  Future<void> submitInput(InputEvent event) async {
    try {
      for (final command in _inputHandler.map(event)) {
        if (command.type.name == 'flip') {
          _flipCount += 1;
        }
        _engine.enqueueCommand(command);
      }
    } catch (error, stack) {
      await _crashReporting.recordError(error, stack, reason: 'input_submit');
    }
  }

  Future<bool> requestRevive() {
    return _monetization.showReviveRewardedAd();
  }

  Future<void> tick(double dtSeconds) async {
    final watch = Stopwatch()..start();
    try {
      await _engine.update(dtSeconds);
      final previous = _last;
      _last = _engine.state;
      notifyListeners();

      final next = _last;
      if (previous != null &&
          next != null &&
          !previous.controlsInverted &&
          next.controlsInverted) {
        await _analytics.flipUsage(flips: _flipCount);
      }

      if (next != null && next.gameOver) {
        await _onGameOver(next);
      }
    } catch (error, stack) {
      await _crashReporting.recordError(error, stack, reason: 'game_tick');
    } finally {
      watch.stop();
      _frameBudget.onFrame(watch.elapsed);
    }
  }

  void _startLoop() {
    _loop?.cancel();
    _loop = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (_paused) {
        return;
      }
      unawaited(tick(0.016));
    });
  }

  Future<void> _onGameOver(GameState state) async {
    final startedAt = _startedAt;
    final duration = startedAt == null
        ? state.elapsedSeconds.floor()
        : DateTime.now().difference(startedAt).inSeconds;

    await _analytics.gameOver(
      durationSeconds: duration,
      flipped: state.controlsInverted,
    );
    await _analytics.levelDuration(
      levelId: 'session',
      durationSeconds: duration,
    );
    if (duration < 5) {
      await _analytics.rageQuit(durationSeconds: duration);
    }
    _progression.recordSession(
      secondsSurvived: state.elapsedSeconds.floor(),
      flipsUsed: _flipCount,
    );
  }

  @override
  void dispose() {
    _loop?.cancel();
    super.dispose();
  }
}
