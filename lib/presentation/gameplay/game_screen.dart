import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_palette.dart';
import '../../config/app_runtime_config.dart';
import '../../game/trap/trap_analytics.dart';
import '../../game/trap/trap_audio_controller.dart';
import '../../game/trap/trap_death_sequence.dart';
import '../../game/trap/trap_difficulty_scaler.dart';
import '../../game/trap/trap_placement_engine.dart';
import '../../game/trap/trap_state_controller.dart';
import '../../game/trap/trap_tile.dart';
import '../../services/audio_manager.dart';
import '../../services/game_audio_event.dart';
import 'glitch_effect_controller.dart';
import 'maze_generator.dart';
import 'maze_painter.dart';
import 'maze_shift_manager.dart';
import 'player_controller.dart';
import 'stage_rules.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    this.joystickSize = 110,
    this.useArrowController = false,
    this.selectedCharacterIndex = 0,
    this.totalTrophies = 0,
    this.isActive = true,
    this.onExitToDashboard = _noop,
    this.onStageCleared = _noopStageCleared,
    this.onRestartWithAd = _alwaysAllow,
    this.onReviveWithAd = _alwaysAllow,
    super.key,
  });

  static const ValueKey<String> gameSurfaceKey = ValueKey<String>(
    'game_surface',
  );

  final double joystickSize;
  final bool useArrowController;
  final int selectedCharacterIndex;
  final int totalTrophies;
  final bool isActive;
  final VoidCallback onExitToDashboard;
  final Future<void> Function(int clearedStage) onStageCleared;
  final Future<bool> Function() onRestartWithAd;
  final Future<bool> Function() onReviveWithAd;

  static void _noop() {}
  static Future<void> _noopStageCleared(int _) async {}

  static Future<bool> _alwaysAllow() async => true;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final MazeGenerator _generator = MazeGenerator();
  final AudioManager _audioManager = AudioManager.instance;
  final MazeShiftManager _mazeShiftManager = MazeShiftManager();
  final TrapPlacementEngine _trapPlacementEngine = const TrapPlacementEngine();
  final TrapStateController _trapStateController = TrapStateController();
  final TrapDifficultyScaler _trapDifficultyScaler =
      const TrapDifficultyScaler();
  final TrapAnalytics _trapAnalytics = TrapAnalytics();
  final GlitchEffectController _glitchEffectController =
      GlitchEffectController();
  final GlobalKey _gameSurfaceSizeKey = GlobalKey(
    debugLabel: 'game_surface_size',
  );
  late PlayerController _playerController;
  late AnimationController _stageClearController;
  late final TrapAudioController _trapAudioController;
  late final TrapDeathSequence _trapDeathSequence;
  ui.Image? _playerSprite;
  ui.Image? _breakingTrapTexture;
  // characters.png uses a 32x32 grid: 736x128 => 23 columns x 4 rows.
  static const int _spriteColumns = 23;
  static const int _spriteRows = 4;
  static const int _maxStage = 100;
  static const int _maxPlayableMazeSize = 17;
  static const int _safeZonesPerStage = 2;
  static const int _persistentSafeZonesUntilStage = 75;
  static const double _devilMinPathClearance = 0.30;
  static const int _defaultStageDurationSeconds = 105;
  static const double _stageTickSeconds = 0.05;

  int _difficulty = 10;
  int _stage = 1;
  int _remainingSeconds = _defaultStageDurationSeconds;
  late StageRule _stageRule;
  late MazeGrid _maze;
  bool _isStageTransition = false;
  bool _isTimeUpHandling = false;
  int _completedStage = 1;
  Timer? _countdownTimer;
  Timer? _stageTimer;
  final Random _random = Random();
  final Random _trapQuoteRandom = Random();
  double _stageElapsedSeconds = 0;
  double _nextFlipAtSeconds = 0;
  bool _controlsInverted = false;
  Point<int>? _devilCell;
  bool _devilSpawned = false;
  double _devilMoveAccumulator = 0;
  Point<int>? _lastPlayerCell;
  int _stepsSinceSafeZone = 0;
  bool _awaitingDevilRespawnSteps = false;
  final Map<Point<int>, double> _safeZones = <Point<int>, double>{};
  Map<Point<int>, int> _distanceFromStart = <Point<int>, int>{};
  int _startToGoalDistance = 0;
  bool _playerSafe = false;
  bool _showLossOverlay = false;
  bool _adActionInProgress = false;
  bool _lostByTime = false;
  bool _lostByTrap = false;
  bool _isPaused = false;
  bool _isExternallyInactive = false;
  bool _resetToCheckpointOnReactivation = false;
  bool _trapDeathInProgress = false;
  bool _trapLossAudioQueued = false;
  bool _roundResolved = false;
  String? _trapDeathQuote;
  int _playerStepCount = 0;
  TrapStageConfig _trapStageConfig = const TrapStageConfig(
    trapsEnabled: false,
    trapCount: 0,
    allowChokepoints: false,
    hiddenCueLevel: 0,
    criticalTriggerDistance: 1,
  );
  int _audioFrameId = 0;
  int? _lastReportedDevilDistanceTiles;
  bool? _lastReportedDevilEnabled;
  bool? _lastReportedSafeZoneImmune;
  double _devilDistanceSampleElapsed = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stageRule = StageRules.forStage(_stage);
    _difficulty = _difficultyForStage(_stage);
    _maze = _generator.generate(rows: _difficulty, cols: _difficulty);
    _rebuildPathMetrics();
    _playerController = PlayerController(
      maze: _maze,
      onWin: _loadNextMaze,
      animationFrameCount: _spriteColumns,
      animationFrameStepMs: 80,
    );
    _trapAudioController = TrapAudioController(audioManager: _audioManager);
    _trapDeathSequence = TrapDeathSequence(
      vsync: this,
      onComplete: _onTrapDeathSequenceComplete,
    );
    _trapStateController.onCriticalTrigger = _onTrapCriticalTriggered;
    _trapStateController.onHiddenSuspicionCue = _onTrapHiddenSuspicionCue;

    _stageClearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    unawaited(_audioManager.preload());
    _isExternallyInactive = !widget.isActive;
    _applyStageRule(resetMaze: false);
    unawaited(_audioManager.handle(GameAudioEvent.matchStart));
    unawaited(
      _audioManager.handle(
        GameAudioEvent.timeChanged,
        secondsLeft: _remainingSeconds,
      ),
    );
    if (_isExternallyInactive) {
      unawaited(_audioManager.handle(GameAudioEvent.matchPause));
    }
    _startCountdown();
    _startStageLoop();
    _loadCharactersSprite();
    _loadBreakingTrapTexture();
  }

  @override
  void didUpdateWidget(covariant GameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _handleExternalActivityChange(widget.isActive);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) {
      return;
    }

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _handleExternalActivityChange(false);
        break;
      case AppLifecycleState.resumed:
        _handleExternalActivityChange(widget.isActive);
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  void _handleExternalActivityChange(bool isActive) {
    final shouldBeInactive = !isActive;
    if (_isExternallyInactive == shouldBeInactive) {
      return;
    }

    _isExternallyInactive = shouldBeInactive;
    if (_isExternallyInactive) {
      _playerController.stop();
      unawaited(_audioManager.handle(GameAudioEvent.matchPause));
    } else {
      if (_resetToCheckpointOnReactivation) {
        _resetToCheckpointOnReactivation = false;
        _resetToCheckpoint();
        return;
      }

      unawaited(_audioManager.handle(GameAudioEvent.matchResume));
      unawaited(
        _audioManager.handle(
          GameAudioEvent.timeChanged,
          secondsLeft: _remainingSeconds,
        ),
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadNextMaze() async {
    if (!mounted || _roundResolved || _isStageTransition || _showLossOverlay) {
      return;
    }

    _roundResolved = true;

    _playerController.stop();
    _countdownTimer?.cancel();

    try {
      await _audioManager.stopAlarmImmediately();
    } catch (_) {
      // Keep stage transition crash-safe if alarm stop fails.
    }

    setState(() {
      _isStageTransition = true;
      _completedStage = _stage;
    });

    try {
      await _audioManager.handle(GameAudioEvent.playerWon);
    } catch (_) {
      // Keep stage transition crash-safe if audio dispatch fails.
    }

    try {
      await widget.onStageCleared(_stage).timeout(const Duration(seconds: 3));
    } catch (_) {
      // Keep stage progression crash-safe even if trophy persistence fails.
    }

    await _stageClearController.forward(from: 0);
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) {
      return;
    }

    setState(() {
      _stage = min(_stage + 1, _maxStage);
      _stageRule = StageRules.forStage(_stage);
      _difficulty = _difficultyForStage(_stage);
      _maze = _generator.generate(rows: _difficulty, cols: _difficulty);
      _rebuildPathMetrics();
      _remainingSeconds = _stageDurationSeconds;
      _isStageTransition = false;
    });

    _playerController.resetForMaze(_maze);
    _applyStageRule(resetMaze: false);
    unawaited(_audioManager.handle(GameAudioEvent.matchRestart));
    _restartCountdown();
  }

  String get _modeLabel {
    return _controlsInverted ? 'FLIPPED' : 'NORMAL';
  }

  int get _checkpoint {
    if (_stage >= 75) {
      return 75;
    }
    if (_stage >= 50) {
      return 50;
    }
    if (_stage >= 25) {
      return 25;
    }
    return 0;
  }

  int _difficultyForStage(int stage) {
    if (stage <= StageRules.maxDefinedStage) {
      return StageRules.forStage(
        stage,
      ).mazeSize.clamp(10, _maxPlayableMazeSize);
    }
    final normalized = stage.clamp(1, _maxStage);
    return min(10 + (normalized - 1), _maxPlayableMazeSize);
  }

  int _stageDurationFor(int stage) {
    return _defaultStageDurationSeconds;
  }

  int get _stageDurationSeconds => _stageDurationFor(_stage);

  bool get _isPanic => _remainingSeconds <= 10;

  String get _timeLabel {
    final mins = _remainingSeconds ~/ 60;
    final secs = _remainingSeconds % 60;
    return 'TIME: $mins:${secs.toString().padLeft(2, '0')}';
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      if (_roundResolved || _isStageTransition) {
        return;
      }
      if (_showLossOverlay) {
        return;
      }
      if (_trapDeathInProgress) {
        return;
      }
      if (_isExternallyInactive || _isPaused) {
        return;
      }
      if (_remainingSeconds <= 0) {
        _countdownTimer?.cancel();
        if (_playerReachedGoal) {
          unawaited(_loadNextMaze());
        } else {
          unawaited(_onTimeExpired());
        }
        return;
      }
      setState(() {
        _remainingSeconds -= 1;
      });

      unawaited(
        _audioManager.handle(
          GameAudioEvent.timeChanged,
          secondsLeft: _remainingSeconds,
        ),
      );

      if (_remainingSeconds <= 0) {
        _countdownTimer?.cancel();
        if (_playerReachedGoal) {
          unawaited(_loadNextMaze());
        } else {
          unawaited(_onTimeExpired());
        }
      }
    });
  }

  void _startStageLoop() {
    _stageTimer?.cancel();
    _stageTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => _onStageTick(),
    );
  }

  void _onStageTick() {
    if (!mounted ||
        _roundResolved ||
        _isStageTransition ||
        _isTimeUpHandling ||
        _showLossOverlay ||
        _trapDeathInProgress ||
        _isExternallyInactive ||
        _isPaused) {
      return;
    }

    final dt = _stageTickSeconds;
    var shouldRebuild = false;
    _audioFrameId += 1;
    _stageElapsedSeconds += dt;

    // Reaching the golden goal tile always wins and advances to next stage.
    if (_playerController.position == _maze.end) {
      unawaited(_loadNextMaze());
      return;
    }

    _mazeShiftManager.tick(dt);
    final wasGlitchActive = _glitchEffectController.isActive;
    _glitchEffectController.update(dt);
    if (wasGlitchActive && !_glitchEffectController.isActive) {
      unawaited(_audioManager.handle(GameAudioEvent.mazeShiftEnded));
    }
    if (wasGlitchActive || _glitchEffectController.isActive) {
      shouldRebuild = true;
    }

    final timeToFlip = _nextFlipAtSeconds - _stageElapsedSeconds;
    if (timeToFlip <= _stageRule.warningTime && timeToFlip > 0) {}

    if (_stageElapsedSeconds >= _nextFlipAtSeconds) {
      _controlsInverted = !_controlsInverted;
      _playerController.setControlsInverted(_controlsInverted);
      unawaited(
        _audioManager.handle(
          GameAudioEvent.flipTriggered,
          frameId: _audioFrameId,
        ),
      );
      _nextFlipAtSeconds = _stageElapsedSeconds + _nextFlipInterval();
      shouldRebuild = true;
    }

    final wasPlayerSafe = _playerSafe;
    _updateSafeZones();
    if (!wasPlayerSafe && _playerSafe) {
      _onSafeZoneEntered();
      shouldRebuild = true;
    } else if (wasPlayerSafe && !_playerSafe) {
      unawaited(_audioManager.handle(GameAudioEvent.safeZoneExited));
      shouldRebuild = true;
    }

    final playerMoved = _trackPlayerSteps();
    TrapTile? pendingTrapCollapse;

    if (_trapStageConfig.trapsEnabled &&
        _trapStateController.activeTiles.isNotEmpty) {
      if (playerMoved) {
        final playerCell = _playerController.position;
        final trapStepResult = _trapStateController.onPlayerStep(
          playerCell,
          playerStepCount: _playerStepCount,
        );

        switch (trapStepResult) {
          case TrapStepResult.noTrap:
            break;
          case TrapStepResult.trapRevealed:
            _trapAudioController.playCrackReveal();
            final tile = _trapStateController.trapAt(playerCell);
            if (tile != null) {
              _trapAnalytics.record(
                stage: _stage,
                eventType: 'crack_reveal',
                cell: tile.cell,
                topology: tile.topology,
                playerStepCount: _playerStepCount,
                secondsElapsed: _stageElapsedSeconds,
                devilActive: _devilSpawned && _devilCell != null,
                controlsInverted: _controlsInverted,
                trapsTriggeredThisRun: _trapStateController.triggeredCount,
                secondsRemaining: _remainingSeconds,
                placementScore: tile.placementScore,
                revisitScore: tile.revisitScore,
                pressureTags: tile.pressureTags,
                distanceToGoal: _maze.shortestPathDistance(
                  playerCell,
                  _maze.end,
                ),
              );
            }
            shouldRebuild = true;
            break;
          case TrapStepResult.trapCollapsed:
            final tile = _trapStateController.trapAt(playerCell);
            if (tile != null) {
              tile.collapseProgress = 1;
              pendingTrapCollapse = tile;
            }
            shouldRebuild = true;
            break;
        }
      }

      _trapStateController.update(
        dt,
        _playerController.position,
        criticalDistance: _trapStageConfig.criticalTriggerDistance,
        playerStepCount: _playerStepCount,
        panicMode: _isPanic,
        devilCell: _devilCell,
        hiddenCueLevel: _trapStageConfig.hiddenCueLevel,
      );
      shouldRebuild = true;
    }

    _maybeTriggerMazeShift();

    final hazardGraceActive = _mazeShiftManager.hazardGraceActive;
    if (_canSpawnDevilNow()) {
      _devilSpawned = true;
      _devilCell = _spawnDevilCell();
      shouldRebuild = true;
    }

    if (_devilSpawned && _devilCell != null) {
      final previousDevilCell = _devilCell;
      if (!hazardGraceActive) {
        _devilMoveAccumulator += dt;
        final playerSpeed = _stageRule.playerSpeedMultiplier <= 0
            ? 1.0
            : _stageRule.playerSpeedMultiplier;
        final speedRatio = (_stageRule.devilSpeedMultiplier / playerSpeed)
            .clamp(0.0, 1.0);
        final baseDevilSpeed = _stageRule.devilStepsPerSecond * speedRatio;

        // ── Distance-based rubber-band speed factor ──
        // Devil slows when very close (breathing room) and sprints when far
        // (aggressive chase). Piecewise-linear between nearDist and farDist.
        final double dx =
            (_devilCell!.x - _playerController.position.x).toDouble();
        final double dy =
            (_devilCell!.y - _playerController.position.y).toDouble();
        final double euclideanDist = sqrt(dx * dx + dy * dy);
        final double mapDiag = sqrt(
          pow(_maze.cols - 1, 2).toDouble() +
              pow(_maze.rows - 1, 2).toDouble(),
        );
        final double nearDist = 0.25 * mapDiag;
        final double farDist = 0.75 * mapDiag;
        const double minFactor = 0.7; // slow when close
        const double maxFactor = 1.5; // sprint when far
        double distanceFactor;
        if (euclideanDist <= nearDist) {
          distanceFactor = minFactor;
        } else if (euclideanDist >= farDist) {
          distanceFactor = maxFactor;
        } else {
          final double t =
              (euclideanDist - nearDist) / (farDist - nearDist);
          distanceFactor = minFactor + (maxFactor - minFactor) * t;
        }
        final devilStepsPerSecond =
            (baseDevilSpeed * distanceFactor).clamp(0.2, 4.0);
        final stepInterval = 1.0 / devilStepsPerSecond;
        while (_devilMoveAccumulator >= stepInterval) {
          _devilMoveAccumulator -= stepInterval;
          _devilCell = _nextDevilStep(_devilCell!, _playerController.position);
        }
      } else {
        _devilMoveAccumulator = 0;
      }

      if (_devilCell != previousDevilCell) {
        shouldRebuild = true;
      }

      _devilDistanceSampleElapsed += dt;
      if (_devilDistanceSampleElapsed >= 0.10 ||
          _devilCell != previousDevilCell) {
        _devilDistanceSampleElapsed = 0;
        final distanceCells =
            _maze.shortestPathDistance(
              _devilCell!,
              _playerController.position,
            ) ??
            99;
        final devilAudioEnabled = distanceCells <= 6;
        _dispatchDevilDistance(
          distanceTiles: distanceCells,
          devilEnabled: devilAudioEnabled,
        );
      }

      final playerCell = _playerController.position;
      final crossedThroughEachOther =
          previousDevilCell != null &&
          previousDevilCell == playerCell &&
          _lastPlayerCell == _devilCell;

      if ((_devilCell == playerCell || crossedThroughEachOther) &&
          !_playerSafe &&
          !hazardGraceActive) {
        unawaited(_onDevilCaught());
      }
    } else {
      _devilDistanceSampleElapsed = 0;
      _dispatchDevilDistance(distanceTiles: 99, devilEnabled: false);
    }

    if (pendingTrapCollapse != null && !_roundResolved) {
      unawaited(_onTrapCollapsed(pendingTrapCollapse));
      if (shouldRebuild && mounted) {
        setState(() {});
      }
      return;
    }

    if (shouldRebuild && mounted) {
      setState(() {});
    }
  }

  void _dispatchDevilDistance({
    required int distanceTiles,
    required bool devilEnabled,
  }) {
    final safeZoneImmune = _playerSafe;
    if (_lastReportedDevilDistanceTiles == distanceTiles &&
        _lastReportedDevilEnabled == devilEnabled &&
        _lastReportedSafeZoneImmune == safeZoneImmune) {
      return;
    }

    _lastReportedDevilDistanceTiles = distanceTiles;
    _lastReportedDevilEnabled = devilEnabled;
    _lastReportedSafeZoneImmune = safeZoneImmune;
    unawaited(
      _audioManager.handle(
        GameAudioEvent.devilDistanceChanged,
        devilDistanceTiles: distanceTiles,
        devilEnabled: devilEnabled,
        safeZoneImmune: safeZoneImmune,
      ),
    );
  }

  Future<void> _onDevilCaught() async {
    if (!mounted ||
        _roundResolved ||
        _isTimeUpHandling ||
        _isStageTransition ||
        _showLossOverlay ||
        _trapDeathInProgress) {
      return;
    }
    _roundResolved = true;
    _isTimeUpHandling = true;
    _isPaused = false;
    _countdownTimer?.cancel();
    _playerController.stop();
    try {
      await _audioManager.handle(GameAudioEvent.playerLost);
    } catch (_) {
      // Keep fail flow crash-safe if audio dispatch fails.
    }
    setState(() {
      _showLossOverlay = true;
      _lostByTime = false;
      _lostByTrap = false;
      _trapDeathQuote = null;
    });
    _isTimeUpHandling = false;
  }

  void _applyStageRule({required bool resetMaze}) {
    if (resetMaze) {
      _maze = _generator.generate(rows: _difficulty, cols: _difficulty);
      _playerController.resetForMaze(_maze);
    }

    _playerController.setSpeedMultiplier(_stageRule.playerSpeedMultiplier);
    _controlsInverted = false;
    _playerController.setControlsInverted(false);
    _stageElapsedSeconds = 0;
    _nextFlipAtSeconds = _stageRule.firstFlipDelay;
    _devilCell = null;
    _devilSpawned = false;
    _devilMoveAccumulator = 0;
    _devilDistanceSampleElapsed = 0;
    _lastPlayerCell = _maze.start;
    _playerStepCount = 0;
    _stepsSinceSafeZone = 0;
    _awaitingDevilRespawnSteps = false;
    _playerSafe = false;
    _lastReportedDevilDistanceTiles = null;
    _lastReportedDevilEnabled = null;
    _lastReportedSafeZoneImmune = null;
    _trapDeathInProgress = false;
    _trapLossAudioQueued = false;
    _trapDeathQuote = null;
    _trapDeathSequence.cancel();
    _trapAudioController.reset();
    _rebuildPathMetrics();
    _mazeShiftManager.startStage(
      stage: _stage,
      totalSteps: _mazeShiftTotalSteps,
    );
    _resetSafeZones();
    _rebuildTrapTilesForCurrentStage();
    _showLossOverlay = false;
    _adActionInProgress = false;
    _lostByTime = false;
    _lostByTrap = false;
    _isPaused = false;
    _roundResolved = false;
    _glitchEffectController.clear();
  }

  void _rebuildTrapTilesForCurrentStage() {
    final walkableCellCount = _distanceFromStart.length;
    _trapStageConfig = _trapDifficultyScaler.configForStage(
      stage: _stage,
      walkableCellCount: walkableCellCount,
    );

    final forceStageOneTestTrap = _shouldForceStageOneTestTrap();
    if (forceStageOneTestTrap) {
      _trapStageConfig = TrapStageConfig(
        trapsEnabled: true,
        trapCount: max(1, _trapStageConfig.trapCount),
        allowChokepoints: _trapStageConfig.allowChokepoints,
        hiddenCueLevel: max(0.25, _trapStageConfig.hiddenCueLevel),
        criticalTriggerDistance: max(
          1,
          _trapStageConfig.criticalTriggerDistance,
        ),
      );
    }

    if (!_trapStageConfig.trapsEnabled || _trapStageConfig.trapCount <= 0) {
      _trapStateController.reset(const <TrapTile>[]);
      return;
    }

    final seed = _stageTrapSeed();
    final placedTiles = _trapPlacementEngine.placeTiles(
      maze: _maze,
      stage: _stage,
      seed: seed,
      config: _trapDifficultyScaler.config,
    );

    final filteredTiles = placedTiles
        .where((tile) => !_safeZones.containsKey(tile.cell))
        .toList(growable: true);

    if (forceStageOneTestTrap) {
      _injectStageOneTestTrap(
        filteredTiles,
        stageSeed: seed,
        maxTiles: _trapDifficultyScaler.config.maxTrapCount,
      );
    }

    _trapStateController.reset(filteredTiles.toList(growable: false));
  }

  bool _shouldForceStageOneTestTrap() {
    return _stage == 1 && AppRuntimeConfig.stageOneSixthTileTrapEnabled;
  }

  void _injectStageOneTestTrap(
    List<TrapTile> tiles, {
    required int stageSeed,
    required int maxTiles,
  }) {
    final targetCell = _stageOneTestTrapCell();
    if (targetCell == null) {
      return;
    }
    _safeZones.remove(targetCell);
    if (tiles.any((tile) => tile.cell == targetCell)) {
      return;
    }

    if (maxTiles <= 0) {
      return;
    }

    if (tiles.length >= maxTiles) {
      final removalIndex = tiles.indexWhere(
        (tile) => tile.topology != TileTopology.tJunction,
      );
      if (removalIndex >= 0) {
        tiles.removeAt(removalIndex);
      } else if (tiles.isNotEmpty) {
        tiles.removeLast();
      }
    }

    tiles.add(
      TrapTile(
        cell: targetCell,
        crackSeed: _trapCrackSeedForCell(targetCell, stageSeed),
        topology: TileTopology.corridor,
      ),
    );
  }

  Point<int>? _stageOneTestTrapCell() {
    final preferredPath = _shortestPathCells(_maze.start, _maze.end);
    if (preferredPath.length > 6) {
      return preferredPath[5];
    }
    if (preferredPath.length > 2) {
      return preferredPath[preferredPath.length - 2];
    }

    final sortedByDistance = _distanceFromStart.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    var eligibleSeen = 0;
    for (final entry in sortedByDistance) {
      final cell = entry.key;
      if (!_isEligibleStageOneTestTrapCell(cell)) {
        continue;
      }
      eligibleSeen += 1;
      if (eligibleSeen >= 6) {
        return cell;
      }
    }

    return null;
  }

  bool _isEligibleStageOneTestTrapCell(Point<int> cell) {
    if (cell == _maze.start || cell == _maze.end) {
      return false;
    }
    return true;
  }

  List<Point<int>> _shortestPathCells(Point<int> from, Point<int> to) {
    final parent = <Point<int>, Point<int>?>{from: null};
    final queue = <Point<int>>[from];
    var index = 0;

    while (index < queue.length) {
      final current = queue[index++];
      if (current == to) {
        break;
      }

      for (final direction in Direction4.values) {
        if (!_maze.canMove(current, direction)) {
          continue;
        }
        final next = _maze.move(current, direction);
        if (parent.containsKey(next)) {
          continue;
        }
        parent[next] = current;
        queue.add(next);
      }
    }

    if (!parent.containsKey(to)) {
      return const <Point<int>>[];
    }

    final path = <Point<int>>[];
    Point<int>? cursor = to;
    while (cursor != null) {
      path.add(cursor);
      cursor = parent[cursor];
    }
    return path.reversed.toList(growable: false);
  }

  int _trapCrackSeedForCell(Point<int> cell, int stageSeed) {
    return cell.x * 7919 + cell.y * 104729 + stageSeed;
  }

  int _stageTrapSeed() {
    final endHash = (_maze.end.x * 31) ^ (_maze.end.y * 17);
    return (_stage * 73856093) ^
        (_maze.rows * 19349663) ^
        (_maze.cols * 83492791) ^
        endHash;
  }

  void _onTrapHiddenSuspicionCue(TrapTile tile) {
    _trapAudioController.playHiddenCreak();
    _trapAnalytics.record(
      stage: _stage,
      eventType: 'hidden_suspicion_cue',
      cell: tile.cell,
      topology: tile.topology,
      playerStepCount: _playerStepCount,
      secondsElapsed: _stageElapsedSeconds,
      devilActive: _devilSpawned && _devilCell != null,
      controlsInverted: _controlsInverted,
      trapsTriggeredThisRun: _trapStateController.triggeredCount,
      secondsRemaining: _remainingSeconds,
      placementScore: tile.placementScore,
      revisitScore: tile.revisitScore,
      pressureTags: tile.pressureTags,
      distanceToGoal: _maze.shortestPathDistance(
        _playerController.position,
        _maze.end,
      ),
    );
  }

  void _onTrapCriticalTriggered(TrapTile tile) {
    _trapAudioController.playCriticalEscalation();
    final distanceToGoal = _maze.shortestPathDistance(
      _playerController.position,
      _maze.end,
    );
    _trapAnalytics.record(
      stage: _stage,
      eventType: 'critical_trigger',
      cell: tile.cell,
      topology: tile.topology,
      playerStepCount: _playerStepCount,
      secondsElapsed: _stageElapsedSeconds,
      devilActive: _devilSpawned && _devilCell != null,
      controlsInverted: _controlsInverted,
      trapsTriggeredThisRun: _trapStateController.triggeredCount,
      secondsRemaining: _remainingSeconds,
      stepsSinceReveal: tile.stepsSinceReveal(_playerStepCount),
      placementScore: tile.placementScore,
      revisitScore: tile.revisitScore,
      pressureTags: tile.pressureTags,
      distanceToGoal: distanceToGoal,
    );
    _trapAnalytics.record(
      stage: _stage,
      eventType: 'near_miss',
      cell: tile.cell,
      topology: tile.topology,
      playerStepCount: _playerStepCount,
      secondsElapsed: _stageElapsedSeconds,
      devilActive: _devilSpawned && _devilCell != null,
      controlsInverted: _controlsInverted,
      trapsTriggeredThisRun: _trapStateController.triggeredCount,
      secondsRemaining: _remainingSeconds,
      stepsSinceReveal: tile.stepsSinceReveal(_playerStepCount),
      placementScore: tile.placementScore,
      revisitScore: tile.revisitScore,
      pressureTags: tile.pressureTags,
      distanceToGoal: distanceToGoal,
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _onTrapCollapsed(TrapTile? tile) async {
    if (tile == null ||
        !mounted ||
        _roundResolved ||
        _isTimeUpHandling ||
        _isStageTransition ||
        _showLossOverlay ||
        _trapDeathInProgress) {
      return;
    }

    _roundResolved = true;
    _isTimeUpHandling = true;
    _isPaused = false;
    _countdownTimer?.cancel();
    _playerController.stop();

    final playerCell = _playerController.position;
    final distanceToGoal = _maze.shortestPathDistance(playerCell, _maze.end);
    _trapDeathQuote = TrapDeathQuotes.pick(
      random: _trapQuoteRandom,
      wasNearGoal: (distanceToGoal ?? 99) <= 3,
    );
    _trapAnalytics.record(
      stage: _stage,
      eventType: 'trap_death',
      cell: tile.cell,
      topology: tile.topology,
      playerStepCount: _playerStepCount,
      secondsElapsed: _stageElapsedSeconds,
      devilActive: _devilSpawned && _devilCell != null,
      controlsInverted: _controlsInverted,
      trapsTriggeredThisRun: _trapStateController.triggeredCount,
      secondsRemaining: _remainingSeconds,
      stepsSinceReveal: tile.stepsSinceReveal(_playerStepCount),
      placementScore: tile.placementScore,
      revisitScore: tile.revisitScore,
      pressureTags: tile.pressureTags,
      distanceToGoal: distanceToGoal,
    );

    _queueTrapLossAudio();

    final metrics = _trapSurfaceMetrics();
    if (metrics == null) {
      await _finalizeTrapDeath(withCinematic: false);
      return;
    }

    setState(() {
      _trapDeathInProgress = true;
      _lostByTrap = true;
      _lostByTime = false;
    });

    _trapDeathSequence.start(
      trapCenter: _cellCenterOnSurface(tile.cell, metrics),
      cellSize: metrics.cellSize,
    );
  }

  void _queueTrapLossAudio() {
    if (_trapLossAudioQueued) {
      return;
    }
    _trapLossAudioQueued = true;
    unawaited(_playTrapLossAudioSafely());
  }

  Future<void> _playTrapLossAudioSafely() async {
    try {
      await _trapAudioController.playTrapDeath();
    } catch (_) {
      // Keep trap death flow crash-safe if audio dispatch fails.
    }
  }

  void _onTrapDeathSequenceComplete() {
    unawaited(_finalizeTrapDeath(withCinematic: true));
  }

  Future<void> _finalizeTrapDeath({required bool withCinematic}) async {
    if (!mounted) {
      return;
    }

    _trapDeathInProgress = false;
    _lostByTrap = true;
    _lostByTime = false;

    if (!mounted) {
      return;
    }

    setState(() {
      _showLossOverlay = true;
    });

    _isTimeUpHandling = false;
    if (!withCinematic) {
      _trapDeathSequence.cancel();
    }
  }

  _TrapSurfaceMetrics? _trapSurfaceMetrics() {
    final context = _gameSurfaceSizeKey.currentContext;
    if (context == null) {
      return null;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }

    final size = renderObject.size;
    final cellSize = min(size.width / _maze.cols, size.height / _maze.rows);
    final mazeWidth = cellSize * _maze.cols;
    final mazeHeight = cellSize * _maze.rows;
    final origin = Offset(
      (size.width - mazeWidth) * 0.5,
      (size.height - mazeHeight) * 0.5,
    );

    return _TrapSurfaceMetrics(origin: origin, cellSize: cellSize);
  }

  Offset _cellCenterOnSurface(Point<int> cell, _TrapSurfaceMetrics metrics) {
    return Offset(
      metrics.origin.dx + (cell.x + 0.5) * metrics.cellSize,
      metrics.origin.dy + (cell.y + 0.5) * metrics.cellSize,
    );
  }

  double _nextFlipInterval() {
    final minR = _stageRule.flipRandomnessMin;
    final maxR = _stageRule.flipRandomnessMax;
    final r = minR == maxR
        ? minR
        : (minR + _random.nextDouble() * (maxR - minR));
    final jitter = (_random.nextDouble() * 2 - 1) * r;
    return (_stageRule.baseFlipInterval * (1 + jitter)).clamp(1.0, 12.0);
  }

  bool _canSpawnDevilNow() {
    if (!_stageRule.devilEnabled || _devilSpawned) {
      return false;
    }
    if (_playerSafe) {
      return false;
    }
    if (_stageElapsedSeconds < _stageRule.devilSpawnDelay) {
      return false;
    }
    if (_awaitingDevilRespawnSteps &&
        _stepsSinceSafeZone < _devilRespawnStepsForStage()) {
      return false;
    }
    return _pathClearanceProgress() >= _devilMinPathClearance;
  }

  void _onSafeZoneEntered() {
    unawaited(_audioManager.handle(GameAudioEvent.safeZoneEntered));

    if (!_stageRule.devilEnabled) {
      return;
    }
    _devilCell = null;
    _devilSpawned = false;
    _devilMoveAccumulator = 0;
    _devilDistanceSampleElapsed = 0;
    _dispatchDevilDistance(distanceTiles: 99, devilEnabled: false);
    _stepsSinceSafeZone = 0;
    _awaitingDevilRespawnSteps = true;
  }

  int _devilRespawnStepsForStage() {
    final t = ((_stage - 1) / (_maxStage - 1)).clamp(0.0, 1.0);
    final earlySteps = 5.0;
    final lateSteps = 2.0;
    final steps = earlySteps + (lateSteps - earlySteps) * t;
    return steps.round().clamp(2, 5);
  }

  bool _trackPlayerSteps() {
    final current = _playerController.position;
    final previous = _lastPlayerCell;
    final moved = previous != null && current != previous;
    if (moved) {
      _mazeShiftManager.onPlayerStep();
      if (_awaitingDevilRespawnSteps) {
        _stepsSinceSafeZone += 1;
      }
      _playerStepCount += 1;
    }
    _lastPlayerCell = current;
    return moved;
  }

  double _pathClearanceProgress() {
    if (_startToGoalDistance <= 0) {
      return 0.0;
    }
    final dist = _distanceFromStart[_playerController.position];
    if (dist == null) {
      return 0.0;
    }
    return (dist / _startToGoalDistance).clamp(0.0, 1.0);
  }

  int get _mazeShiftTotalSteps {
    final fallback = max(8, _maze.rows + _maze.cols);
    if (_startToGoalDistance <= 0) {
      return fallback;
    }
    return max(8, _startToGoalDistance);
  }

  void _maybeTriggerMazeShift() {
    final phase = _mazeShiftManager.pendingPhase;
    if (phase == MazeShiftPhase.none) {
      return;
    }

    _mazeShiftManager.markPhaseTriggered(phase);
    _glitchEffectController.trigger();

    final outcome = _mazeShiftManager.triggerMazeShift(
      phase: phase,
      maze: _maze,
      playerPosition: _playerController.position,
      exitPosition: _maze.end,
    );
    if (!outcome.applied) {
      return;
    }

    unawaited(_audioManager.handle(GameAudioEvent.mazeShiftStarted));

    // When glitch effects are disabled the controller deactivates immediately,
    // so the tick-loop's wasGlitchActive→!isActive transition never fires
    // mazeShiftEnded.  Emit it after a short delay so the stinger SFX plays
    // through and the AudioManager's priority resets reliably.
    if (!_glitchEffectController.isActive) {
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (mounted && !_roundResolved && !_isStageTransition) {
          unawaited(_audioManager.handle(GameAudioEvent.mazeShiftEnded));
        }
      });
    }

    _rebuildPathMetrics();
    _mazeShiftManager.updateTotalSteps(_mazeShiftTotalSteps);
    _devilMoveAccumulator = 0;
  }

  void _rebuildPathMetrics() {
    _distanceFromStart = _buildDistanceMap(_maze.start);
    _startToGoalDistance = _distanceFromStart[_maze.end] ?? 0;
  }

  Map<Point<int>, int> _buildDistanceMap(Point<int> source) {
    final distances = <Point<int>, int>{source: 0};
    final queue = <Point<int>>[source];
    var index = 0;

    while (index < queue.length) {
      final current = queue[index++];
      final base = distances[current] ?? 0;
      for (final dir in Direction4.values) {
        if (!_maze.canMove(current, dir)) {
          continue;
        }
        final next = _maze.move(current, dir);
        if (distances.containsKey(next)) {
          continue;
        }
        distances[next] = base + 1;
        queue.add(next);
      }
    }

    return distances;
  }

  Point<int> _spawnDevilCell() {
    final player = _playerController.position;
    final trail = _trailCells();
    final distance = _stageRule.devilSpawnDistanceCells
        .clamp(2, max(2, _maxPlayableMazeSize - 2))
        .toInt();

    // Primary rule: spawn from traveled path behind player (A -> B-3 style).
    if (trail.length > distance) {
      final target = trail[trail.length - 1 - distance];
      if (target != player) {
        return target;
      }
    }

    // Secondary: pick the nearest earlier path point that is still behind.
    for (var i = trail.length - 2; i >= 0; i--) {
      final candidate = trail[i];
      final gap =
          (candidate.x - player.x).abs() + (candidate.y - player.y).abs();
      if (gap >= 2) {
        return candidate;
      }
    }

    // Last fallback: opposite to facing direction (for very short trails).
    final facing = _facingVector(_playerController.direction);
    return Point<int>(
      (player.x - facing.x * 2).clamp(0, _maze.cols - 1).toInt(),
      (player.y - facing.y * 2).clamp(0, _maze.rows - 1).toInt(),
    );
  }

  List<Point<int>> _trailCells() {
    final points = _playerController.pathPoints;
    if (points.isEmpty) {
      return <Point<int>>[_playerController.position];
    }

    final trail = <Point<int>>[];
    Point<int>? last;
    for (final p in points) {
      final cell = Point<int>(p.dx.round(), p.dy.round());
      if (cell != last) {
        trail.add(cell);
        last = cell;
      }
    }

    if (trail.isEmpty || trail.last != _playerController.position) {
      trail.add(_playerController.position);
    }
    return trail;
  }

  Point<int> _facingVector(Direction4 direction) {
    switch (direction) {
      case Direction4.up:
        return const Point<int>(0, -1);
      case Direction4.right:
        return const Point<int>(1, 0);
      case Direction4.down:
        return const Point<int>(0, 1);
      case Direction4.left:
        return const Point<int>(-1, 0);
    }
  }

  Point<int> _nextDevilStep(Point<int> from, Point<int> player) {
    if (from == player) {
      return from;
    }

    final queue = <Point<int>>[from];
    final parent = <Point<int>, Point<int>?>{from: null};
    var index = 0;

    while (index < queue.length) {
      final current = queue[index++];
      if (current == player) {
        break;
      }

      for (final dir in Direction4.values) {
        if (!_maze.canMove(current, dir)) {
          continue;
        }
        final next = _maze.move(current, dir);
        if (parent.containsKey(next)) {
          continue;
        }
        parent[next] = current;
        queue.add(next);
      }
    }

    if (!parent.containsKey(player)) {
      return from;
    }

    Point<int> cursor = player;
    while (parent[cursor] != null && parent[cursor] != from) {
      cursor = parent[cursor]!;
    }
    return cursor;
  }

  void _resetSafeZones() {
    _safeZones
      ..clear()
      ..addAll(_buildSafeZones(count: _safeZonesPerStage, duration: 1.0));
  }

  Map<Point<int>, double> _buildSafeZones({
    required int count,
    required double duration,
  }) {
    if (count <= 0) {
      return const <Point<int>, double>{};
    }

    final path = _goalPathCells();
    if (path.length <= 2) {
      return const <Point<int>, double>{};
    }

    final interior = path
        .where((cell) => cell != _maze.start && cell != _maze.end)
        .toList(growable: false);
    if (interior.isEmpty) {
      return const <Point<int>, double>{};
    }

    final zonesToPlace = min(count, interior.length);
    final picked = <Point<int>, double>{};

    // Spread safe zones along the true start->goal path so they guide routing.
    for (var i = 1; i <= zonesToPlace; i++) {
      final ratio = i / (zonesToPlace + 1);
      final index = (ratio * (interior.length - 1)).round().clamp(
        0,
        interior.length - 1,
      );
      final cell = interior[index];
      picked[cell] = duration;
    }

    return picked;
  }

  List<Point<int>> _goalPathCells() {
    final start = _maze.start;
    final goal = _maze.end;
    final queue = <Point<int>>[start];
    final parent = <Point<int>, Point<int>?>{start: null};
    var index = 0;

    while (index < queue.length) {
      final current = queue[index++];
      if (current == goal) {
        break;
      }
      for (final dir in Direction4.values) {
        if (!_maze.canMove(current, dir)) {
          continue;
        }
        final next = _maze.move(current, dir);
        if (parent.containsKey(next)) {
          continue;
        }
        parent[next] = current;
        queue.add(next);
      }
    }

    if (!parent.containsKey(goal)) {
      return const <Point<int>>[];
    }

    final path = <Point<int>>[];
    Point<int>? cursor = goal;
    while (cursor != null) {
      path.add(cursor);
      cursor = parent[cursor];
    }
    return path.reversed.toList(growable: false);
  }

  void _updateSafeZones() {
    _playerSafe = false;
    final current = _playerController.position;
    if (!_safeZones.containsKey(current)) {
      return;
    }

    _playerSafe = true;

    // Up to stage 75, safe zones stay reusable; after that, each one is
    // consumed on first touch so players must route to a different zone.
    if (_stage > _persistentSafeZonesUntilStage) {
      _safeZones.remove(current);
    }
  }

  void _restartCountdown() {
    _roundResolved = false;
    _remainingSeconds = _stageDurationSeconds;
    unawaited(
      _audioManager.handle(
        GameAudioEvent.timeChanged,
        secondsLeft: _remainingSeconds,
      ),
    );
    _startCountdown();
  }

  Future<void> _onTimeExpired() async {
    if (!mounted ||
        _roundResolved ||
        _isTimeUpHandling ||
        _isStageTransition ||
        _showLossOverlay ||
        _trapDeathInProgress) {
      return;
    }

    if (_playerReachedGoal) {
      unawaited(_loadNextMaze());
      return;
    }

    _roundResolved = true;
    _isTimeUpHandling = true;
    _isPaused = false;
    _countdownTimer?.cancel();
    _playerController.stop();
    try {
      await _audioManager.handle(GameAudioEvent.playerLost);
    } catch (_) {
      // Keep timeout flow crash-safe if audio dispatch fails.
    }
    setState(() {
      _showLossOverlay = true;
      _lostByTime = true;
      _lostByTrap = false;
      _trapDeathQuote = null;
    });
    _isTimeUpHandling = false;
  }

  bool get _playerReachedGoal => _playerController.position == _maze.end;

  Future<void> _onExitPressed() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final escaped = _escapePercent();

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 20,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppPalette.accentPurple.withAlpha(170),
                  width: 1.3,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppPalette.accentPurple,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.exit_to_app_rounded,
                          color: Colors.black,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LEAVE THIS RUN?',
                              style: TextStyle(
                                color: AppPalette.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                letterSpacing: 0.9,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'You can continue now or return to dashboard.',
                              style: TextStyle(
                                color: AppPalette.textMuted,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'One more push could change this run.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppPalette.neonGreen,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: AppPalette.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppPalette.borderSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'CURRENT PROGRESS',
                              style: TextStyle(
                                color: AppPalette.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                letterSpacing: 0.55,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$escaped%',
                              style: const TextStyle(
                                color: AppPalette.accentPink,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: (escaped / 100).clamp(0.0, 1.0),
                            minHeight: 9,
                            backgroundColor: const Color(0xFF252525),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppPalette.accentPink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Stage $_stage / $_maxStage  •  ${_checkpointPushText()}',
                          style: const TextStyle(
                            color: AppPalette.textMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: BorderSide(
                              color: AppPalette.neonGreen.withAlpha(170),
                            ),
                            foregroundColor: AppPalette.neonGreen,
                          ),
                          child: const Text(
                            'KEEP PLAYING',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: AppPalette.danger,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text(
                            'EXIT RUN',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (shouldExit == true) {
      _resetToCheckpointOnReactivation = true;
      await _audioManager.handle(GameAudioEvent.matchExit);
      widget.onExitToDashboard();
    }
  }

  void _togglePause() {
    final canToggle =
        !_isStageTransition &&
        !_isTimeUpHandling &&
        !_showLossOverlay &&
        !_trapDeathInProgress &&
        !_isExternallyInactive &&
        !_adActionInProgress;
    if (!canToggle) {
      return;
    }

    setState(() {
      _isPaused = !_isPaused;
    });

    if (_isPaused) {
      _playerController.stop();
      unawaited(_audioManager.handle(GameAudioEvent.matchPause));
    } else {
      unawaited(_audioManager.handle(GameAudioEvent.matchResume));
      unawaited(
        _audioManager.handle(
          GameAudioEvent.timeChanged,
          secondsLeft: _remainingSeconds,
        ),
      );
    }
  }

  Future<void> _loadCharactersSprite() async {
    try {
      final data = await rootBundle.load('assets/images/characters.png');
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();
      if (!mounted) {
        return;
      }
      setState(() {
        _playerSprite = frameInfo.image;
      });
    } catch (_) {
      // Fallback to circle rendering if sprite is not available.
    }
  }

  Future<void> _loadBreakingTrapTexture() async {
    try {
      final data = await rootBundle.load('assets/images/464.jpg');
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 128,
        targetHeight: 128,
      );
      final frameInfo = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        return;
      }
      setState(() {
        _breakingTrapTexture = frameInfo.image;
      });
    } catch (_) {
      // Keep trap rendering crash-safe by falling back to vector cracks.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _stageTimer?.cancel();
    _stageClearController.dispose();
    _trapDeathSequence.dispose();
    _playerController.dispose();
    unawaited(_audioManager.handle(GameAudioEvent.matchExit));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final shortestSide = min(screenSize.width, screenSize.height);
    final uiScale = (shortestSide / 390).clamp(0.84, 1.2);
    final horizontalPadding = (14 * uiScale).clamp(10.0, 20.0);
    final verticalPadding = (10 * uiScale).clamp(8.0, 16.0);
    final controlsLift = (-44 * uiScale).clamp(-56.0, -30.0);
    final controlsBottomPadding = (6 * uiScale).clamp(4.0, 12.0);
    final mazeFramePadding = (6 * uiScale).clamp(4.0, 10.0);
    final floatingLabelSize = (10 * uiScale).clamp(8.0, 12.0);
    final floatingValueSize = (20 * uiScale).clamp(15.0, 24.0);
    final floatingSubValueSize = (14 * uiScale).clamp(11.0, 18.0);
    final floatingTop = (4 * uiScale).clamp(2.0, 8.0);
    final floatingDrift = sin(_stageElapsedSeconds * pi * 2) * (1.8 * uiScale);
    final timeDigits = _timeLabel.replaceFirst('TIME: ', '');


    return Material(
      color: AppPalette.backgroundDark,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  SizedBox(height: (16 * uiScale).clamp(10.0, 22.0)),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          padding: EdgeInsets.all(mazeFramePadding),
                          decoration: BoxDecoration(
                            color: AppPalette.surface,
                            borderRadius: BorderRadius.circular(
                              (18 * uiScale).clamp(14.0, 22.0),
                            ),
                            border: Border.all(
                              color: AppPalette.accentPurple.withAlpha(160),
                              width: 1.3,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              (12 * uiScale).clamp(10.0, 16.0),
                            ),
                            child: GlitchEffectOverlay(
                              controller: _glitchEffectController,
                              child: _buildGameSurface(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: (10 * uiScale).clamp(8.0, 14.0)),
                  Transform.translate(
                    offset: Offset(0, controlsLift),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: controlsBottomPadding),
                      child: Center(
                        child: widget.useArrowController
                            ? _ArrowPad(
                                size: widget.joystickSize,
                                onDirection:
                                    (_isStageTransition ||
                                        _isExternallyInactive ||
                                        _isPaused ||
                                        _trapDeathInProgress)
                                    ? (_) {}
                                    : (direction) {
                                        final effective = _controlsInverted
                                            ? _invertDirection(direction)
                                            : direction;
                                        _playerController.holdDirection(
                                          effective,
                                        );
                                      },
                                onEnd:
                                    (_isStageTransition ||
                                        _isExternallyInactive ||
                                        _isPaused ||
                                        _trapDeathInProgress)
                                    ? () {}
                                    : _playerController.stop,
                              )
                            : _Joystick(
                                size: widget.joystickSize,
                                onDirection:
                                    (_isStageTransition ||
                                        _isExternallyInactive ||
                                        _isPaused ||
                                        _trapDeathInProgress)
                                    ? (_) {}
                                    : (direction) {
                                        final effective = _controlsInverted
                                            ? _invertDirection(direction)
                                            : direction;
                                        _playerController.holdDirection(
                                          effective,
                                        );
                                      },
                                onEnd:
                                    (_isStageTransition ||
                                        _isExternallyInactive ||
                                        _isPaused ||
                                        _trapDeathInProgress)
                                    ? () {}
                                    : _playerController.stop,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: (2 * uiScale).clamp(1.0, 8.0),
                top: floatingTop + floatingDrift,
                child: IgnorePointer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FloatingHudMetric(
                        label: 'STAGE',
                        value: _stage.toString(),
                        labelColor: const Color(0xFF79EFFF),
                        valueColor: AppPalette.accentPink,
                        labelSize: floatingLabelSize,
                        valueSize: floatingValueSize,
                        icon: Icons.auto_awesome_rounded,
                      ),
                      SizedBox(height: (6 * uiScale).clamp(4.0, 10.0)),
                      _FloatingHudMetric(
                        label: 'CHECKPOINT',
                        value: _checkpoint.toString(),
                        labelColor: const Color(0xFFC5B0FF),
                        valueColor: AppPalette.accentPurple,
                        labelSize: floatingLabelSize,
                        valueSize: floatingSubValueSize,
                        icon: Icons.flag_rounded,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: (2 * uiScale).clamp(1.0, 8.0),
                top: floatingTop - floatingDrift,
                child: _FloatingTimeControl(
                  isPanic: _isPanic,
                  isPaused: _isPaused,
                  timeDigits: timeDigits,
                  labelSize: floatingLabelSize,
                  valueSize: floatingValueSize,
                  onPauseTap: _togglePause,
                ),
              ),
              if (AppRuntimeConfig.debugStageDropdownEnabled)
                Positioned(
                  top: floatingTop + (2 * uiScale).clamp(1.0, 8.0),
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _DebugStageDropdown(
                      currentStage: _stage,
                      maxStage: _maxStage,
                      onStageSelected: _jumpToStageForDebug,
                    ),
                  ),
                ),
              if (_isPaused)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: false,
                    child: Container(
                      color: const Color(0xC0000000),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: max(0.0, constraints.maxHeight - 36),
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 460,
                                  ),
                                  child: _RunPausedDialog(
                                    stage: _stage,
                                    checkpoint: _checkpoint,
                                    nextCheckpoint: _nextMilestoneStage(),
                                    checkpointText: _checkpointPushText(),
                                    modeLabel: _modeLabel,
                                    timeRemainingLabel: _timeLabel.replaceFirst(
                                      'TIME: ',
                                      '',
                                    ),
                                    onResumePressed: _togglePause,
                                    onExitPressed: _onExitPressed,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              if (_isStageTransition)
                _StageClearOverlay(
                  stage: _completedStage,
                  controller: _stageClearController,
                ),
              if (_showLossOverlay)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: false,
                    child: Container(
                      color: const Color(0xD9000000),
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: _RunFailedDialog(
                                stage: _stage,
                                maxStage: _maxStage,
                                escapePercent: _escapePercent(),
                                checkpointText: _checkpointPushText(),
                                modeLabel: _modeLabel,
                                timeRemainingLabel: _timeLabel.replaceFirst(
                                  'TIME: ',
                                  '',
                                ),
                                lossReason: _lossReasonText(),
                                comebackHook: _comebackHookText(),
                                lostByTime: _lostByTime,
                                lostByTrap: _lostByTrap,
                                trapDeathQuote: _trapDeathQuote,
                                adActionInProgress: _adActionInProgress,
                                onRevivePressed: _onReviveFromLoss,
                                onRestartPressed: _onRestartFromLoss,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  int _escapePercent() {
    return ((_stage.clamp(1, _maxStage) / _maxStage) * 100).round();
  }

  int _nextMilestoneStage() {
    if (_stage < 25) {
      return 25;
    }
    if (_stage < 50) {
      return 50;
    }
    if (_stage < 75) {
      return 75;
    }
    return _maxStage;
  }

  String _lossReasonText() {
    if (_lostByTrap) {
      return 'The floor collapsed beneath your return step.';
    }
    return _lostByTime
        ? 'Clock hit zero before extraction.'
        : 'Devil intercepted your route.';
  }

  String _comebackHookText() {
    if (_lostByTrap) {
      return 'Remember where you cracked the floor. Reroute and punish the maze.';
    }
    final percent = _escapePercent();
    if (percent >= 90) {
      return 'You are inches away from the finish. Lock in and close it.';
    }
    if (percent >= 70) {
      return 'Strong run. One cleaner path and this stage is yours.';
    }
    if (percent >= 40) {
      return 'You already broke through the hard part. Push again.';
    }
    return 'Warm-up complete. Build momentum and surge forward.';
  }

  String _checkpointPushText() {
    final milestone = _nextMilestoneStage();
    if (_stage >= milestone) {
      return 'Checkpoint secured';
    }
    final remaining = milestone - _stage;
    final suffix = remaining == 1 ? '' : 's';
    return '$remaining stage$suffix to checkpoint $milestone';
  }

  Future<void> _onRestartFromLoss() async {
    if (_adActionInProgress) {
      return;
    }
    setState(() {
      _adActionInProgress = true;
    });
    final shown = await widget.onRestartWithAd();
    if (!mounted) {
      return;
    }
    if (shown) {
      _resetToCheckpoint();
    }
    setState(() {
      _adActionInProgress = false;
    });
  }

  Future<void> _onReviveFromLoss() async {
    if (_adActionInProgress) {
      return;
    }
    setState(() {
      _adActionInProgress = true;
    });
    final shown = await widget.onReviveWithAd();
    if (!mounted) {
      return;
    }
    if (shown) {
      _restartCurrentStageFromStart();
      return;
    }
    setState(() {
      _adActionInProgress = false;
    });
  }

  void _recordTrapRecoveryIntent(String eventType) {
    if (!_lostByTrap) {
      return;
    }
    final playerCell = _playerController.position;
    final tile = _trapStateController.trapAt(playerCell);
    _trapAnalytics.record(
      stage: _stage,
      eventType: eventType,
      cell: tile?.cell ?? playerCell,
      topology: tile?.topology,
      playerStepCount: _playerStepCount,
      secondsElapsed: _stageElapsedSeconds,
      devilActive: _devilSpawned && _devilCell != null,
      controlsInverted: _controlsInverted,
      trapsTriggeredThisRun: _trapStateController.triggeredCount,
      secondsRemaining: _remainingSeconds,
      stepsSinceReveal: tile?.stepsSinceReveal(_playerStepCount),
      placementScore: tile?.placementScore,
      revisitScore: tile?.revisitScore,
      pressureTags: tile?.pressureTags,
      distanceToGoal: _maze.shortestPathDistance(playerCell, _maze.end),
    );
  }

  void _restartCurrentStageFromStart() {
    _recordTrapRecoveryIntent('restart_after_trap_death');
    _showLossOverlay = false;
    _lostByTime = false;
    _lostByTrap = false;
    _trapDeathQuote = null;
    _trapDeathInProgress = false;
    _adActionInProgress = false;
    _trapDeathSequence.cancel();

    _playerController.resetForMaze(_maze);
    _applyStageRule(resetMaze: false);
    // Fire matchExit first to force-kill the game-lost one-shot and any other
    // lingering audio before the new round begins.
    unawaited(_audioManager.handle(GameAudioEvent.matchExit));
    unawaited(_audioManager.handle(GameAudioEvent.matchRestart));
    _restartCountdown();
    setState(() {});
  }

  void _resetToCheckpoint() {
    _recordTrapRecoveryIntent('checkpoint_reset_after_trap_death');
    final checkpointStage = _checkpoint == 0 ? 1 : _checkpoint;
    final targetStage = checkpointStage.clamp(1, _maxStage);

    _stage = targetStage;
    _stageRule = StageRules.forStage(_stage);
    _difficulty = _difficultyForStage(_stage);
    _maze = _generator.generate(rows: _difficulty, cols: _difficulty);
    _rebuildPathMetrics();
    _remainingSeconds = _stageDurationSeconds;
    _isStageTransition = false;
    _showLossOverlay = false;
    _lostByTime = false;
    _lostByTrap = false;
    _trapDeathQuote = null;
    _trapDeathInProgress = false;
    _trapDeathSequence.cancel();

    _playerController.resetForMaze(_maze);
    _applyStageRule(resetMaze: false);
    // Fire matchExit first to force-kill the game-lost one-shot and any other
    // lingering audio before the checkpoint restart begins.
    unawaited(_audioManager.handle(GameAudioEvent.matchExit));
    unawaited(_audioManager.handle(GameAudioEvent.matchRestart));
    _restartCountdown();
    setState(() {});
  }

  void _jumpToStageForDebug(int targetStage) {
    final stage = targetStage.clamp(1, _maxStage);
    if (_stage == stage && !_showLossOverlay && !_isStageTransition) {
      return;
    }

    _countdownTimer?.cancel();
    _stageClearController.stop();
    _stageClearController.reset();

    _stage = stage;
    _stageRule = StageRules.forStage(_stage);
    _difficulty = _difficultyForStage(_stage);
    _maze = _generator.generate(rows: _difficulty, cols: _difficulty);
    _rebuildPathMetrics();
    _remainingSeconds = _stageDurationSeconds;
    _isStageTransition = false;
    _isTimeUpHandling = false;
    _showLossOverlay = false;
    _lostByTime = false;
    _lostByTrap = false;
    _trapDeathQuote = null;
    _trapDeathInProgress = false;
    _trapDeathSequence.cancel();
    _adActionInProgress = false;

    _playerController.resetForMaze(_maze);
    _applyStageRule(resetMaze: false);

    // Force-clear lingering one-shots and start the chosen stage cleanly.
    unawaited(_audioManager.handle(GameAudioEvent.matchExit));
    unawaited(_audioManager.handle(GameAudioEvent.matchRestart));
    _restartCountdown();

    if (_isExternallyInactive) {
      unawaited(_audioManager.handle(GameAudioEvent.matchPause));
    }

    if (mounted) {
      setState(() {});
    }
  }

  Direction4? _invertDirection(Direction4? direction) {
    switch (direction) {
      case Direction4.up:
        return Direction4.down;
      case Direction4.right:
        return Direction4.left;
      case Direction4.down:
        return Direction4.up;
      case Direction4.left:
        return Direction4.right;
      case null:
        return null;
    }
  }

  Widget _buildGameSurface() {
    return RepaintBoundary(
      key: GameScreen.gameSurfaceKey,
      child: AnimatedBuilder(
        animation: _playerController,
        builder: (context, _) {
          final pulse = (_stageElapsedSeconds * 1.25) % 1.0;
          final trapTiles = List<TrapTile>.unmodifiable(
            _trapStateController.activeTiles,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                key: _gameSurfaceSizeKey,
                painter: MazePainter(
                  maze: _maze,
                  pathPoints: _playerController.pathPoints,
                  playerCellPosition: _playerController.renderPosition,
                  direction: _playerController.direction,
                  currentFrame: _playerController.currentFrame,
                  isMoving: _playerController.isMoving,
                  pulse: pulse,
                  playerSprite: _playerSprite,
                  spriteFrameCount: _spriteColumns,
                  spriteRows: _spriteRows,
                  spriteRowIndex: widget.selectedCharacterIndex + 1,
                  devilCell: _devilCell,
                  devilSprite: _playerSprite,
                  devilSpriteRowIndex: 0,
                  safeZones: _safeZones,
                  playerSafe: _playerSafe,
                  isFlippedMode: _controlsInverted,
                  trapTiles: trapTiles,
                  trapHiddenCueLevel: _trapStageConfig.hiddenCueLevel,
                  breakingTrapTexture: _breakingTrapTexture,
                  hidePlayer: _trapDeathInProgress,
                ),
              ),
              if (_trapDeathInProgress)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _trapDeathSequence.painter),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TrapSurfaceMetrics {
  const _TrapSurfaceMetrics({required this.origin, required this.cellSize});

  final Offset origin;
  final double cellSize;
}

class _DebugStageDropdown extends StatelessWidget {
  const _DebugStageDropdown({
    required this.currentStage,
    required this.maxStage,
    required this.onStageSelected,
  });

  final int currentStage;
  final int maxStage;
  final ValueChanged<int> onStageSelected;

  @override
  Widget build(BuildContext context) {
    final safeStage = currentStage.clamp(1, maxStage).toInt();

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 8, 4),
      decoration: BoxDecoration(
        color: AppPalette.surface.withAlpha(224),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.accentPurple.withAlpha(170)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bug_report_rounded,
            color: AppPalette.accentPurple.withAlpha(220),
            size: 16,
          ),
          const SizedBox(width: 6),
          const Text(
            'TEST STAGE',
            style: TextStyle(
              color: AppPalette.textMuted,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.45,
            ),
          ),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: safeStage,
              isDense: true,
              menuMaxHeight: 320,
              dropdownColor: AppPalette.surfaceAlt,
              iconEnabledColor: AppPalette.neonGreen,
              style: const TextStyle(
                color: AppPalette.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
              items: List<DropdownMenuItem<int>>.generate(maxStage, (index) {
                final stage = index + 1;
                return DropdownMenuItem<int>(
                  value: stage,
                  child: Text('Stage $stage'),
                );
              }, growable: false),
              onChanged: (value) {
                if (value != null) {
                  onStageSelected(value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingHudMetric extends StatelessWidget {
  const _FloatingHudMetric({
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
    required this.labelSize,
    required this.valueSize,
    required this.icon,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;
  final double labelSize;
  final double valueSize;
  final IconData icon;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final textAlign = alignEnd ? TextAlign.right : TextAlign.left;
    final crossAxis = alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: crossAxis,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: labelColor.withAlpha(230), size: labelSize + 3),
            const SizedBox(width: 5),
            Text(
              label,
              textAlign: textAlign,
              style: TextStyle(
                color: labelColor,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.9,
                fontSize: labelSize,
                height: 1,
                shadows: [
                  Shadow(
                    color: labelColor.withAlpha(130),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
        Text(
          value,
          textAlign: textAlign,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
            fontSize: valueSize,
            height: 1,
            shadows: [
              Shadow(
                color: valueColor.withAlpha(160),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
              const Shadow(
                color: Color(0x99000000),
                blurRadius: 9,
                offset: Offset(0, 3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FloatingTimeControl extends StatelessWidget {
  const _FloatingTimeControl({
    required this.isPanic,
    required this.isPaused,
    required this.timeDigits,
    required this.labelSize,
    required this.valueSize,
    required this.onPauseTap,
  });

  final bool isPanic;
  final bool isPaused;
  final String timeDigits;
  final double labelSize;
  final double valueSize;
  final VoidCallback onPauseTap;

  @override
  Widget build(BuildContext context) {
    final labelColor = isPanic
        ? const Color(0xFFFFA39A)
        : const Color(0xFFB7FFA8);
    final valueColor = isPanic ? AppPalette.danger : AppPalette.neonGreen;
    final buttonColor = isPaused
        ? AppPalette.neonGreen.withAlpha(220)
        : AppPalette.accentPurple.withAlpha(220);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IgnorePointer(
          child: _FloatingHudMetric(
            label: 'TIME',
            value: timeDigits,
            labelColor: labelColor,
            valueColor: valueColor,
            labelSize: labelSize,
            valueSize: valueSize,
            icon: isPanic ? Icons.favorite_rounded : Icons.schedule_rounded,
            alignEnd: true,
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: isPaused ? 'Resume run' : 'Pause run',
          child: Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: buttonColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(140)),
              boxShadow: [
                BoxShadow(
                  color: buttonColor.withAlpha(90),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              padding: EdgeInsets.zero,
              splashRadius: 18,
              onPressed: onPauseTap,
              icon: Icon(
                isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                size: 20,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RunPausedDialog extends StatelessWidget {
  const _RunPausedDialog({
    required this.stage,
    required this.checkpoint,
    required this.nextCheckpoint,
    required this.checkpointText,
    required this.modeLabel,
    required this.timeRemainingLabel,
    required this.onResumePressed,
    required this.onExitPressed,
  });

  final int stage;
  final int checkpoint;
  final int nextCheckpoint;
  final String checkpointText;
  final String modeLabel;
  final String timeRemainingLabel;
  final VoidCallback onResumePressed;
  final Future<void> Function() onExitPressed;

  @override
  Widget build(BuildContext context) {
    final checkpointProgress = nextCheckpoint <= 0
        ? 1.0
        : (stage / nextCheckpoint).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF121522), Color(0xFF090B14)],
        ),
        border: Border.all(
          color: AppPalette.accentPurple.withAlpha(190),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.accentPurple.withAlpha(70),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
          const BoxShadow(
            color: Color(0x52000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _RunPausedDialogGridPainter()),
            ),
            Positioned(
              top: -28,
              right: -22,
              child: Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x55E26AE6), Color(0x00E26AE6)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -34,
              bottom: -42,
              child: Container(
                width: 170,
                height: 170,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x3333FF2B), Color(0x0033FF2B)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppPalette.accentPurple,
                              AppPalette.accentPink,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppPalette.accentPurple.withAlpha(90),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.pause_circle_filled_rounded,
                          color: Colors.black,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RUN PAUSED',
                              style: TextStyle(
                                color: AppPalette.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 21,
                                letterSpacing: 1,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Take a breath. Your progress is safe.',
                              style: TextStyle(
                                color: AppPalette.textMuted,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _RunPausedInfoChip(
                        label: 'STAGE',
                        value: '$stage',
                        color: AppPalette.accentPurple,
                      ),
                      _RunPausedInfoChip(
                        label: 'TIME LEFT',
                        value: timeRemainingLabel,
                        color: AppPalette.neonGreen,
                      ),
                      _RunPausedInfoChip(
                        label: 'MODE',
                        value: modeLabel,
                        color: const Color(0xFF87ECFF),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Ready for the next move?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppPalette.neonGreen,
                      fontWeight: FontWeight.w900,
                      fontSize: 31,
                      letterSpacing: 0.2,
                      height: 0.95,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    checkpointText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppPalette.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      height: 1.28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _RunPausedCheckpointCard(
                    checkpoint: checkpoint,
                    progress: checkpointProgress,
                    stage: stage,
                    nextCheckpoint: nextCheckpoint,
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onResumePressed,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text(
                      'RESUME RUN',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: AppPalette.neonGreen,
                      foregroundColor: Colors.black,
                      elevation: 8,
                      shadowColor: const Color(0x8833FF2B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _RunPausedExitButton(
                    onPressed: () {
                      unawaited(onExitPressed());
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunPausedInfoChip extends StatelessWidget {
  const _RunPausedInfoChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x33161B28),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withAlpha(150)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 10.8,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.55,
          ),
          children: [
            TextSpan(
              text: '$label  ',
              style: TextStyle(color: color),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: AppPalette.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunPausedCheckpointCard extends StatelessWidget {
  const _RunPausedCheckpointCard({
    required this.checkpoint,
    required this.progress,
    required this.stage,
    required this.nextCheckpoint,
  });

  final int checkpoint;
  final double progress;
  final int stage;
  final int nextCheckpoint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xA8191C28),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppPalette.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'CHECKPOINT STATUS',
                style: TextStyle(
                  color: AppPalette.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.65,
                ),
              ),
              const Spacer(),
              Text(
                '$checkpoint',
                style: const TextStyle(
                  color: AppPalette.accentPink,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _RunPausedProgressBar(value: progress),
          const SizedBox(height: 8),
          Text(
            'Stage $stage  •  Next checkpoint $nextCheckpoint',
            style: const TextStyle(
              color: AppPalette.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _RunPausedProgressBar extends StatelessWidget {
  const _RunPausedProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 10,
        color: const Color(0xFF252836),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [AppPalette.accentPink, AppPalette.accentPurple],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppPalette.accentPurple.withAlpha(120),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RunPausedExitButton extends StatelessWidget {
  const _RunPausedExitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0x33FF8A80), Color(0x111A1A24)],
        ),
        border: Border.all(color: AppPalette.danger.withAlpha(170)),
        boxShadow: [
          BoxShadow(
            color: AppPalette.danger.withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.exit_to_app_rounded),
        label: const Text(
          'EXIT THIS RUN',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          side: BorderSide.none,
          foregroundColor: AppPalette.danger,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }
}

class _RunPausedDialogGridPainter extends CustomPainter {
  const _RunPausedDialogGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppPalette.accentPurple.withAlpha(28)
      ..strokeWidth = 1;

    const spacing = 28.0;
    for (var x = 0.0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final scanPaint = Paint()
      ..shader =
          const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0x44E26AE6), Colors.transparent],
          ).createShader(
            Rect.fromLTWH(0, size.height * 0.25, size.width, size.height * 0.2),
          );

    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.25, size.width, size.height * 0.18),
      scanPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RunFailedDialog extends StatelessWidget {
  const _RunFailedDialog({
    required this.stage,
    required this.maxStage,
    required this.escapePercent,
    required this.checkpointText,
    required this.modeLabel,
    required this.timeRemainingLabel,
    required this.lossReason,
    required this.comebackHook,
    required this.lostByTime,
    required this.lostByTrap,
    required this.trapDeathQuote,
    required this.adActionInProgress,
    required this.onRevivePressed,
    required this.onRestartPressed,
  });

  final int stage;
  final int maxStage;
  final int escapePercent;
  final String checkpointText;
  final String modeLabel;
  final String timeRemainingLabel;
  final String lossReason;
  final String comebackHook;
  final bool lostByTime;
  final bool lostByTrap;
  final String? trapDeathQuote;
  final bool adActionInProgress;
  final Future<void> Function() onRevivePressed;
  final Future<void> Function() onRestartPressed;

  @override
  Widget build(BuildContext context) {
    final accent = lostByTrap
        ? const Color(0xFFFF6A5F)
        : (lostByTime ? AppPalette.danger : const Color(0xFFFF938B));
    final threatTag = lostByTrap
        ? 'TRAP FALL'
        : (lostByTime ? 'TIME OUT' : 'DEVIL THREAT');
    final progress = (escapePercent / 100).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF141623), Color(0xFF0B0C14)],
        ),
        border: Border.all(color: accent.withAlpha(190), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withAlpha(70),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
          const BoxShadow(
            color: Color(0x52000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RunFailedDialogGridPainter(accent: accent),
              ),
            ),
            Positioned(
              top: -28,
              right: -24,
              child: Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x55E85BDA), Color(0x00E85BDA)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -36,
              bottom: -42,
              child: Container(
                width: 180,
                height: 180,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x3833FF2B), Color(0x0033FF2B)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [accent, accent.withAlpha(210)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withAlpha(90),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.replay_circle_filled_rounded,
                          color: Colors.black,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'RUN FAILED',
                              style: TextStyle(
                                color: AppPalette.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 21,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              lossReason,
                              style: const TextStyle(
                                color: AppPalette.textMuted,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x26FFFFFF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: accent.withAlpha(180)),
                        ),
                        child: Text(
                          threatTag,
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _RunFailedInfoChip(
                        label: 'STAGE',
                        value: '$stage / $maxStage',
                        color: AppPalette.accentPurple,
                      ),
                      _RunFailedInfoChip(
                        label: 'TIME LEFT',
                        value: timeRemainingLabel,
                        color: AppPalette.neonGreen,
                      ),
                      _RunFailedInfoChip(
                        label: 'MODE',
                        value: modeLabel,
                        color: const Color(0xFF87ECFF),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Let\'s play one more.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppPalette.neonGreen,
                      fontWeight: FontWeight.w900,
                      fontSize: 31,
                      letterSpacing: 0.2,
                      height: 0.95,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    comebackHook,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppPalette.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      height: 1.28,
                    ),
                  ),
                  if (trapDeathQuote != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x26111111),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accent.withAlpha(150)),
                      ),
                      child: Text(
                        '"$trapDeathQuote"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppPalette.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xA8191C28),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: AppPalette.borderSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'COMPLETION LINE',
                              style: TextStyle(
                                color: AppPalette.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                letterSpacing: 0.65,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$escapePercent%',
                              style: const TextStyle(
                                color: AppPalette.accentPink,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _RunFailedProgressBar(
                          value: progress,
                          color: AppPalette.accentPink,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Stage $stage / $maxStage  •  $checkpointText',
                          style: const TextStyle(
                            color: AppPalette.textMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _RunFailedActionButton(
                    icon: Icons.flash_on_rounded,
                    label: adActionInProgress
                        ? 'LOADING AD...'
                        : 'REVIVE NOW (WATCH AD)',
                    background: AppPalette.neonGreen,
                    foreground: Colors.black,
                    glow: const Color(0x8833FF2B),
                    enabled: !adActionInProgress,
                    onPressed: () {
                      unawaited(onRevivePressed());
                    },
                  ),
                  const SizedBox(height: 10),
                  _RunFailedActionButton(
                    icon: Icons.restart_alt_rounded,
                    label: adActionInProgress
                        ? 'RESTARTING...'
                        : 'INSTANT CHECKPOINT RETRY',
                    background: AppPalette.accentPink,
                    foreground: Colors.black,
                    glow: const Color(0x88E85BDA),
                    enabled: !adActionInProgress,
                    onPressed: () {
                      unawaited(onRestartPressed());
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunFailedInfoChip extends StatelessWidget {
  const _RunFailedInfoChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x33161B28),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withAlpha(150)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 10.8,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.55,
          ),
          children: [
            TextSpan(
              text: '$label  ',
              style: TextStyle(color: color),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: AppPalette.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunFailedProgressBar extends StatelessWidget {
  const _RunFailedProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 10,
        color: const Color(0xFF252836),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [color.withAlpha(220), AppPalette.accentPurple],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withAlpha(120),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RunFailedActionButton extends StatelessWidget {
  const _RunFailedActionButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.glow,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final Color glow;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.9),
      ),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: background,
        disabledBackgroundColor: background.withAlpha(120),
        foregroundColor: foreground,
        elevation: enabled ? 7 : 0,
        shadowColor: glow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}

class _RunFailedDialogGridPainter extends CustomPainter {
  const _RunFailedDialogGridPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = accent.withAlpha(28)
      ..strokeWidth = 1;

    const spacing = 26.0;
    for (var x = 0.0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final scanPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [accent.withAlpha(50), Colors.transparent],
          ).createShader(
            Rect.fromLTWH(0, size.height * 0.2, size.width, size.height * 0.2),
          );

    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.2, size.width, size.height * 0.18),
      scanPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RunFailedDialogGridPainter oldDelegate) {
    return oldDelegate.accent != accent;
  }
}

class _Joystick extends StatefulWidget {
  const _Joystick({
    required this.size,
    required this.onDirection,
    required this.onEnd,
  });

  final double size;
  final ValueChanged<Direction4?> onDirection;
  final VoidCallback onEnd;

  @override
  State<_Joystick> createState() => _JoystickState();
}

class _ArrowPad extends StatelessWidget {
  const _ArrowPad({
    required this.size,
    required this.onDirection,
    required this.onEnd,
  });

  final double size;
  final ValueChanged<Direction4?> onDirection;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final padSize = (size * 1.08).clamp(104.0, 188.0);
    final buttonSize = padSize * 0.34;

    return SizedBox(
      width: padSize,
      height: padSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _ArrowButton(
            alignment: Alignment.topCenter,
            icon: Icons.keyboard_arrow_up,
            size: buttonSize,
            onDown: () => onDirection(Direction4.up),
            onUp: onEnd,
          ),
          _ArrowButton(
            alignment: Alignment.bottomCenter,
            icon: Icons.keyboard_arrow_down,
            size: buttonSize,
            onDown: () => onDirection(Direction4.down),
            onUp: onEnd,
          ),
          _ArrowButton(
            alignment: Alignment.centerLeft,
            icon: Icons.keyboard_arrow_left,
            size: buttonSize,
            onDown: () => onDirection(Direction4.left),
            onUp: onEnd,
          ),
          _ArrowButton(
            alignment: Alignment.centerRight,
            icon: Icons.keyboard_arrow_right,
            size: buttonSize,
            onDown: () => onDirection(Direction4.right),
            onUp: onEnd,
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.alignment,
    required this.icon,
    required this.size,
    required this.onDown,
    required this.onUp,
  });

  final Alignment alignment;
  final IconData icon;
  final double size;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTapDown: (_) => onDown(),
        onTapUp: (_) => onUp(),
        onTapCancel: onUp,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppPalette.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppPalette.accentPurple.withAlpha(170),
              width: 1.3,
            ),
          ),
          child: Icon(icon, color: AppPalette.neonGreen, size: size * 0.68),
        ),
      ),
    );
  }
}

class _JoystickState extends State<_Joystick> {
  static const double _deadZone = 10;

  Offset _knobOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onPanDown: (details) => _handleDrag(details.localPosition),
        onPanUpdate: (details) => _handleDrag(details.localPosition),
        onPanEnd: (_) => _resetKnob(),
        onPanCancel: _resetKnob,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppPalette.surfaceAlt,
            border: Border.all(
              color: AppPalette.accentPurple.withAlpha(170),
              width: 2.6,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppPalette.neonGreen.withAlpha(90),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Transform.translate(
                  offset: _knobOffset,
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppPalette.neonGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1.2),
                      ),
                      child: const Icon(
                        Icons.control_camera,
                        size: 18,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleDrag(Offset local) {
    final radius = widget.size / 2;
    final maxKnobOffset = widget.size * 0.28;
    final dx = local.dx - radius;
    final dy = local.dy - radius;
    final vector = Offset(dx, dy);
    final distance = vector.distance;

    Offset limited = vector;
    if (distance > maxKnobOffset && distance > 0) {
      limited = vector / distance * maxKnobOffset;
    }

    setState(() {
      _knobOffset = limited;
    });

    widget.onDirection(_directionFromVector(vector));
  }

  void _resetKnob() {
    if (_knobOffset != Offset.zero) {
      setState(() {
        _knobOffset = Offset.zero;
      });
    }
    widget.onEnd();
  }

  Direction4? _directionFromVector(Offset vector) {
    final dx = vector.dx;
    final dy = vector.dy;
    if (dx.abs() < _deadZone && dy.abs() < _deadZone) {
      return null;
    }
    if (dx.abs() > dy.abs()) {
      return dx >= 0 ? Direction4.right : Direction4.left;
    }
    return dy >= 0 ? Direction4.down : Direction4.up;
  }
}

// ── Stage Clear Overlay ──────────────────────────────────────────────────────

class _StageClearOverlay extends StatelessWidget {
  const _StageClearOverlay({required this.stage, required this.controller});
  final int stage;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final bgFade    = CurvedAnimation(parent: controller,
        curve: const Interval(0.00, 0.25, curve: Curves.easeIn));
    final burstAnim = CurvedAnimation(parent: controller,
        curve: const Interval(0.00, 0.55, curve: Curves.easeOutCubic));
    final slideIn   = CurvedAnimation(parent: controller,
        curve: const Interval(0.15, 0.55, curve: Curves.easeOutBack));
    final textFade  = CurvedAnimation(parent: controller,
        curve: const Interval(0.20, 0.55, curve: Curves.easeOut));
    final subFade   = CurvedAnimation(parent: controller,
        curve: const Interval(0.45, 0.72, curve: Curves.easeOut));
    final starsFade = CurvedAnimation(parent: controller,
        curve: const Interval(0.50, 0.82, curve: Curves.easeOut));

    return IgnorePointer(
      child: Positioned.fill(
        child: AnimatedBuilder(
          animation: controller,
          builder: (ctx, _) {
            final t = controller.value;
            return Stack(fit: StackFit.expand, children: [
              Opacity(
                opacity: (bgFade.value * 0.80).clamp(0.0, 1.0),
                child: const ColoredBox(color: Colors.black),
              ),
              Center(
                child: Opacity(
                  opacity: burstAnim.value,
                  child: CustomPaint(
                    size: const Size(340, 340),
                    painter: _BurstPainter(burstAnim.value),
                  ),
                ),
              ),
              Opacity(
                opacity: (t < 0.6 ? t / 0.6 : 1 - (t - 0.6) / 0.4).clamp(0, 1),
                child: CustomPaint(size: Size.infinite, painter: _ScanPainter(t)),
              ),
              Center(
                child: FadeTransition(
                  opacity: textFade,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.5), end: Offset.zero,
                    ).animate(slideIn),
                    child: _ClearCard(stage: stage, subFade: subFade),
                  ),
                ),
              ),
              Opacity(
                opacity: starsFade.value,
                child: CustomPaint(size: Size.infinite, painter: _ParticlePainter(t)),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _ClearCard extends StatelessWidget {
  const _ClearCard({required this.stage, required this.subFade});
  final int stage;
  final Animation<double> subFade;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFF080808),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppPalette.neonGreen, width: 2),
        boxShadow: [
          BoxShadow(color: AppPalette.neonGreen.withAlpha(110), blurRadius: 32, spreadRadius: 4),
          BoxShadow(color: AppPalette.accentPurple.withAlpha(60), blurRadius: 48, spreadRadius: 8),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppPalette.neonGreen.withAlpha(20),
            border: Border.all(color: AppPalette.neonGreen.withAlpha(160), width: 2),
            boxShadow: [BoxShadow(color: AppPalette.neonGreen.withAlpha(80), blurRadius: 16)],
          ),
          child: const Icon(Icons.emoji_events_rounded, color: AppPalette.neonGreen, size: 32),
        ),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            colors: [AppPalette.neonGreen, AppPalette.accentPurple],
          ).createShader(r),
          child: const Text('STAGE CLEARED',
              style: TextStyle(color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.w900, letterSpacing: 3.5)),
        ),
        const SizedBox(height: 6),
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            colors: [Colors.white, AppPalette.neonGreen],
          ).createShader(r),
          child: Text('$stage',
              style: const TextStyle(color: Colors.white, fontSize: 72,
                  fontWeight: FontWeight.w900, height: 1.0)),
        ),
        const SizedBox(height: 4),
        FadeTransition(
          opacity: subFade,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.4), end: Offset.zero,
            ).animate(subFade),
            child: Column(children: [
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: AppPalette.accentPurple.withAlpha(22),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: AppPalette.accentPurple.withAlpha(120)),
                ),
                child: const Text('NEXT STAGE LOADING…',
                    style: TextStyle(color: AppPalette.accentPurple,
                        fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1.8)),
              ),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _MiniStat(icon: Icons.bolt, label: 'ESCAPED'),
                const SizedBox(width: 16),
                _MiniStat(icon: Icons.star_rounded, label: '+1 TROPHY'),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.label});
  final IconData icon; final String label;
  @override
  Widget build(BuildContext ctx) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: AppPalette.neonGreen, size: 13),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(color: AppPalette.textMuted,
        fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.8)),
  ]);
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.width * 0.5 * t;
    canvas.drawCircle(Offset(cx, cy), maxR,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 3
          ..color = AppPalette.accentPurple.withAlpha(((1 - t) * 200).round().clamp(0, 255)));
    canvas.drawCircle(Offset(cx, cy), maxR * 0.65,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 2
          ..color = AppPalette.neonGreen.withAlpha(((1 - t) * 180).round().clamp(0, 255)));
    const rays = 12;
    final rp = Paint()..strokeWidth = 1.5
      ..color = AppPalette.neonGreen.withAlpha(((1 - t) * 120).round().clamp(0, 255));
    for (int i = 0; i < rays; i++) {
      final a = (i / rays) * pi * 2;
      canvas.drawLine(
        Offset(cx + maxR * 0.2 * cos(a), cy + maxR * 0.2 * sin(a)),
        Offset(cx + maxR * 0.95 * cos(a), cy + maxR * 0.95 * sin(a)),
        rp,
      );
    }
    canvas.drawCircle(Offset(cx, cy), maxR * 0.3,
        Paint()..shader = RadialGradient(colors: [
          AppPalette.neonGreen.withAlpha(((1 - t) * 60).round().clamp(0, 255)),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: maxR * 0.3)));
  }
  @override
  bool shouldRepaint(_BurstPainter o) => o.t != t;
}

class _ScanPainter extends CustomPainter {
  _ScanPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final y = t * size.height * 1.5 - size.height * 0.25;
    canvas.drawRect(Rect.fromLTWH(0, y - 2, size.width, 3),
        Paint()..color = AppPalette.neonGreen.withAlpha(60)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    final p = Paint()..color = const Color(0xFF1A1A1A)..strokeWidth = 0.5;
    const step = 36.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double yy = 0; yy < size.height; yy += step) {
      canvas.drawLine(Offset(0, yy), Offset(size.width, yy), p);
    }
  }
  @override
  bool shouldRepaint(_ScanPainter o) => o.t != t;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.t);
  final double t;
  static const _count = 24;
  static final _seeds = List.generate(_count, (i) => (i * 1.618033) % 1.0);
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    for (int i = 0; i < _count; i++) {
      final seed = _seeds[i];
      final angle = seed * pi * 2;
      final r = size.width * 0.58 * t * (0.3 + seed * 0.7);
      final alpha = ((1 - t) * 220).round().clamp(0, 255);
      final radius = (2.5 + seed * 3.0) * (1 - t * 0.5);
      final color = i % 3 == 0
          ? AppPalette.neonGreen.withAlpha(alpha)
          : i % 3 == 1
              ? AppPalette.accentPurple.withAlpha(alpha)
              : AppPalette.accentPink.withAlpha(alpha);
      canvas.drawCircle(
        Offset(cx + r * cos(angle), cy + r * sin(angle)),
        radius, Paint()..color = color,
      );
    }
  }
  @override
  bool shouldRepaint(_ParticlePainter o) => o.t != t;
}
