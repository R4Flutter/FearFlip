import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_runtime_config.dart';
import '../../game/daily/daily_nightmare.dart';
import '../../game/keys/key_box_planner.dart';
import '../../game/keys/key_hunt.dart';
import '../../game/mercy/quiet_mercy.dart';
import '../../game/trap/trap_analytics.dart';
import '../../game/trap/trap_audio_controller.dart';
import '../../game/trap/trap_death_sequence.dart';
import '../../game/trap/trap_difficulty_scaler.dart';
import '../../game/trap/trap_placement_engine.dart';
import '../../game/trap/trap_state_controller.dart';
import '../../game/trap/trap_tile.dart';
import '../../services/audio_manager.dart';
import '../../services/error_reporter.dart';
import '../../services/game_audio_event.dart';
import 'glitch_effect_controller.dart';
import 'maze_art.dart';
import 'maze_camera.dart';
import 'maze_generator.dart';
import 'maze_painter.dart';
import 'maze_shift_manager.dart';
import 'near_miss_text.dart';
import 'player_controller.dart';
import 'stage_rules.dart';
import '../../domain/entities/direction4.dart';
import 'widgets/cyber_horror_ui_components.dart';
import 'widgets/daily_result_dialog.dart';
import 'widgets/debug_stage_dropdown.dart';
import 'widgets/game_controls.dart';
import 'widgets/game_hud.dart';
import 'widgets/run_failed_dialog.dart';
import 'widgets/run_banner.dart';
import 'widgets/run_paused_dialog.dart';
import 'widgets/stage_100_win_dialog.dart';
import 'widgets/stage_clear_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    this.joystickSize = 110,
    this.useArrowController = true,
    this.selectedCharacterIndex = 0,
    this.totalTrophies = 0,
    this.isActive = true,
    this.onExitToDashboard = _noop,
    this.onStageCleared = _noopStageCleared,
    this.onRestartWithAd = _alwaysAllow,
    this.onReviveWithAd = _alwaysAllow,
    this.onBeforeNextStage = _noopStageCleared,
    this.initialStage = 1,
    this.daily,
    this.onDailyEscaped,
    this.onDailyFailed,
    this.onDailyShare,
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

  /// Awaited after a stage-clear celebration, before the next maze loads
  /// (the app offers Google sign-in here after a guest's first clear).
  final Future<void> Function(int clearedStage) onBeforeNextStage;

  /// The stage a run starts on.
  final int initialStage;

  /// Set for a Daily Nightmare run: one seeded maze, the same for everyone,
  /// with free retries and no stage progress, revives or trophies.
  final DailyChallenge? daily;

  /// Daily Nightmare: an escape (returns what the result screen shows), a
  /// failed try, and sharing the result (true when a share sheet opened).
  final Future<DailySummary> Function(DailyRunResult result)? onDailyEscaped;
  final Future<void> Function()? onDailyFailed;
  final Future<bool> Function(String text)? onDailyShare;

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
  final ValueNotifier<int> _gameSurfaceRevision = ValueNotifier<int>(0);
  final FocusNode _keyboardFocusNode = FocusNode(
    debugLabel: 'fear_flip_game_keyboard',
  );
  final Set<LogicalKeyboardKey> _pressedMovementKeys = <LogicalKeyboardKey>{};
  late PlayerController _playerController;
  late AnimationController _stageClearController;
  late final TrapAudioController _trapAudioController;
  late final TrapDeathSequence _trapDeathSequence;
  MazeArt _art = const MazeArt.none();

  /// One-shot effects playing in the maze (smoke, the flip's crack burst).
  final List<MazeFx> _fx = <MazeFx>[];

  /// The key hunt: boxes, keys and the sealed exit
  /// (docs/retention_features.md).
  final KeyBoxPlanner _keyBoxPlanner = KeyBoxPlanner(
    balance: KeyHuntBalance(
      boxCount: AppRuntimeConfig.keyHuntBoxCount,
      keyCount: AppRuntimeConfig.keyHuntKeyCount,
      keysToUnseal: AppRuntimeConfig.keyHuntKeysToUnseal,
    ),
  );
  final KeyHuntController _keyHunt = KeyHuntController();
  Set<Point<int>> _keyHuntReserved = const <Point<int>>{};
  KeyBox? _nearestBox;
  double _keyFlashAt = -100;
  double _sealedBumpAt = -100;
  Timer? _unsealAudioTimer;

  /// Short messages at the top of the run ("KEY 1 OF 2", "SEALED").
  final ValueNotifier<RunBannerMessage?> _banner =
      ValueNotifier<RunBannerMessage?>(null);
  Timer? _bannerTimer;
  int _bannerSerial = 0;

  /// Quiet help for a player stuck on a stage. Never in the Daily Nightmare,
  /// which stays the same for everyone.
  final QuietMercy _mercy = QuietMercy(
    enabled: AppRuntimeConfig.mercyEnabled,
    failThreshold: AppRuntimeConfig.mercyFailThreshold,
    maxLevel: AppRuntimeConfig.mercyMaxLevel,
    bonusSecondsPerLevel: AppRuntimeConfig.mercyBonusSecondsPerLevel,
  );

  /// Where the last run ended, for the near-miss line on the loss screen.
  int _lossDistanceToExit = 0;
  int _lossKeysShort = 0;

  /// Daily Nightmare: the escape screen's numbers once escaped, and the
  /// failed tries since this screen opened.
  DailySummary? _dailySummary;
  int _dailyDeaths = 0;
  static const int _animationFrameCount = 7;
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

  /// How many ad-revives the player has consumed in the current checkpoint band.
  /// Resets to 0 whenever the player crosses a checkpoint boundary.
  int _revivesUsedInCheckpointBand = 0;

  /// True after the player clears stage 100 – shows the crown victory overlay.
  bool _gameComplete = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stage =
        widget.daily?.profileStage ??
        widget.initialStage.clamp(1, _maxStage).toInt();
    _stageRule = StageRules.forStage(_stage);
    _difficulty = _difficultyForStage(_stage);
    _maze = _generateMaze();
    _rebuildPathMetrics();
    _remainingSeconds = _stageDurationSeconds;
    _playerController = PlayerController(
      maze: _maze,
      vsync: this,
      onWin: _onPlayerReachedExit,
      onStep: _onPlayerStep,
      animationFrameCount: _animationFrameCount,
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
    unawaited(_loadArt());
    if (widget.isActive) {
      _lockOrientation(playing: true);
    }
    _requestKeyboardFocusIfNeeded();
  }

  /// A run plays in landscape, like the GBA; the menus stay portrait (as
  /// main.dart sets them).
  static const _playOrientations = [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];
  static const _menuOrientations = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ];

  void _lockOrientation({required bool playing}) {
    if (kIsWeb) {
      return;
    }
    unawaited(
      SystemChrome.setPreferredOrientations(
        playing ? _playOrientations : _menuOrientations,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant GameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _lockOrientation(playing: widget.isActive);
      _handleExternalActivityChange(widget.isActive);
      if (widget.isActive) {
        _requestKeyboardFocusIfNeeded();
      }
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

  @override
  void dispose() {
    if (widget.isActive) {
      _lockOrientation(playing: false);
    }
    _art.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _clearKeyboardMovement(stopPlayer: false);
    _keyboardFocusNode.dispose();
    _countdownTimer?.cancel();
    _stageTimer?.cancel();
    _bannerTimer?.cancel();
    _unsealAudioTimer?.cancel();
    _banner.dispose();
    _stageClearController.dispose();
    _trapDeathSequence.dispose();
    _playerController.dispose();
    _gameSurfaceRevision.dispose();
    super.dispose();
  }

  void _handleExternalActivityChange(bool isActive) {
    final shouldBeInactive = !isActive;
    if (_isExternallyInactive == shouldBeInactive) {
      return;
    }

    _isExternallyInactive = shouldBeInactive;
    if (_isExternallyInactive) {
      _clearKeyboardMovement();
      _playerController.stop();
      unawaited(_audioManager.handle(GameAudioEvent.matchPause));
    } else {
      if (_resetToCheckpointOnReactivation) {
        _resetToCheckpointOnReactivation = false;
        _resetToCheckpoint();
        return;
      }

      // A Daily Nightmare played in between ends the match audio; restart
      // it instead of resuming, or this run would come back silent.
      final audioEnded =
          !_audioManager.isMatchActive &&
          !_audioManager.isWon &&
          !_audioManager.isLost;
      unawaited(
        _audioManager.handle(
          audioEnded ? GameAudioEvent.matchRestart : GameAudioEvent.matchResume,
        ),
      );
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

  bool get _inputBlocked =>
      _roundResolved ||
      _isStageTransition ||
      _isTimeUpHandling ||
      _showLossOverlay ||
      _trapDeathInProgress ||
      _isExternallyInactive ||
      _isPaused;

  void _holdInputDirection(Direction4? direction) {
    if (_inputBlocked) {
      return;
    }
    final effective = _controlsInverted
        ? _invertDirection(direction)
        : direction;
    _playerController.holdDirection(effective);
  }

  void _endInput() {
    if (_inputBlocked) {
      return;
    }
    _playerController.stop();
  }

  void _clearKeyboardMovement({bool stopPlayer = true}) {
    _pressedMovementKeys.clear();
    if (stopPlayer) {
      _playerController.stop();
    }
  }

  void _requestKeyboardFocusIfNeeded() {
    if (!kIsWeb || !mounted || !widget.isActive) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isActive) {
        _keyboardFocusNode.requestFocus();
      }
    });
  }

  KeyEventResult _handleKeyboardEvent(FocusNode node, KeyEvent event) {
    if (!kIsWeb) {
      return KeyEventResult.ignored;
    }

    final direction = _directionForKey(event.logicalKey);
    if (direction == null) {
      return KeyEventResult.ignored;
    }

    if (event is KeyUpEvent) {
      _pressedMovementKeys.remove(event.logicalKey);
      if (_inputBlocked) {
        return KeyEventResult.handled;
      }
      final fallbackDirection = _latestPressedKeyboardDirection();
      if (fallbackDirection == null) {
        _endInput();
      } else {
        _holdInputDirection(fallbackDirection);
      }
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _pressedMovementKeys.add(event.logicalKey);
      if (!_inputBlocked) {
        _holdInputDirection(direction);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Direction4? _latestPressedKeyboardDirection() {
    for (final key in _pressedMovementKeys.toList().reversed) {
      final direction = _directionForKey(key);
      if (direction != null) {
        return direction;
      }
    }
    return null;
  }

  Direction4? _directionForKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp) {
      return Direction4.up;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      return Direction4.down;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      return Direction4.left;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      return Direction4.right;
    }
    return null;
  }

  Future<void> _loadNextMaze() async {
    if (!mounted || _roundResolved || _isStageTransition || _showLossOverlay) {
      return;
    }
    if (!_keyHunt.exitUnsealed) {
      return;
    }

    _roundResolved = true;
    _banner.value = null;

    _playerController.stop();
    _countdownTimer?.cancel();

    try {
      await _audioManager.stopAlarmImmediately();
    } catch (error, stackTrace) {
      ErrorReporter.report(
        reason: 'game_stop_alarm_failed',
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (widget.daily != null) {
      await _finishDailyRun();
      return;
    }

    _mercy.clear();
    setState(() {
      _isStageTransition = true;
      _completedStage = _stage;
    });

    try {
      await _audioManager.handle(GameAudioEvent.playerWon);
    } catch (error, stackTrace) {
      ErrorReporter.report(
        reason: 'game_audio_player_won_failed',
        error: error,
        stackTrace: stackTrace,
      );
    }

    try {
      await widget.onStageCleared(_stage);
    } catch (error, stackTrace) {
      ErrorReporter.report(
        reason: 'game_stage_cleared_callback_failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'stage': _stage},
      );
    }

    await _stageClearController.forward(from: 0);
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) {
      return;
    }

    // Stage 100 cleared → show crown victory overlay instead of advancing.
    if (_completedStage >= _maxStage) {
      setState(() {
        _isStageTransition = false;
        _gameComplete = true;
      });
      return;
    }

    try {
      await widget.onBeforeNextStage(_completedStage);
    } catch (error, stackTrace) {
      ErrorReporter.report(
        reason: 'game_before_next_stage_failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'stage': _completedStage},
      );
    }
    if (!mounted) {
      return;
    }

    // Capture checkpoint band BEFORE advancing the stage counter.
    final previousBandCheckpoint = _checkpoint;

    setState(() {
      _stage = min(_stage + 1, _maxStage);
      _stageRule = StageRules.forStage(_stage);
      _difficulty = _difficultyForStage(_stage);
      _maze = _generateMaze();
      _rebuildPathMetrics();
      _remainingSeconds = _stageDurationSeconds;
      _isStageTransition = false;
    });

    // Reset revive counter whenever the player crosses a checkpoint boundary.
    if (_checkpoint != previousBandCheckpoint) {
      _revivesUsedInCheckpointBand = 0;
    }

    _playerController.resetForMaze(_maze);
    _applyStageRule(resetMaze: false);
    unawaited(_audioManager.handle(GameAudioEvent.matchRestart));
    _restartCountdown();
  }

  // ---------------------------------------------------------------------------
  // Key hunt (docs/retention_features.md)
  // ---------------------------------------------------------------------------

  bool get _isKeyHuntStage =>
      AppRuntimeConfig.keyHuntEnabled &&
      _stage >= AppRuntimeConfig.keyHuntStartStage;

  /// Places this stage's boxes (or clears them). Runs after the safe zones
  /// (boxes avoid them) and before the traps (traps avoid the box routes).
  void _resetKeyHunt() {
    _keyFlashAt = -100;
    _sealedBumpAt = -100;
    _unsealAudioTimer?.cancel();
    if (!_isKeyHuntStage) {
      _keyHunt.clear();
      _keyHuntReserved = const <Point<int>>{};
      _nearestBox = null;
      return;
    }
    final plan = _keyBoxPlanner.plan(
      maze: _maze,
      stage: _stage,
      seed: _stageTrapSeed() ^ 0x5EED,
      avoid: _safeZones.keys.toSet(),
    );
    _keyHunt.reset(plan);
    _keyHuntReserved = plan.reservedCells;
    _nearestBox = _keyHunt.nearestUnopened(_maze, _maze.start);
    if (!plan.isActive) {
      return;
    }
    final keys = plan.boxes.where((box) => box.hasKey).length;
    final need = plan.keysRequired == keys
        ? '$keys KEYS'
        : '${plan.keysRequired} OF $keys KEYS';
    final daily = widget.daily;
    final firstHunt =
        daily == null && _stage == AppRuntimeConfig.keyHuntStartStage;
    _showBanner(
      daily == null ? 'THE EXIT IS SEALED' : 'DAILY NIGHTMARE #${daily.number}',
      subtitle: firstHunt
          ? 'STEP ON THE BOXES · FIND $need'
          : '${plan.boxes.length} BOXES · $need',
      duration: Duration(milliseconds: firstHunt ? 3400 : 2400),
    );
  }

  /// Every cell the runner arrives on: opens a shut box there.
  void _onPlayerStep(Point<int> cell) {
    if (!_keyHunt.isActive || _roundResolved || _isStageTransition) {
      return;
    }
    final result = _keyHunt.openAt(cell, _stageElapsedSeconds);
    switch (result) {
      case KeyBoxOpenResult.none:
        if (!_keyHunt.exitUnsealed) {
          _nearestBox = _keyHunt.nearestUnopened(_maze, cell);
        }
        return;
      case KeyBoxOpenResult.empty:
        _onKeyBoxEmpty(cell);
      case KeyBoxOpenResult.key:
      case KeyBoxOpenResult.unsealed:
        _onKeyFound(cell, unsealed: result == KeyBoxOpenResult.unsealed);
    }
    _nearestBox = _keyHunt.exitUnsealed
        ? null
        : _keyHunt.nearestUnopened(_maze, cell);
    if (mounted) {
      setState(() {});
    }
  }

  void _onKeyFound(Point<int> cell, {required bool unsealed}) {
    final now = _stageElapsedSeconds;
    _fx.add(
      MazeFx(
        MazeFxKind.keyRise,
        Offset(cell.x.toDouble(), cell.y.toDouble()),
        now,
      ),
    );
    _keyFlashAt = now;
    unawaited(_audioManager.handle(GameAudioEvent.keyFound));
    if (unsealed) {
      _fx.add(
        MazeFx(
          MazeFxKind.unseal,
          Offset(_maze.end.x.toDouble(), _maze.end.y.toDouble()),
          now,
        ),
      );
      _unsealAudioTimer?.cancel();
      _unsealAudioTimer = Timer(const Duration(milliseconds: 350), () {
        if (mounted && !_roundResolved) {
          unawaited(_audioManager.handle(GameAudioEvent.exitUnsealed));
        }
      });
      unawaited(HapticFeedback.heavyImpact());
      _showBanner(
        'THE EXIT IS OPEN',
        subtitle: 'RUN!',
        duration: const Duration(milliseconds: 2200),
      );
      return;
    }
    unawaited(HapticFeedback.mediumImpact());
    final left = _keyHunt.keysLeft;
    _showBanner(
      'KEY ${_keyHunt.keysFound} OF ${_keyHunt.keysRequired}',
      subtitle: left == 1 ? 'ONE LOCK LEFT' : '$left LOCKS LEFT',
    );
  }

  void _onKeyBoxEmpty(Point<int> cell) {
    _fx.add(
      MazeFx(
        MazeFxKind.emptyPuff,
        Offset(cell.x.toDouble(), cell.y.toDouble()),
        _stageElapsedSeconds,
      ),
    );
    unawaited(_audioManager.handle(GameAudioEvent.keyBoxEmpty));
    unawaited(HapticFeedback.lightImpact());
    final keysLeft = _keyHunt.keysLeft;
    final boxesLeft = _keyHunt.boxesLeft;
    // The odds stay honest: keys left and the boxes they can be in.
    _showBanner(
      'EMPTY…',
      subtitle: keysLeft > 0
          ? '$keysLeft KEY${keysLeft == 1 ? '' : 'S'} IN $boxesLeft '
                'BOX${boxesLeft == 1 ? '' : 'ES'}'
          : null,
      color: NightHud.boneDim,
    );
  }

  /// The runner arrived on the exit: escape if it's open, else it's sealed.
  void _onPlayerReachedExit() {
    if (_keyHunt.exitUnsealed) {
      unawaited(_loadNextMaze());
      return;
    }
    if (_roundResolved || _isStageTransition) {
      return;
    }
    _sealedBumpAt = _stageElapsedSeconds;
    unawaited(_audioManager.handle(GameAudioEvent.exitSealedBump));
    unawaited(HapticFeedback.selectionClick());
    final left = _keyHunt.keysLeft;
    _showBanner(
      'SEALED',
      subtitle: 'FIND $left MORE KEY${left == 1 ? '' : 'S'}',
      color: NightHud.blood,
    );
  }

  void _showBanner(
    String title, {
    String? subtitle,
    Color color = NightHud.gold,
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    _bannerTimer?.cancel();
    _banner.value = RunBannerMessage(
      title: title,
      subtitle: subtitle,
      color: color,
      serial: ++_bannerSerial,
    );
    _bannerTimer = Timer(duration, () => _banner.value = null);
  }

  // ---------------------------------------------------------------------------
  // Losses: the near-miss line and quiet mercy
  // ---------------------------------------------------------------------------

  /// Bookkeeping for any loss (the Devil, a trap or the clock).
  void _onRunLost() {
    _bannerTimer?.cancel();
    _banner.value = null;
    _lossDistanceToExit =
        _maze.shortestPathDistance(_playerController.position, _maze.end) ?? 0;
    _lossKeysShort = _keyHunt.keysLeft;
    if (widget.daily != null) {
      _dailyDeaths += 1;
      final onFailed = widget.onDailyFailed;
      if (onFailed != null) {
        unawaited(onFailed());
      }
      return;
    }
    _mercy.recordFailure(_stage);
  }

  /// "2 STAGES TO CHECKPOINT 25" under the near miss.
  String _nearMissDetail() {
    final daily = widget.daily;
    if (daily != null) {
      return 'DAILY NIGHTMARE #${daily.number} · FREE RETRIES';
    }
    return checkpointProgressText(
      stage: _stage,
      milestone: _nextMilestoneStage(),
      maxStage: _maxStage,
    );
  }

  // ---------------------------------------------------------------------------
  // Daily Nightmare
  // ---------------------------------------------------------------------------

  /// The daily maze comes from the day's seed, the same for everyone; a run
  /// maze is random.
  MazeGrid _generateMaze() => _generator.generate(
    rows: _difficulty,
    cols: _difficulty,
    seed: widget.daily?.seed,
  );

  Future<void> _finishDailyRun() async {
    final daily = widget.daily!;
    final seconds = max(0, _stageDurationSeconds - _remainingSeconds);
    final keys = _keyHunt.keysFound;
    setState(() => _isStageTransition = true);
    try {
      await _audioManager.handle(GameAudioEvent.playerWon);
    } catch (error, stackTrace) {
      ErrorReporter.report(
        reason: 'game_audio_player_won_failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
    final result = DailyRunResult(seconds: seconds, keys: keys);
    var summary = DailySummary(
      number: daily.number,
      seconds: seconds,
      bestSeconds: seconds,
      keys: keys,
      deaths: _dailyDeaths,
      streak: 1,
      freezes: 0,
      shareText: dailyShareText(
        number: daily.number,
        seconds: seconds,
        keys: keys,
        deaths: _dailyDeaths,
        streak: 1,
      ),
    );
    final onEscaped = widget.onDailyEscaped;
    if (onEscaped != null) {
      try {
        summary = await onEscaped(result);
      } catch (error, stackTrace) {
        ErrorReporter.report(
          reason: 'daily_escape_record_failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    if (!mounted) {
      return;
    }
    unawaited(HapticFeedback.heavyImpact());
    setState(() => _dailySummary = summary);
  }

  /// Another try at the same daily maze (after a loss, or to beat a time).
  void _restartDaily() {
    _countdownTimer?.cancel();
    setState(() {
      _dailySummary = null;
      _isStageTransition = false;
      _isTimeUpHandling = false;
      _showLossOverlay = false;
      _lostByTime = false;
      _lostByTrap = false;
      _trapDeathQuote = null;
      _trapDeathInProgress = false;
      _adActionInProgress = false;
      // Fresh from the seed, so even shifted walls are back as they were.
      _maze = _generateMaze();
      _rebuildPathMetrics();
      _remainingSeconds = _stageDurationSeconds;
    });
    _trapDeathSequence.cancel();
    _playerController.resetForMaze(_maze);
    _applyStageRule(resetMaze: false);
    unawaited(_audioManager.handle(GameAudioEvent.matchExit));
    unawaited(_audioManager.handle(GameAudioEvent.matchRestart));
    _restartCountdown();
    _requestKeyboardFocusIfNeeded();
  }

  Future<void> _exitDaily() async {
    await _audioManager.handle(GameAudioEvent.matchExit);
    widget.onExitToDashboard();
  }

  Future<bool> _shareDaily() async {
    final summary = _dailySummary;
    if (summary == null) {
      return false;
    }
    final share = widget.onDailyShare;
    if (share != null) {
      return share(summary.shareText);
    }
    await Clipboard.setData(ClipboardData(text: summary.shareText));
    return false;
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

  /// The clock: the base, plus time for the box detours on key-hunt stages,
  /// plus quiet mercy for a player stuck on this stage.
  int get _stageDurationSeconds {
    var seconds = _defaultStageDurationSeconds;
    if (_isKeyHuntStage) {
      seconds += AppRuntimeConfig.keyHuntExtraSeconds;
    }
    if (widget.daily == null) {
      seconds += _mercy.bonusSecondsFor(_stage);
    }
    return seconds;
  }

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

  void _markGameSurfaceDirty() {
    if (!mounted) {
      return;
    }
    _gameSurfaceRevision.value += 1;
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
    _audioFrameId += 1;
    _stageElapsedSeconds += dt;

    // Reaching the open exit wins and advances to the next stage.
    if (_keyHunt.canEscape(_playerController.position, _maze.end)) {
      unawaited(_loadNextMaze());
      return;
    }

    _mazeShiftManager.tick(dt);
    final wasGlitchActive = _glitchEffectController.isActive;
    _glitchEffectController.update(dt);
    if (wasGlitchActive && !_glitchEffectController.isActive) {
      unawaited(_audioManager.handle(GameAudioEvent.mazeShiftEnded));
    }

    final timeToFlip = _nextFlipAtSeconds - _stageElapsedSeconds;
    if (timeToFlip <= _stageRule.warningTime && timeToFlip > 0) {}

    if (_stageElapsedSeconds >= _nextFlipAtSeconds) {
      _controlsInverted = !_controlsInverted;
      _fx.add(
        MazeFx(
          MazeFxKind.flip,
          _playerController.renderPosition,
          _stageElapsedSeconds,
        ),
      );
      _playerController.setControlsInverted(_controlsInverted);
      unawaited(
        _audioManager.handle(
          GameAudioEvent.flipTriggered,
          frameId: _audioFrameId,
        ),
      );
      _nextFlipAtSeconds = _stageElapsedSeconds + _nextFlipInterval();
    }

    final wasPlayerSafe = _playerSafe;
    _updateSafeZones();
    if (!wasPlayerSafe && _playerSafe) {
      _onSafeZoneEntered();
    } else if (wasPlayerSafe && !_playerSafe) {
      unawaited(_audioManager.handle(GameAudioEvent.safeZoneExited));
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
            break;
          case TrapStepResult.trapCollapsed:
            final tile = _trapStateController.trapAt(playerCell);
            if (tile != null) {
              tile.collapseProgress = 1;
              pendingTrapCollapse = tile;
            }
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
    }

    _maybeTriggerMazeShift();

    final hazardGraceActive = _mazeShiftManager.hazardGraceActive;
    if (_canSpawnDevilNow()) {
      _devilSpawned = true;
      _devilCell = _spawnDevilCell();
      _addSmoke(_devilCell!);
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
        final double dx = (_devilCell!.x - _playerController.position.x)
            .toDouble();
        final double dy = (_devilCell!.y - _playerController.position.y)
            .toDouble();
        final double euclideanDist = sqrt(dx * dx + dy * dy);
        final double mapDiag = sqrt(
          pow(_maze.cols - 1, 2).toDouble() + pow(_maze.rows - 1, 2).toDouble(),
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
          final double t = (euclideanDist - nearDist) / (farDist - nearDist);
          distanceFactor = minFactor + (maxFactor - minFactor) * t;
        }
        final devilStepsPerSecond = (baseDevilSpeed * distanceFactor).clamp(
          0.2,
          4.0,
        );
        final stepInterval = 1.0 / devilStepsPerSecond;
        while (_devilMoveAccumulator >= stepInterval) {
          _devilMoveAccumulator -= stepInterval;
          _devilCell = _nextDevilStep(_devilCell!, _playerController.position);
        }
      } else {
        _devilMoveAccumulator = 0;
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
    }

    _fx.removeWhere((fx) => _stageElapsedSeconds - fx.start >= fx.duration);

    // Idle animations (exit gate, devil bob, breathing) are time-driven, so
    // the surface repaints every tick instead of only on state changes.
    _markGameSurfaceDirty();
  }

  void _addSmoke(Point<int> cell) => _fx.add(
    MazeFx(
      MazeFxKind.smoke,
      Offset(cell.x.toDouble(), cell.y.toDouble()),
      _stageElapsedSeconds,
    ),
  );

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
    _onRunLost();
    try {
      await _audioManager.handle(GameAudioEvent.playerLost);
    } catch (error, stackTrace) {
      ErrorReporter.report(
        reason: 'game_audio_player_lost_failed',
        error: error,
        stackTrace: stackTrace,
      );
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
      _maze = _generateMaze();
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
    _resetKeyHunt();
    _rebuildTrapTilesForCurrentStage();
    _fx.clear();
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
      reservedCells: _keyHuntReserved,
    );

    final filteredTiles = placedTiles
        .where(
          (tile) =>
              !_safeZones.containsKey(tile.cell) &&
              !_keyHuntReserved.contains(tile.cell),
        )
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
    _markGameSurfaceDirty();
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
    _onRunLost();

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

    final camera = _surfaceCamera();
    if (camera == null) {
      await _finalizeTrapDeath(withCinematic: false);
      return;
    }

    setState(() {
      _trapDeathInProgress = true;
      _lostByTrap = true;
      _lostByTime = false;
    });

    _trapDeathSequence.start(
      trapCenter: camera.cellCenter(
        Offset(tile.cell.x.toDouble(), tile.cell.y.toDouble()),
      ),
      cellSize: camera.tileSize,
      debris: _art.debris,
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
    } catch (error, stackTrace) {
      ErrorReporter.report(
        reason: 'trap_audio_failed',
        error: error,
        stackTrace: stackTrace,
      );
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

  /// The same camera [MazePainter] draws with, so overlays line up with it.
  MazeCamera? _surfaceCamera() {
    final context = _gameSurfaceSizeKey.currentContext;
    if (context == null) {
      return null;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }

    return MazeCamera.follow(
      viewport: renderObject.size,
      maze: _maze,
      focus: _playerController.renderPosition,
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
    final banished = _devilCell;
    if (banished != null) {
      _addSmoke(banished);
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

  bool _maybeTriggerMazeShift() {
    final phase = _mazeShiftManager.pendingPhase;
    if (phase == MazeShiftPhase.none) {
      return false;
    }

    _mazeShiftManager.markPhaseTriggered(phase);
    _glitchEffectController.trigger();

    final shutBoxes = _keyHunt.unopened.toList(growable: false);
    final outcome = _mazeShiftManager.triggerMazeShift(
      phase: phase,
      maze: _maze,
      playerPosition: _playerController.position,
      exitPosition: _maze.end,
      protectedCells: {for (final box in shutBoxes) ...box.sidePath},
      mustReach: [for (final box in shutBoxes) box.cell],
    );
    if (!outcome.applied) {
      return _glitchEffectController.isActive;
    }
    if (_keyHunt.isActive) {
      // The walls moved: no trap may now sit on a route to a box or the exit.
      _trapStateController.removeTilesOn(
        _keyHunt.objectiveCells(_maze, _playerController.position, _maze.end),
      );
      _nearestBox = _keyHunt.exitUnsealed
          ? null
          : _keyHunt.nearestUnopened(_maze, _playerController.position);
    }

    unawaited(_audioManager.handle(GameAudioEvent.mazeShiftStarted));

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
    return true;
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

    if (trail.length > distance) {
      final target = trail[trail.length - 1 - distance];
      if (target != player) {
        return target;
      }
    }

    for (var i = trail.length - 2; i >= 0; i--) {
      final candidate = trail[i];
      final gap =
          (candidate.x - player.x).abs() + (candidate.y - player.y).abs();
      if (gap >= 2) {
        return candidate;
      }
    }

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
    final extra = widget.daily == null ? _mercy.extraSafeZonesFor(_stage) : 0;
    _safeZones
      ..clear()
      ..addAll(
        _buildSafeZones(count: _safeZonesPerStage + extra, duration: 1.0),
      );
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
    _onRunLost();
    try {
      await _audioManager.handle(GameAudioEvent.playerLost);
    } catch (error, stackTrace) {
      ErrorReporter.report(
        reason: 'game_audio_player_lost_failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
    setState(() {
      _showLossOverlay = true;
      _lostByTime = true;
      _lostByTrap = false;
      _trapDeathQuote = null;
    });
    _isTimeUpHandling = false;
  }

  /// On the exit with enough keys to open it.
  bool get _playerReachedGoal =>
      _keyHunt.canEscape(_playerController.position, _maze.end);

  // ---------------------------------------------------------------------------
  // Revive-life system
  // ---------------------------------------------------------------------------

  /// Maximum ad-revives allowed for the current checkpoint band.
  /// Returns -1 for unlimited (stages 1–25).
  int get _maxRevivesForCurrentBand {
    if (_stage <= 25) return -1;
    if (_stage <= 50) return AppRuntimeConfig.reviveLimitBand25to50;
    if (_stage <= 75) return AppRuntimeConfig.reviveLimitBand50to75;
    return AppRuntimeConfig.reviveLimitBand75to100;
  }

  /// True when the player still has at least one ad-revive available.
  bool get _canRevive {
    final max = _maxRevivesForCurrentBand;
    if (max == -1) return true;
    return _revivesUsedInCheckpointBand < max;
  }

  /// Lives remaining in the current band. -1 = unlimited (no hearts shown).
  int get _livesRemaining {
    final max = _maxRevivesForCurrentBand;
    if (max == -1) return -1;
    return (max - _revivesUsedInCheckpointBand).clamp(0, max);
  }

  /// Max lives to display as hearts. 0 when the band is unlimited.
  int get _maxLivesForHud =>
      _maxRevivesForCurrentBand == -1 ? 0 : _maxRevivesForCurrentBand;

  Future<void> _onExitPressed() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: RealityGlassPanel(color: NightHud.boneDim),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const HorrorHeader(
                        title: 'BREAK CYCLE?',
                        subtitle: 'EXTERNAL REALITY DETECTED',
                        icon: Icons.exit_to_app_rounded,
                        color: NightHud.boneDim,
                        emblem: 'house',
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'LEAVING WILL PURGE UNSAVED PROGRESS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: NightHud.blood,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      FearButton(
                        label: 'STAY IN HELL',
                        color: NightHud.amber,
                        onPressed: () => Navigator.pop(context, false),
                        isPrimary: true,
                      ),
                      const SizedBox(height: 12),
                      FearButton(
                        label: 'CONFIRM ABORT',
                        color: NightHud.blood,
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldExit == true && mounted) {
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
      _clearKeyboardMovement();
      _playerController.stop();
      unawaited(_audioManager.handle(GameAudioEvent.matchPause));
    } else {
      _requestKeyboardFocusIfNeeded();
      unawaited(_audioManager.handle(GameAudioEvent.matchResume));
      unawaited(
        _audioManager.handle(
          GameAudioEvent.timeChanged,
          secondsLeft: _remainingSeconds,
        ),
      );
    }
  }

  Future<void> _loadArt() async {
    final art = await MazeArt.load();
    if (!mounted) {
      art.dispose();
      return;
    }
    _art.dispose();
    _art = art;
    _markGameSurfaceDirty();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final shortestSide = min(screenSize.width, screenSize.height);
    final uiScale = (shortestSide / 390).clamp(0.84, 1.2);
    final horizontalPadding = (14 * uiScale).clamp(10.0, 20.0);
    final verticalPadding = (10 * uiScale).clamp(8.0, 16.0);
    final showTouchControls = !kIsWeb;

    final gameContent = Material(
      color: NightHud.ink,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The maze is the whole screen, like the GBA: no box, no frame.
          _buildGameSurface(),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Stack(
                children: [
                  GameHud(
                    stage: _stage,
                    remainingSeconds: _remainingSeconds,
                    totalSeconds: _stageDurationSeconds,
                    isPaused: _isPaused,
                    onPauseTap: _togglePause,
                    checkpoint: widget.daily == null ? _checkpoint : 0,
                    livesRemaining: _livesRemaining,
                    maxLives: _maxLivesForHud,
                    keysFound: _keyHunt.keysFound,
                    keysRequired: _keyHunt.keysRequired,
                    boxesLeft: _keyHunt.boxesLeft,
                    stageLabel: widget.daily == null
                        ? null
                        : '#${widget.daily!.number}',
                  ),
                  Positioned(
                    top: 46 * uiScale,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: RunBanner(message: _banner, scale: uiScale),
                    ),
                  ),
                  // A fixed, see-through pad over the maze's bottom-left.
                  if (showTouchControls)
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: widget.useArrowController
                          ? ArrowPad(
                              size: widget.joystickSize,
                              onDirection: _holdInputDirection,
                              onEnd: _endInput,
                            )
                          : Joystick(
                              size: widget.joystickSize,
                              onDirection: _holdInputDirection,
                              onEnd: _endInput,
                            ),
                    ),
                  if (AppRuntimeConfig.debugStageDropdownEnabled)
                    Positioned(
                      top: 4,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: DebugStageDropdown(
                          currentStage: _stage,
                          maxStage: _maxStage,
                          onStageSelected: _jumpToStageForDebug,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (_isPaused)
            Positioned.fill(
              child: Container(
                color: const Color(0xC0000000),
                child: _fitted(
                  RunPausedDialog(
                    stage: _stage,
                    stageLabel: widget.daily == null ? 'STAGE' : 'DAILY',
                    stageValue: widget.daily == null
                        ? null
                        : '#${widget.daily!.number}',
                    checkpoint: _checkpoint,
                    nextCheckpoint: _nextMilestoneStage(),
                    checkpointText: widget.daily == null
                        ? _checkpointPushText()
                        : 'Daily Nightmare · free retries',
                    modeLabel: _modeLabel,
                    timeRemainingLabel: _timeLabel.replaceFirst('TIME: ', ''),
                    onResumePressed: _togglePause,
                    onExitPressed: _onExitPressed,
                  ),
                ),
              ),
            ),

          if (_isStageTransition && widget.daily == null)
            StageClearOverlay(
              stage: _completedStage,
              controller: _stageClearController,
            ),

          if (_dailySummary != null)
            Positioned.fill(
              child: Container(
                color: const Color(0xD9000000),
                child: _fitted(
                  DailyResultDialog(
                    summary: _dailySummary!,
                    onShare: _shareDaily,
                    onPlayAgain: _restartDaily,
                    onMenu: () => unawaited(_exitDaily()),
                  ),
                ),
              ),
            ),

          if (_showLossOverlay)
            Positioned.fill(
              child: Container(
                color: const Color(0xD9000000),
                child: _fitted(
                  RunFailedDialog(
                    stage: _stage,
                    maxStage: _maxStage,
                    escapePercent: _escapePercent(),
                    checkpointText: _checkpointPushText(),
                    modeLabel: _modeLabel,
                    timeRemainingLabel: _timeLabel.replaceFirst('TIME: ', ''),
                    lossReason: _lossReasonText(),
                    comebackHook: _comebackHookText(),
                    lostByTime: _lostByTime,
                    lostByTrap: _lostByTrap,
                    trapDeathQuote: _trapDeathQuote,
                    adActionInProgress: _adActionInProgress,
                    livesRemaining: _livesRemaining,
                    maxLives: _maxLivesForHud,
                    nearMissText: nearMissText(
                      tilesToExit: _lossDistanceToExit,
                      keysShort: _lossKeysShort,
                    ),
                    nearMissDetail: _nearMissDetail(),
                    dailyNumber: widget.daily?.number,
                    dailyDeaths: _dailyDeaths,
                    onRevivePressed: widget.daily == null
                        ? _onReviveFromLoss
                        : () async => _restartDaily(),
                    onRestartPressed: widget.daily == null
                        ? _onRestartFromLoss
                        : _exitDaily,
                  ),
                ),
              ),
            ),

          // ── Stage 100 crown victory overlay ───────────────────────────
          if (_gameComplete)
            Positioned.fill(
              child: Container(
                color: const Color(0xE6000000),
                child: _fitted(
                  Stage100WinDialog(
                    onPlayAgain: _onGameCompletePlayAgain,
                    onExit: widget.onExitToDashboard,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: kIsWeb && widget.isActive,
      canRequestFocus: kIsWeb && widget.isActive,
      onFocusChange: (hasFocus) {
        if (!hasFocus) {
          _clearKeyboardMovement();
        }
      },
      onKeyEvent: _handleKeyboardEvent,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _requestKeyboardFocusIfNeeded(),
        child: gameContent,
      ),
    );
  }

  int _escapePercent() {
    return ((_stage.clamp(1, _maxStage) / _maxStage) * 100).round();
  }

  int _nextMilestoneStage() {
    if (_stage < 25) return 25;
    if (_stage < 50) return 50;
    if (_stage < 75) return 75;
    return _maxStage;
  }

  String _lossReasonText() {
    if (_lostByTrap) return 'Floor collapsed beneath you.';
    return _lostByTime ? 'Clock hit zero.' : 'Devil intercepted you.';
  }

  String _comebackHookText() {
    if (_lostByTrap) return 'Reroute and punish the maze.';
    final percent = _escapePercent();
    if (percent >= 90) return 'Inches away. Lock in.';
    if (percent >= 70) return 'Strong run. Try again.';
    return 'Momentum is building. Surge forward.';
  }

  String _checkpointPushText() {
    final milestone = _nextMilestoneStage();
    if (_stage >= milestone) return 'Checkpoint secured';
    final remaining = milestone - _stage;
    return '$remaining stage${remaining == 1 ? '' : 's'} to $milestone';
  }

  /// Resets the run back to stage 1 after the Stage-100 crown dialog.
  void _onGameCompletePlayAgain() {
    setState(() {
      _gameComplete = false;
      _stage = 1;
      _stageRule = StageRules.forStage(_stage);
      _difficulty = _difficultyForStage(_stage);
      _maze = _generateMaze();
      _rebuildPathMetrics();
      _remainingSeconds = _stageDurationSeconds;
      _revivesUsedInCheckpointBand = 0;
      _roundResolved = false;
    });
    _playerController.resetForMaze(_maze);
    _applyStageRule(resetMaze: false);
    unawaited(_audioManager.handle(GameAudioEvent.matchRestart));
    _restartCountdown();
  }

  Future<void> _onRestartFromLoss() async {
    if (_adActionInProgress) return;
    setState(() => _adActionInProgress = true);
    final shown = await widget.onRestartWithAd();
    if (!mounted) return;
    if (shown) _resetToCheckpoint();
    setState(() => _adActionInProgress = false);
  }

  Future<void> _onReviveFromLoss() async {
    if (_adActionInProgress) return;

    // If the player has exhausted all revive lives for this band, fall back to
    // a checkpoint restart instead of attempting to show a rewarded ad.
    if (!_canRevive) {
      await _onRestartFromLoss();
      return;
    }

    setState(() => _adActionInProgress = true);
    final shown = await widget.onReviveWithAd();
    if (!mounted) return;
    if (shown) {
      // Consume one life from the current band.
      setState(() => _revivesUsedInCheckpointBand += 1);
      _restartCurrentStageFromStart();
      return;
    } else {
      setState(() => _adActionInProgress = false);
    }
  }

  void _recordTrapRecoveryIntent(String eventType) {
    if (!_lostByTrap) return;
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
    unawaited(_audioManager.handle(GameAudioEvent.matchExit));
    unawaited(_audioManager.handle(GameAudioEvent.matchRestart));
    _restartCountdown();
    setState(() {});
  }

  void _resetToCheckpoint() {
    _recordTrapRecoveryIntent('checkpoint_reset_after_trap_death');
    final checkpointStage = _checkpoint == 0 ? 1 : _checkpoint;
    _stage = checkpointStage.clamp(1, _maxStage);
    _stageRule = StageRules.forStage(_stage);
    _difficulty = _difficultyForStage(_stage);
    _maze = _generateMaze();
    _rebuildPathMetrics();
    _remainingSeconds = _stageDurationSeconds;
    _isStageTransition = false;
    _showLossOverlay = false;
    _lostByTime = false;
    _lostByTrap = false;
    _trapDeathQuote = null;
    _trapDeathInProgress = false;
    _trapDeathSequence.cancel();
    // Reset the revive counter – the player is starting fresh from checkpoint.
    _revivesUsedInCheckpointBand = 0;
    _playerController.resetForMaze(_maze);
    _applyStageRule(resetMaze: false);
    unawaited(_audioManager.handle(GameAudioEvent.matchExit));
    unawaited(_audioManager.handle(GameAudioEvent.matchRestart));
    _restartCountdown();
    setState(() {});
  }

  void _jumpToStageForDebug(int targetStage) {
    final stage = targetStage.clamp(1, _maxStage);
    if (_stage == stage && !_showLossOverlay && !_isStageTransition) return;
    _countdownTimer?.cancel();
    _stageClearController.stop();
    _stageClearController.reset();
    _stage = stage;
    _stageRule = StageRules.forStage(_stage);
    _difficulty = _difficultyForStage(_stage);
    _maze = _generateMaze();
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
    _revivesUsedInCheckpointBand = 0;
    _playerController.resetForMaze(_maze);
    _applyStageRule(resetMaze: false);
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

  /// A run dialog, shrunk to fit the screen (a landscape phone is shorter
  /// than the dialog), never grown.
  Widget _fitted(Widget dialog) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(width: 460, child: dialog),
        ),
      ),
    ),
  );

  Widget _buildGameSurface() {
    return RepaintBoundary(
      key: GameScreen.gameSurfaceKey,
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[
          _playerController,
          _gameSurfaceRevision,
        ]),
        builder: (context, _) {
          final pulse = (_stageElapsedSeconds * 1.25) % 1.0;
          final trapTiles = List<TrapTile>.unmodifiable(
            _trapStateController.activeTiles,
          );
          return GlitchEffectOverlay(
            controller: _glitchEffectController,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  key: _gameSurfaceSizeKey,
                  painter: MazePainter(
                    maze: _maze,
                    playerCellPosition: _playerController.renderPosition,
                    direction: _playerController.direction,
                    currentFrame: _playerController.currentFrame,
                    isMoving: _playerController.isMoving,
                    pulse: pulse,
                    time: _stageElapsedSeconds,
                    art: _art,
                    devilCell: _devilCell,
                    safeZones: _safeZones,
                    playerSafe: _playerSafe,
                    isFlippedMode: _controlsInverted,
                    trapTiles: trapTiles,
                    trapHiddenCueLevel: _trapStageConfig.hiddenCueLevel,
                    hidePlayer: _trapDeathInProgress,
                    effects: List<MazeFx>.unmodifiable(_fx),
                    keyBoxes: _keyHunt.boxes,
                    keysFound: _keyHunt.keysFound,
                    keysRequired: _keyHunt.keysRequired,
                    boxPointer: _nearestBox?.cell,
                    keyFlashAt: _keyFlashAt,
                    sealedBumpAt: _sealedBumpAt,
                  ),
                ),
                if (_trapDeathInProgress)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _trapDeathSequence.painter),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
