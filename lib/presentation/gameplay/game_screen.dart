import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_palette.dart';
import 'maze_generator.dart';
import 'maze_painter.dart';
import 'player_controller.dart';
import 'stage_rules.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    this.joystickSize = 110,
    this.useArrowController = false,
    this.selectedCharacterIndex = 0,
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

    _applyStageRule(resetMaze: false);
    _startCountdown();
    _startStageLoop();
    _loadCharactersSprite();
  }

  Future<void> _loadNextMaze() async {
    if (_isStageTransition) {
      return;
    }

    _playerController.stop();
    _countdownTimer?.cancel();

    setState(() {
      _isStageTransition = true;
      _completedStage = _stage;
    });

    try {
      await widget.onStageCleared(_stage);
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

  Color get _modeColor {
    return _controlsInverted ? Colors.red : AppPalette.neonGreen;
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
      if (_showLossOverlay || _isPaused) {
        return;
      }
      if (_remainingSeconds <= 0) {
        _countdownTimer?.cancel();
        return;
      }
      setState(() {
        _remainingSeconds -= 1;
      });

      if (_remainingSeconds <= 0) {
        _countdownTimer?.cancel();
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
        _isPaused) {
      return;
    }

    final dt = _stageTickSeconds;
    _stageElapsedSeconds += dt;

    final timeToFlip = _nextFlipAtSeconds - _stageElapsedSeconds;
    if (timeToFlip <= _stageRule.warningTime && timeToFlip > 0) {
      _flipWarningActive = true;
      _flipWarningTimeLeft = timeToFlip;
    }

    if (_stageElapsedSeconds >= _nextFlipAtSeconds) {
      _controlsInverted = !_controlsInverted;
      _playerController.setControlsInverted(_controlsInverted);
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

    if (_canSpawnDevilNow()) {
      _devilSpawned = true;
      _devilCell = _spawnDevilCell();
    }

    if (_devilSpawned && _devilCell != null) {
      _devilMoveAccumulator += dt;
      final stepInterval = 1.0 / _stageRule.devilStepsPerSecond.clamp(0.2, 3.0);
      while (_devilMoveAccumulator >= stepInterval) {
        _devilMoveAccumulator -= stepInterval;
        _devilCell = _nextDevilStep(_devilCell!, _playerController.position);
      }
      if (_devilCell == _playerController.position && !_playerSafe) {
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
    _playerController.stop();
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
    _resetSafeZones();
    _showLossOverlay = false;
    _adActionInProgress = false;
    _lostByTime = false;
    _isPaused = false;
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
    if (!_stageRule.devilEnabled) {
      return;
    }
    _devilCell = null;
    _devilSpawned = false;
    _devilMoveAccumulator = 0;
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

  void _trackPlayerSteps() {
    final current = _playerController.position;
    final previous = _lastPlayerCell;
    if (previous != null && current != previous && _awaitingDevilRespawnSteps) {
      _stepsSinceSafeZone += 1;
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
    _playerController.stop();
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
        return AlertDialog(
          backgroundColor: AppPalette.surface,
          title: const Text(
            'Exit Game?',
            style: TextStyle(
              color: AppPalette.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Do you want to exit this game and go back to dashboard?',
            style: TextStyle(color: AppPalette.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes, Exit'),
            ),
          ],
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
        !_adActionInProgress;
    if (!canToggle) {
      return;
    }

    setState(() {
      _isPaused = !_isPaused;
    });

    if (_isPaused) {
      _playerController.stop();
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
    final statusBarTopGap = (topButtonSize + (8 * uiScale).clamp(6.0, 14.0))
        .toDouble();
    final statusBarHeight = (54 * uiScale).clamp(48.0, 64.0);
    final statusBarFont = (15 * uiScale).clamp(12.0, 17.0);
    final statusBarSmallFont = (12 * uiScale).clamp(10.0, 14.0);
    final timeChipTopGap = (8 * uiScale).clamp(6.0, 12.0);
    final timeChipHorizontalPadding = (14 * uiScale).clamp(10.0, 18.0);
    final timeChipVerticalPadding = (6 * uiScale).clamp(4.0, 8.0);
    final timeChipFontSize = (13 * uiScale).clamp(11.0, 15.0);
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
                  SizedBox(height: statusBarTopGap),
                  Container(
                    height: statusBarHeight,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFFFFF), Color(0xFFF0F0F0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black, width: 1.8),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: (12 * uiScale).clamp(10.0, 16.0),
                      vertical: (6 * uiScale).clamp(4.0, 8.0),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: (10 * uiScale).clamp(8.0, 12.0),
                            vertical: (6 * uiScale).clamp(4.0, 7.0),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _stage,
                              dropdownColor: const Color(0xFF101010),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: (statusBarSmallFont + 0.6),
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                              selectedItemBuilder: (context) {
                                return List<Widget>.generate(_maxStage, (
                                  index,
                                ) {
                                  final stageNumber = index + 1;
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text('STAGE $stageNumber'),
                                  );
                                });
                              },
                              items: List<DropdownMenuItem<int>>.generate(
                                _maxStage,
                                (index) {
                                  final stageNumber = index + 1;
                                  return DropdownMenuItem<int>(
                                    value: stageNumber,
                                    child: Text('STAGE $stageNumber'),
                                  );
                                },
                              ),
                              onChanged:
                                  (_isStageTransition ||
                                      _isTimeUpHandling ||
                                      _isPaused ||
                                      _showLossOverlay ||
                                      _adActionInProgress)
                                  ? null
                                  : (value) {
                                      if (value == null || value == _stage) {
                                        return;
                                      }
                                      unawaited(_jumpToStage(value));
                                    },
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: statusBarFont,
                                  fontWeight: FontWeight.w800,
                                ),
                                children: [
                                  TextSpan(
                                    text: _modeLabel,
                                    style: TextStyle(color: _modeColor),
                                  ),
                                  const TextSpan(text: '   |   '),
                                  TextSpan(text: 'CHECKPOINT $_checkpoint'),
                                  const TextSpan(text: '   |   '),
                                  TextSpan(
                                    text: _playerSafe ? 'SAFE' : 'EXPOSED',
                                    style: TextStyle(
                                      color: _playerSafe
                                          ? const Color(0xFF00AA55)
                                          : Colors.black,
                                    ),
                                  ),
                                  const TextSpan(text: '   |   '),
                                  TextSpan(
                                    text: _flipWarningActive
                                        ? 'FLIP ${_flipWarningTimeLeft.toStringAsFixed(1)}s'
                                        : 'STABLE',
                                    style: TextStyle(
                                      color: _flipWarningActive
                                          ? Colors.red
                                          : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: timeChipTopGap),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: timeChipHorizontalPadding,
                        vertical: timeChipVerticalPadding,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isPanic ? Colors.red : Colors.white,
                          width: 1.3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _isPanic
                                ? const Color(0x66FF0000)
                                : const Color(0x33000000),
                            blurRadius: _isPanic ? 14 : 8,
                            spreadRadius: _isPanic ? 1 : 0,
                          ),
                        ],
                      ),
                      child: Text(
                        _timeLabel,
                        style: TextStyle(
                          color: _isPanic ? Colors.red : Colors.white,
                          fontSize: timeChipFontSize,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: (10 * uiScale).clamp(8.0, 14.0)),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _buildGameSurface(),
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
                                onDirection: (_isStageTransition || _isPaused)
                                    ? (_) {}
                                    : (direction) {
                                        final effective = _controlsInverted
                                            ? _invertDirection(direction)
                                            : direction;
                                        _playerController.holdDirection(
                                          effective,
                                        );
                                      },
                                onEnd: (_isStageTransition || _isPaused)
                                    ? () {}
                                    : _playerController.stop,
                              )
                            : _Joystick(
                                size: widget.joystickSize,
                                onDirection: (_isStageTransition || _isPaused)
                                    ? (_) {}
                                    : (direction) {
                                        final effective = _controlsInverted
                                            ? _invertDirection(direction)
                                            : direction;
                                        _playerController.holdDirection(
                                          effective,
                                        );
                                      },
                                onEnd: (_isStageTransition || _isPaused)
                                    ? () {}
                                    : _playerController.stop,
                              ),
                      ),
                    ),
                  ),
                ],
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
                            backgroundColor: AppPalette.neonGreen,
                            foregroundColor: Colors.black,
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
                            backgroundColor: AppPalette.accentPurple,
                            foregroundColor: Colors.black,
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
                      color: const Color(0x8F000000),
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 360),
                          margin: const EdgeInsets.symmetric(horizontal: 18),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141414),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF2A2A2A)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'PAUSED',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 24,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 14),
                              FilledButton(
                                onPressed: _togglePause,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppPalette.neonGreen,
                                  foregroundColor: Colors.black,
                                ),
                                child: const Text(
                                  'RESUME',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
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
                      color: const Color(0xC8000000),
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 420),
                          margin: const EdgeInsets.symmetric(horizontal: 18),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141414),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF2A2A2A)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _lostByTime ? 'TIME UP' : 'CAUGHT BY DEVIL',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFFF5252),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 24,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'You escaped ${_escapePercent()}%',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _adActionInProgress
                                    ? null
                                    : _onRestartFromLoss,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppPalette.accentPink,
                                  foregroundColor: Colors.black,
                                ),
                                child: Text(
                                  _adActionInProgress
                                      ? 'LOADING AD...'
                                      : 'RESTART (AD)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              FilledButton(
                                onPressed: _adActionInProgress
                                    ? null
                                    : _onReviveFromLoss,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppPalette.neonGreen,
                                  foregroundColor: Colors.black,
                                ),
                                child: const Text(
                                  'REVIVE (AD)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
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
            ],
          ),
        ),
      ),
    );
  }

  int _escapePercent() {
    return ((_stage.clamp(1, _maxStage) / _maxStage) * 100).round();
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
      _showLossOverlay = false;
      _adActionInProgress = false;
      if (_lostByTime) {
        _remainingSeconds = max(20, _stageDurationSeconds ~/ 6);
      }
      _lostByTime = false;
      if (_stageRule.devilEnabled &&
          _pathClearanceProgress() >= _devilMinPathClearance) {
        _devilSpawned = true;
        _devilCell = _spawnDevilCell();
        _awaitingDevilRespawnSteps = false;
        _stepsSinceSafeZone = 0;
      } else {
        _devilSpawned = false;
        _devilCell = null;
        _awaitingDevilRespawnSteps = true;
        _stepsSinceSafeZone = 0;
      }
      _playerSafe = true;
      _lastPlayerCell = _playerController.position;
      setState(() {});
      return;
    }
    setState(() {
      _adActionInProgress = false;
    });
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
            color: const Color(0xAA0F0F0F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x88FFFFFF), width: 1.3),
          ),
          child: Icon(icon, color: Colors.white, size: size * 0.68),
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
            border: Border.all(color: const Color(0xAAFFFFFF), width: 3),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0x44FFFFFF),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Transform.translate(
                  offset: _knobOffset,
                  child: const Center(
                    child: Icon(
                      Icons.circle,
                      color: Color(0xFFFF3B3B),
                      size: 36,
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
