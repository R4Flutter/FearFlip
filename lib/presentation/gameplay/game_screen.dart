import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_palette.dart';
import '../../services/audio_service.dart';
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

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  final MazeGenerator _generator = MazeGenerator();
  final AudioService _audioService = AudioService();
  final MazeShiftManager _mazeShiftManager = MazeShiftManager();
  final GlitchEffectController _glitchEffectController =
      GlitchEffectController();
  late PlayerController _playerController;
  late AnimationController _pulseController;
  late AnimationController _stageClearController;
  ui.Image? _playerSprite;
  // characters.png uses a 32x32 grid: 736x128 => 23 columns x 4 rows.
  static const int _spriteColumns = 23;
  static const int _spriteRows = 4;
  static const int _maxStage = 100;
  static const int _maxPlayableMazeSize = 17;
  static const int _safeZonesPerStage = 2;
  static const int _persistentSafeZonesUntilStage = 75;
  static const double _devilMinPathClearance = 0.30;
  static const int _devilAudioTriggerDistanceTiles = 10;
  static const int _defaultStageDurationSeconds = 120;
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
  double _stageElapsedSeconds = 0;
  double _nextFlipAtSeconds = 0;
  bool _flipWarningActive = false;
  double _flipWarningTimeLeft = 0;
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
  bool _isPaused = false;
  bool _isExternallyInactive = false;
  bool _lowTimeAlarmPlayed = false;
  bool _devilProximityLoopStarted = false;

  @override
  void initState() {
    super.initState();
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

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0,
      upperBound: 1,
    )..repeat(reverse: true);

    _stageClearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    unawaited(_audioService.setCriticalGameplayAudioOnly(true));
    unawaited(_audioService.warmUp());
    _isExternallyInactive = !widget.isActive;
    _applyStageRule(resetMaze: false);
    _startCountdown();
    _startStageLoop();
    _loadCharactersSprite();
  }

  @override
  void didUpdateWidget(covariant GameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _handleExternalActivityChange(widget.isActive);
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
      _devilProximityLoopStarted = false;
      _lowTimeAlarmPlayed = false;
      unawaited(_stopDangerAudio());
    } else {
      final canResumeLowTimeAlarm =
          _remainingSeconds <= 10 &&
          !_showLossOverlay &&
          !_isStageTransition &&
          !_isTimeUpHandling &&
          !_isPaused &&
          !_lowTimeAlarmPlayed;
      if (canResumeLowTimeAlarm) {
        _lowTimeAlarmPlayed = true;
        unawaited(_audioService.startLowTimeAlarmLoop());
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadNextMaze() async {
    if (_isStageTransition) {
      return;
    }

    _playerController.stop();
    _countdownTimer?.cancel();
    await _stopDangerAudio();
    await _stopOutcomeAudio();

    setState(() {
      _isStageTransition = true;
      _completedStage = _stage;
    });

    await _audioService.startWinningTransitionLoop();

    try {
      await widget.onStageCleared(_stage);
    } catch (_) {
      // Keep stage progression crash-safe even if trophy persistence fails.
    }

    await _stageClearController.forward(from: 0);
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) {
      await _audioService.stopWinningTransitionLoop();
      return;
    }

    await _audioService.stopWinningTransitionLoop();

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
    _restartCountdown();
  }

  Future<void> _jumpToStage(int stage) async {
    if (!mounted ||
        _isStageTransition ||
        _isTimeUpHandling ||
        _adActionInProgress) {
      return;
    }

    final targetStage = stage.clamp(1, _maxStage);
    _playerController.stop();
    await _stopDangerAudio();
    await _stopOutcomeAudio();

    setState(() {
      _stage = targetStage;
      _stageRule = StageRules.forStage(_stage);
      _difficulty = _difficultyForStage(_stage);
      _maze = _generator.generate(rows: _difficulty, cols: _difficulty);
      _rebuildPathMetrics();
      _remainingSeconds = _stageDurationSeconds;
      _showLossOverlay = false;
      _lostByTime = false;
      _isStageTransition = false;
    });

    _playerController.resetForMaze(_maze);
    _applyStageRule(resetMaze: false);
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

  Future<void> _stopDangerAudio() async {
    await Future.wait<void>([
      _audioService.stopDevilProximityLoop(),
      _audioService.stopLowTimeAlarmLoop(),
    ]);
  }

  Future<void> _stopOutcomeAudio() async {
    await Future.wait<void>([
      _audioService.stopWinningTransitionLoop(),
      _audioService.stopGameLostCue(),
      _audioService.stopSafeZoneCue(),
    ]);
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
      if (_showLossOverlay) {
        unawaited(_audioService.stopLowTimeAlarmLoop());
        return;
      }
      if (_isExternallyInactive || _isPaused) {
        return;
      }
      if (_remainingSeconds <= 0) {
        _countdownTimer?.cancel();
        unawaited(_audioService.stopLowTimeAlarmLoop());
        return;
      }
      setState(() {
        _remainingSeconds -= 1;
      });

      if (_remainingSeconds <= 10 && !_lowTimeAlarmPlayed) {
        _lowTimeAlarmPlayed = true;
        unawaited(_audioService.startLowTimeAlarmLoop());
      }

      if (_remainingSeconds <= 0) {
        _countdownTimer?.cancel();
        unawaited(_audioService.stopLowTimeAlarmLoop());
        unawaited(_onTimeExpired());
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
        _isStageTransition ||
        _isTimeUpHandling ||
        _showLossOverlay ||
        _isExternallyInactive ||
        _isPaused) {
      return;
    }

    final dt = _stageTickSeconds;
    _stageElapsedSeconds += dt;
    _mazeShiftManager.tick(dt);
    _glitchEffectController.update(dt);

    final timeToFlip = _nextFlipAtSeconds - _stageElapsedSeconds;
    if (timeToFlip <= _stageRule.warningTime && timeToFlip > 0) {
      _flipWarningActive = true;
      _flipWarningTimeLeft = timeToFlip;
    }

    if (_stageElapsedSeconds >= _nextFlipAtSeconds) {
      _controlsInverted = !_controlsInverted;
      _playerController.setControlsInverted(_controlsInverted);
      unawaited(_audioService.playFlipCue());
      _flipWarningActive = false;
      _flipWarningTimeLeft = 0;
      _nextFlipAtSeconds = _stageElapsedSeconds + _nextFlipInterval();
    }

    final wasPlayerSafe = _playerSafe;
    _updateSafeZones();
    if (!wasPlayerSafe && _playerSafe) {
      _onSafeZoneEntered();
    }

    _trackPlayerSteps();
    _maybeTriggerMazeShift();

    final hazardGraceActive = _mazeShiftManager.hazardGraceActive;

    if (_canSpawnDevilNow()) {
      _devilSpawned = true;
      _devilCell = _spawnDevilCell();
      _devilProximityLoopStarted = false;
    }

    if (_devilSpawned && _devilCell != null) {
      if (!hazardGraceActive) {
        _devilMoveAccumulator += dt;
        final playerSpeed = _stageRule.playerSpeedMultiplier <= 0
            ? 1.0
            : _stageRule.playerSpeedMultiplier;
        final speedRatio = (_stageRule.devilSpeedMultiplier / playerSpeed)
            .clamp(0.0, 1.0);
        final devilStepsPerSecond =
            (_stageRule.devilStepsPerSecond * speedRatio).clamp(0.2, 3.0);
        final stepInterval = 1.0 / devilStepsPerSecond;
        while (_devilMoveAccumulator >= stepInterval) {
          _devilMoveAccumulator -= stepInterval;
          _devilCell = _nextDevilStep(_devilCell!, _playerController.position);
        }
      } else {
        _devilMoveAccumulator = 0;
      }

      final distanceCells =
          (_devilCell!.x - _playerController.position.x).abs() +
          (_devilCell!.y - _playerController.position.y).abs();
      final shouldStartDevilLoop =
          distanceCells <= _devilAudioTriggerDistanceTiles;
      if (shouldStartDevilLoop && !_devilProximityLoopStarted) {
        _devilProximityLoopStarted = true;
        unawaited(_audioService.startDevilProximityLoop());
      }

      if (_devilCell == _playerController.position &&
          !_playerSafe &&
          !hazardGraceActive) {
        unawaited(_onDevilCaught());
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _onDevilCaught() async {
    if (!mounted ||
        _isTimeUpHandling ||
        _isStageTransition ||
        _showLossOverlay) {
      return;
    }
    _isTimeUpHandling = true;
    _isPaused = false;
    unawaited(_audioService.stopLowTimeAlarmLoop());
    _playerController.stop();
    await _stopDangerAudio();
    await _stopOutcomeAudio();
    _devilProximityLoopStarted = false;
    await _audioService.playGameLostCue();
    setState(() {
      _showLossOverlay = true;
      _lostByTime = false;
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
    _flipWarningActive = false;
    _flipWarningTimeLeft = 0;
    _devilCell = null;
    _devilSpawned = false;
    _devilMoveAccumulator = 0;
    _lastPlayerCell = _maze.start;
    _stepsSinceSafeZone = 0;
    _awaitingDevilRespawnSteps = false;
    _playerSafe = false;
    _rebuildPathMetrics();
    _mazeShiftManager.startStage(
      stage: _stage,
      totalSteps: _mazeShiftTotalSteps,
    );
    _resetSafeZones();
    _showLossOverlay = false;
    _adActionInProgress = false;
    _lostByTime = false;
    _isPaused = false;
    _lowTimeAlarmPlayed = false;
    _devilProximityLoopStarted = false;
    _glitchEffectController.clear();
    unawaited(_stopDangerAudio());
    unawaited(_stopOutcomeAudio());
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
    unawaited(_audioService.playSafeZoneCue());

    if (!_stageRule.devilEnabled) {
      return;
    }
    _devilCell = null;
    _devilSpawned = false;
    _devilMoveAccumulator = 0;
    _stepsSinceSafeZone = 0;
    _awaitingDevilRespawnSteps = true;
    _devilProximityLoopStarted = false;
    unawaited(_audioService.stopDevilProximityLoop());
  }

  int _devilRespawnStepsForStage() {
    final t = ((_stage - 1) / (_maxStage - 1)).clamp(0.0, 1.0);
    final earlySteps = 5.0;
    final lateSteps = 2.0;
    final steps = earlySteps + (lateSteps - earlySteps) * t;
    return steps.round().clamp(2, 5);
  }

  void _trackPlayerSteps() {
    final current = _playerController.position;
    final previous = _lastPlayerCell;
    if (previous != null && current != previous) {
      _mazeShiftManager.onPlayerStep();
      if (_awaitingDevilRespawnSteps) {
        _stepsSinceSafeZone += 1;
      }
    }
    _lastPlayerCell = current;
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

    _rebuildPathMetrics();
    _mazeShiftManager.updateTotalSteps(_mazeShiftTotalSteps);
    _devilMoveAccumulator = 0;
    unawaited(_audioService.playGlitchScreenCue());
  }

  void _rebuildPathMetrics() {
    _distanceFromStart = _buildDistanceMap(_maze.start);
    _startToGoalDistance = _distanceFromStart[_maze.end] ?? 0;
  }

  Map<Point<int>, int> _buildDistanceMap(Point<int> source) {
    final distances = <Point<int>, int>{source: 0};
    final queue = <Point<int>>[source];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
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

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
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

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
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
    _remainingSeconds = _stageDurationSeconds;
    _lowTimeAlarmPlayed = false;
    unawaited(_audioService.stopLowTimeAlarmLoop());
    _startCountdown();
  }

  Future<void> _onTimeExpired() async {
    if (!mounted ||
        _isTimeUpHandling ||
        _isStageTransition ||
        _showLossOverlay) {
      return;
    }

    _isTimeUpHandling = true;
    _isPaused = false;
    unawaited(_audioService.stopLowTimeAlarmLoop());
    _playerController.stop();
    await _stopDangerAudio();
    await _stopOutcomeAudio();
    _devilProximityLoopStarted = false;
    await _audioService.playGameLostCue();
    setState(() {
      _showLossOverlay = true;
      _lostByTime = true;
    });
    _isTimeUpHandling = false;
  }

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
      widget.onExitToDashboard();
    }
  }

  void _togglePause() {
    final canToggle =
        !_isStageTransition &&
        !_isTimeUpHandling &&
        !_showLossOverlay &&
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
      _devilProximityLoopStarted = false;
      if (_remainingSeconds <= 10) {
        _lowTimeAlarmPlayed = false;
      }
      unawaited(_stopDangerAudio());
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

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _stageTimer?.cancel();
    _pulseController.dispose();
    _stageClearController.dispose();
    _playerController.dispose();
    unawaited(_audioService.stopAll());
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
    final topButtonSize = (42 * uiScale).clamp(38.0, 52.0);
    final topButtonIconSize = (20 * uiScale).clamp(18.0, 24.0);
    final hudTopGap = (topButtonSize + (8 * uiScale).clamp(6.0, 14.0))
        .toDouble();
    final hudLabelFont = (10 * uiScale).clamp(9.0, 12.0);
    final hudValueFont = (13 * uiScale).clamp(11.0, 15.0);
    final timerFont = (13 * uiScale).clamp(11.0, 15.0);
    final mazeFramePadding = (6 * uiScale).clamp(4.0, 10.0);
    final stageClearTextSize = (42 * uiScale).clamp(26.0, 50.0);

    final stageClearSlide =
        Tween<Offset>(
          begin: const Offset(0, 1.25),
          end: const Offset(0, -0.15),
        ).animate(
          CurvedAnimation(
            parent: _stageClearController,
            curve: Curves.easeOutCubic,
          ),
        );
    final stageClearOpacity = CurvedAnimation(
      parent: _stageClearController,
      curve: const Interval(0.08, 0.6, curve: Curves.easeOut),
    );

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
                  SizedBox(height: hudTopGap),
                  Container(
                    decoration: BoxDecoration(
                      color: AppPalette.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppPalette.borderSoft),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.fromLTRB(
                      (10 * uiScale).clamp(8.0, 14.0),
                      (10 * uiScale).clamp(8.0, 14.0),
                      (10 * uiScale).clamp(8.0, 14.0),
                      (10 * uiScale).clamp(8.0, 14.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: (42 * uiScale).clamp(38.0, 48.0),
                              padding: EdgeInsets.symmetric(
                                horizontal: (12 * uiScale).clamp(9.0, 14.0),
                              ),
                              decoration: BoxDecoration(
                                color: _isPanic
                                    ? const Color(0xFFFF8A80)
                                    : AppPalette.neonGreen,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    color: Colors.black,
                                    size: (16 * uiScale).clamp(14.0, 18.0),
                                  ),
                                  SizedBox(
                                    width: (6 * uiScale).clamp(4.0, 8.0),
                                  ),
                                  Text(
                                    _timeLabel,
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: timerFont,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: (8 * uiScale).clamp(6.0, 12.0)),
                        Wrap(
                          spacing: (8 * uiScale).clamp(6.0, 12.0),
                          runSpacing: (8 * uiScale).clamp(6.0, 12.0),
                          children: [
                            _GameHudBadge(
                              label: 'STAGE',
                              value: '$_stage',
                              color: AppPalette.accentPink,
                              labelFontSize: hudLabelFont,
                              valueFontSize: hudValueFont,
                            ),
                            _GameHudBadge(
                              label: 'MODE',
                              value: _modeLabel,
                              color: _controlsInverted
                                  ? AppPalette.danger
                                  : AppPalette.neonGreen,
                              labelFontSize: hudLabelFont,
                              valueFontSize: hudValueFont,
                            ),
                            _GameHudBadge(
                              label: 'CHECKPOINT',
                              value: '$_checkpoint',
                              color: AppPalette.accentPurple,
                              labelFontSize: hudLabelFont,
                              valueFontSize: hudValueFont,
                            ),
                            _GameHudBadge(
                              label: 'STATE',
                              value: _playerSafe ? 'SAFE' : 'EXPOSED',
                              color: _playerSafe
                                  ? const Color(0xFF5EDB87)
                                  : const Color(0xFFFFA39A),
                              labelFontSize: hudLabelFont,
                              valueFontSize: hudValueFont,
                            ),
                            _GameHudBadge(
                              label: 'FLIP',
                              value: _flipWarningActive
                                  ? '${_flipWarningTimeLeft.toStringAsFixed(1)}s'
                                  : 'STABLE',
                              color: _flipWarningActive
                                  ? AppPalette.danger
                                  : const Color(0xFFB4F76B),
                              labelFontSize: hudLabelFont,
                              valueFontSize: hudValueFont,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: (10 * uiScale).clamp(8.0, 14.0)),
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
                                        _isPaused)
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
                                        _isPaused)
                                    ? () {}
                                    : _playerController.stop,
                              )
                            : _Joystick(
                                size: widget.joystickSize,
                                onDirection:
                                    (_isStageTransition ||
                                        _isExternallyInactive ||
                                        _isPaused)
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
                                        _isPaused)
                                    ? () {}
                                    : _playerController.stop,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.only(top: (2 * uiScale).clamp(1.0, 4.0)),
                  child: _ArcadeTrophyBadge(
                    trophies: widget.totalTrophies,
                    scale: uiScale,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(top: (2 * uiScale).clamp(1.0, 4.0)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: topButtonSize,
                        height: topButtonSize,
                        child: FilledButton(
                          onPressed: _togglePause,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppPalette.surfaceAlt,
                            foregroundColor: AppPalette.neonGreen,
                            side: BorderSide(
                              color: AppPalette.neonGreen.withAlpha(170),
                            ),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Icon(
                            _isPaused ? Icons.play_arrow : Icons.pause,
                            size: topButtonIconSize,
                          ),
                        ),
                      ),
                      SizedBox(width: (8 * uiScale).clamp(6.0, 12.0)),
                      SizedBox(
                        width: topButtonSize,
                        height: topButtonSize,
                        child: FilledButton(
                          onPressed: _onExitPressed,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppPalette.surfaceAlt,
                            foregroundColor: AppPalette.danger,
                            side: BorderSide(
                              color: AppPalette.danger.withAlpha(170),
                            ),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Icon(Icons.close, size: topButtonIconSize),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isPaused)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: false,
                    child: Container(
                      color: const Color(0xC0000000),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                18,
                                20,
                                18,
                              ),
                              decoration: BoxDecoration(
                                color: AppPalette.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppPalette.accentPurple.withAlpha(180),
                                  width: 1.3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x44000000),
                                    blurRadius: 18,
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
                                          borderRadius: BorderRadius.circular(
                                            11,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.pause_circle_filled_rounded,
                                          color: Colors.black,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'RUN PAUSED',
                                              style: TextStyle(
                                                color: AppPalette.textPrimary,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 20,
                                                letterSpacing: 0.9,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Take a breath. Your progress is safe.',
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
                                    'Ready for the next move?',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppPalette.neonGreen,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 22,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Stage $_stage  •  ${_timeLabel.replaceFirst('TIME: ', '')} remaining  •  ${_modeLabel.toLowerCase()} mode',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppPalette.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      12,
                                      10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppPalette.surfaceAlt,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppPalette.borderSoft,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            const Text(
                                              'CHECKPOINT STATUS',
                                              style: TextStyle(
                                                color: AppPalette.textPrimary,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 11,
                                                letterSpacing: 0.6,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              '$_checkpoint',
                                              style: const TextStyle(
                                                color: AppPalette.accentPink,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _checkpointPushText(),
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
                                  FilledButton.icon(
                                    onPressed: _togglePause,
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(50),
                                      backgroundColor: AppPalette.neonGreen,
                                      foregroundColor: Colors.black,
                                    ),
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: const Text(
                                      'RESUME RUN',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      unawaited(_onExitPressed());
                                    },
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(48),
                                      side: BorderSide(
                                        color: AppPalette.danger.withAlpha(170),
                                      ),
                                      foregroundColor: AppPalette.danger,
                                    ),
                                    icon: const Icon(Icons.exit_to_app_rounded),
                                    label: const Text(
                                      'EXIT THIS RUN',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_isStageTransition)
                IgnorePointer(
                  child: Center(
                    child: SlideTransition(
                      position: stageClearSlide,
                      child: FadeTransition(
                        opacity: stageClearOpacity,
                        child: Text(
                          'STAGE $_completedStage COMPLETED',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: stageClearTextSize,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.3,
                            shadows: const [
                              Shadow(
                                color: Color(0xC0000000),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
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
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  18,
                                  20,
                                  18,
                                ),
                                decoration: BoxDecoration(
                                  color: AppPalette.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: AppPalette.danger.withAlpha(175),
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: AppPalette.danger,
                                            borderRadius: BorderRadius.circular(
                                              11,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: const Icon(
                                            Icons.replay_circle_filled,
                                            color: Colors.black,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'RUN FAILED',
                                                style: TextStyle(
                                                  color: AppPalette.textPrimary,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 20,
                                                  letterSpacing: 0.9,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _lossReasonText(),
                                                style: const TextStyle(
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
                                    const SizedBox(height: 14),
                                    const Text(
                                      'Let\'s play one more.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppPalette.neonGreen,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 24,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _comebackHookText(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppPalette.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Container(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        10,
                                        12,
                                        10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppPalette.surfaceAlt,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppPalette.borderSoft,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            children: [
                                              const Text(
                                                'COMPLETION LINE',
                                                style: TextStyle(
                                                  color: AppPalette.textPrimary,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 11,
                                                  letterSpacing: 0.6,
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                '${_escapePercent()}%',
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
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            child: LinearProgressIndicator(
                                              value: (_escapePercent() / 100)
                                                  .clamp(0.0, 1.0),
                                              minHeight: 10,
                                              backgroundColor: const Color(
                                                0xFF252525,
                                              ),
                                              valueColor:
                                                  const AlwaysStoppedAnimation<
                                                    Color
                                                  >(AppPalette.accentPink),
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
                                    FilledButton.icon(
                                      onPressed: _adActionInProgress
                                          ? null
                                          : _onReviveFromLoss,
                                      icon: const Icon(Icons.flash_on_rounded),
                                      label: Text(
                                        _adActionInProgress
                                            ? 'LOADING AD...'
                                            : 'REVIVE NOW (AD)',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size.fromHeight(50),
                                        backgroundColor: AppPalette.neonGreen,
                                        foregroundColor: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    FilledButton.icon(
                                      onPressed: _adActionInProgress
                                          ? null
                                          : _onRestartFromLoss,
                                      icon: const Icon(
                                        Icons.restart_alt_rounded,
                                      ),
                                      label: Text(
                                        _adActionInProgress
                                            ? 'LOADING AD...'
                                            : 'RESTART FROM CHECKPOINT (AD)',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size.fromHeight(50),
                                        backgroundColor: AppPalette.accentPink,
                                        foregroundColor: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
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
    return _lostByTime
        ? 'Clock hit zero before extraction.'
        : 'Devil intercepted your route.';
  }

  String _comebackHookText() {
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

  void _restartCurrentStageFromStart() {
    _showLossOverlay = false;
    _lostByTime = false;
    _adActionInProgress = false;

    _playerController.resetForMaze(_maze);
    _applyStageRule(resetMaze: false);
    _restartCountdown();
    setState(() {});
  }

  void _resetToCheckpoint() {
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

    _playerController.resetForMaze(_maze);
    _applyStageRule(resetMaze: false);
    _restartCountdown();
    setState(() {});
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
        animation: Listenable.merge([_pulseController, _playerController]),
        builder: (context, _) {
          return CustomPaint(
            painter: MazePainter(
              maze: _maze,
              pathPoints: _playerController.pathPoints,
              playerCellPosition: _playerController.renderPosition,
              direction: _playerController.direction,
              currentFrame: _playerController.currentFrame,
              isMoving: _playerController.isMoving,
              pulse: _pulseController.value,
              playerSprite: _playerSprite,
              spriteFrameCount: _spriteColumns,
              spriteRows: _spriteRows,
              spriteRowIndex: widget.selectedCharacterIndex + 1,
              devilCell: _devilCell,
              devilSprite: _playerSprite,
              devilSpriteRowIndex: 0,
              safeZones: _safeZones.map((key, value) {
                return MapEntry(key, 1.0);
              }),
              playerSafe: _playerSafe,
              isFlippedMode: _controlsInverted,
            ),
          );
        },
      ),
    );
  }
}

class _ArcadeTrophyBadge extends StatelessWidget {
  const _ArcadeTrophyBadge({required this.trophies, required this.scale});

  final int trophies;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final safeTrophies = trophies < 0 ? 0 : trophies;
    final titleSize = (9 * scale).clamp(8.0, 11.0);
    final valueSize = (16 * scale).clamp(13.0, 20.0);
    final iconSize = (16 * scale).clamp(13.0, 19.0);

    return Container(
      padding: EdgeInsets.fromLTRB(
        (10 * scale).clamp(8.0, 12.0),
        (7 * scale).clamp(6.0, 9.0),
        (12 * scale).clamp(10.0, 14.0),
        (7 * scale).clamp(6.0, 9.0),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular((14 * scale).clamp(11.0, 18.0)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF24153D), Color(0xFF0C0A16)],
        ),
        border: Border.all(color: const Color(0xFF4DEFFF), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x884DEFFF),
            blurRadius: 16,
            spreadRadius: -2,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x552A8FFF),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: (26 * scale).clamp(20.0, 32.0),
            height: (26 * scale).clamp(20.0, 32.0),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFD86A), Color(0xFFFFA93D)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x88FFCB46),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.emoji_events_rounded,
              size: iconSize,
              color: const Color(0xFF3A2200),
            ),
          ),
          SizedBox(width: (8 * scale).clamp(6.0, 10.0)),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TROPHIES',
                style: TextStyle(
                  color: const Color(0xFF7FF8FF),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  fontSize: titleSize,
                ),
              ),
              Text(
                '$safeTrophies',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: valueSize,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GameHudBadge extends StatelessWidget {
  const _GameHudBadge({
    required this.label,
    required this.value,
    required this.color,
    required this.labelFontSize,
    required this.valueFontSize,
  });

  final String label;
  final String value;
  final Color color;
  final double labelFontSize;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    final darkText = color.computeLuminance() > 0.45;
    final foreground = darkText ? Colors.black : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: foreground.withAlpha(180),
              fontWeight: FontWeight.w900,
              letterSpacing: 0.45,
              fontSize: labelFontSize,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w900,
              fontSize: valueFontSize,
            ),
          ),
        ],
      ),
    );
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
