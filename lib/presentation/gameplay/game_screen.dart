import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_palette.dart';
import 'maze_generator.dart';
import 'maze_painter.dart';
import 'player_controller.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    required this.joystickSize,
    required this.selectedCharacterIndex,
    required this.onExitToDashboard,
    required this.onRestartWithAd,
    super.key,
  });

  final double joystickSize;
  final int selectedCharacterIndex;
  final VoidCallback onExitToDashboard;
  final Future<void> Function() onRestartWithAd;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
  with TickerProviderStateMixin {
  final MazeGenerator _generator = MazeGenerator();
  late PlayerController _playerController;
  late AnimationController _pulseController;
  late AnimationController _stageClearController;
  ui.Image? _playerSprite;
  // characters.png uses a 32x32 grid: 736x128 => 23 columns x 4 rows.
  static const int _spriteColumns = 23;
  static const int _spriteRows = 4;
  static const int _maxStage = 100;
  static const int _stageDurationSeconds = 120;

  int _difficulty = 10;
  int _stage = 1;
  int _remainingSeconds = _stageDurationSeconds;
  late MazeGrid _maze;
  bool _isRestarting = false;
  bool _isStageTransition = false;
  bool _isTimeUpHandling = false;
  int _completedStage = 1;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _maze = _generator.generate(rows: _difficulty, cols: _difficulty);
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

    _startCountdown();
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

    await _stageClearController.forward(from: 0);
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) {
      return;
    }

    setState(() {
      _stage = min(_stage + 1, _maxStage);
      _difficulty = _difficultyForStage(_stage);
      _maze = _generator.generate(rows: _difficulty, cols: _difficulty);
      _remainingSeconds = _stageDurationSeconds;
      _isStageTransition = false;
    });

    _playerController.resetForMaze(_maze);
    _restartCountdown();
  }

  String get _modeLabel {
    return _stage > 50 ? 'FLIPPED' : 'NORMAL';
  }

  Color get _modeColor {
    return _stage > 50 ? Colors.red : AppPalette.neonGreen;
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
    final normalized = stage.clamp(1, _maxStage);
    return min(10 + (normalized - 1), 22);
  }

  bool get _isPanic => _remainingSeconds <= 10;

  String get _timeLabel {
    if (_remainingSeconds == _stageDurationSeconds) {
      return 'TIME: 2 MINS';
    }
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

  void _restartCountdown() {
    _remainingSeconds = _stageDurationSeconds;
    _startCountdown();
  }

  Future<void> _onTimeExpired() async {
    if (!mounted || _isTimeUpHandling || _isStageTransition) {
      return;
    }

    _isTimeUpHandling = true;
    _playerController.stop();

    final checkpointStage = _checkpoint == 0 ? 1 : _checkpoint;
    final targetStage = checkpointStage.clamp(1, _maxStage);

    setState(() {
      _isStageTransition = true;
    });

    await Future.delayed(const Duration(milliseconds: 750));
    if (!mounted) {
      return;
    }

    setState(() {
      _stage = targetStage;
      _difficulty = _difficultyForStage(_stage);
      _maze = _generator.generate(rows: _difficulty, cols: _difficulty);
      _remainingSeconds = _stageDurationSeconds;
      _isStageTransition = false;
    });

    _playerController.resetForMaze(_maze);
    _restartCountdown();
    _isTimeUpHandling = false;
  }

  void _restartCurrentMaze() {
    _playerController.stop();
    _playerController.resetForMaze(_maze);
    setState(() {
      _remainingSeconds = _stageDurationSeconds;
    });
    _restartCountdown();
  }

  Future<void> _onRestartPressed() async {
    if (_isRestarting) {
      return;
    }

    setState(() {
      _isRestarting = true;
    });

    try {
      await widget.onRestartWithAd();
      if (!mounted) {
        return;
      }
      _restartCurrentMaze();
    } finally {
      if (mounted) {
        setState(() {
          _isRestarting = false;
        });
      }
    }
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
    final restartGap = (18 * uiScale).clamp(12.0, 24.0);
    final restartSize = (56 * uiScale).clamp(48.0, 66.0);
    final restartSpinnerSize = (18 * uiScale).clamp(16.0, 22.0);
    final topButtonSize = (42 * uiScale).clamp(38.0, 52.0);
    final topButtonIconSize = (20 * uiScale).clamp(18.0, 24.0);
    final statusBarTopGap =
      (topButtonSize + (8 * uiScale).clamp(6.0, 14.0)).toDouble();
    final statusBarHeight = (54 * uiScale).clamp(48.0, 64.0);
    final statusBarFont = (15 * uiScale).clamp(12.0, 17.0);
    final statusBarSmallFont = (12 * uiScale).clamp(10.0, 14.0);
    final timeChipTopGap = (8 * uiScale).clamp(6.0, 12.0);
    final timeChipHorizontalPadding = (14 * uiScale).clamp(10.0, 18.0);
    final timeChipVerticalPadding = (6 * uiScale).clamp(4.0, 8.0);
    final timeChipFontSize = (13 * uiScale).clamp(11.0, 15.0);
    final stageClearTextSize = (42 * uiScale).clamp(26.0, 50.0);

    final stageClearSlide = Tween<Offset>(
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

    return Container(
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
                          child: Text(
                            'STAGE $_stage',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: (statusBarSmallFont + 0.6),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: RichText(
                              text: TextSpan(
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
                                ],
                              ),
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
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: Listenable.merge([
                              _pulseController,
                              _playerController,
                            ]),
                            builder: (context, _) {
                              return CustomPaint(
                                painter: MazePainter(
                                  maze: _maze,
                                  pathPoints: _playerController.pathPoints,
                                  playerCellPosition:
                                      _playerController.renderPosition,
                                  direction: _playerController.direction,
                                  currentFrame: _playerController.currentFrame,
                                  isMoving: _playerController.isMoving,
                                  pulse: _pulseController.value,
                                  playerSprite: _playerSprite,
                                  spriteFrameCount: _spriteColumns,
                                  spriteRows: _spriteRows,
                                  spriteRowIndex: widget.selectedCharacterIndex,
                                ),
                              );
                            },
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
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Center(
                              child: _Joystick(
                                size: widget.joystickSize,
                                onDirection: _isStageTransition
                                    ? (_) {}
                                    : _playerController.holdDirection,
                                onEnd: _isStageTransition
                                    ? () {}
                                    : _playerController.stop,
                              ),
                            ),
                          ),
                          SizedBox(width: restartGap),
                          SizedBox(
                            width: restartSize,
                            height: restartSize,
                            child: FilledButton(
                              onPressed: _isRestarting || _isStageTransition
                                  ? null
                                  : _onRestartPressed,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppPalette.accentPink,
                                foregroundColor: Colors.black,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isRestarting
                                  ? SizedBox(
                                      width: restartSpinnerSize,
                                      height: restartSpinnerSize,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Icon(Icons.refresh),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(top: (2 * uiScale).clamp(1.0, 4.0)),
                  child: SizedBox(
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
            ],
          ),
        ),
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
