import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../services/ads_service_base.dart';
import '../services/audio_manager.dart';
import '../services/error_reporter.dart';
import '../services/game_audio_event.dart';
import '../services/leaderboard_service.dart';
import '../domain/procedural/level_config.dart';
import '../domain/procedural/procedural_modules.dart';
import '../services/procedural/breathing_system_impl.dart';
import '../services/procedural/chaos_system_impl.dart';
import '../services/procedural/difficulty_engine_impl.dart';
import '../services/procedural/game_config_adapter.dart';
import '../services/procedural/level_validator_impl.dart';
import '../services/procedural/procedural_generation_service.dart';
import '../services/procedural/procedural_level_generator_impl.dart';
import 'character.dart';
import 'devil.dart';
import 'flip_system.dart';
import 'game_config.dart';
import 'maze.dart';
import 'player.dart';
import 'safe_zone.dart';
import 'shadow_clone.dart';

enum FearFlipMode { normal, memory }

enum RoundResult { playing, won, lost }

class HudState {
  const HudState({
    required this.level,
    required this.secondsAlive,
    required this.secondsUntilFlip,
    required this.warningActive,
    required this.controlsInverted,
    required this.mode,
    required this.roundResult,
    required this.canRevive,
    required this.memoryHidden,
    required this.mazeShiftActive,
  });

  final int level;
  final int secondsAlive;
  final double secondsUntilFlip;
  final bool warningActive;
  final bool controlsInverted;
  final FearFlipMode mode;
  final RoundResult roundResult;
  final bool canRevive;
  final bool memoryHidden;
  final bool mazeShiftActive;

  HudState copyWith({
    int? level,
    int? secondsAlive,
    double? secondsUntilFlip,
    bool? warningActive,
    bool? controlsInverted,
    FearFlipMode? mode,
    RoundResult? roundResult,
    bool? canRevive,
    bool? memoryHidden,
    bool? mazeShiftActive,
  }) {
    return HudState(
      level: level ?? this.level,
      secondsAlive: secondsAlive ?? this.secondsAlive,
      secondsUntilFlip: secondsUntilFlip ?? this.secondsUntilFlip,
      warningActive: warningActive ?? this.warningActive,
      controlsInverted: controlsInverted ?? this.controlsInverted,
      mode: mode ?? this.mode,
      roundResult: roundResult ?? this.roundResult,
      canRevive: canRevive ?? this.canRevive,
      memoryHidden: memoryHidden ?? this.memoryHidden,
      mazeShiftActive: mazeShiftActive ?? this.mazeShiftActive,
    );
  }
}

class FearFlipGame extends FlameGame {
  FearFlipGame({
    required this.adsService,
    required this.audioManager,
    required this.leaderboardService,
  });

  final AdsServiceBase adsService;
  final AudioManager audioManager;
  final LeaderboardService leaderboardService;

  final Random _random = Random();
  final DifficultyEngine _difficultyEngine = DifficultyEngineImpl();
  final ChaosSystem _chaosSystem = ChaosSystemImpl();
  final BreathingSystem _breathingSystem = BreathingSystemImpl();
  late final ProceduralLevelGenerator _levelGenerator =
      ProceduralLevelGeneratorImpl(
        difficultyEngine: _difficultyEngine,
        chaosSystem: _chaosSystem,
        breathingSystem: _breathingSystem,
      );
  late final ProceduralGenerationService _generationService =
      ProceduralGenerationService(
        generator: _levelGenerator,
        validator: LevelValidatorImpl(),
      );
  final GameConfigAdapter _configAdapter = GameConfigAdapter();

  RuntimeBalanceConfig _runtimeConfig = RuntimeBalanceConfig.defaults();
  LevelConfig? _activeLevelConfig;
  final ProgressionMode _progressionMode = ProgressionMode.levelBased;
  int _levelIndex = 0;
  double _difficulty = 0;
  int _nextBreathingEventIndex = 0;
  final ValueNotifier<HudState> hud = ValueNotifier<HudState>(
    const HudState(
      level: 1,
      secondsAlive: 0,
      secondsUntilFlip: GameBalanceConfig.flipInterval,
      warningActive: false,
      controlsInverted: false,
      mode: FearFlipMode.normal,
      roundResult: RoundResult.playing,
      canRevive: true,
      memoryHidden: false,
      mazeShiftActive: false,
    ),
  );

  late MazeData _maze;
  late MazeComponent _mazeComponent;
  late PlayerComponent _player;
  late RealityFlipSystem _flipSystem;
  FearFlipCharacter _selectedCharacter = FearFlipCharacter.catalog.first;

  /// One 7-frame walk set per distinct on-disk frame set, keyed by frame-set
  /// name (devil / sentinel / void_ripper / phantom). Loaded once in onLoad.
  final Map<String, CharacterSpriteSet> _spriteSets =
      <String, CharacterSpriteSet>{};

  DevilComponent? _devil;
  ShadowCloneComponent? _shadowClone;
  final List<SafeZoneComponent> _safeZones = <SafeZoneComponent>[];

  FearFlipMode _mode = FearFlipMode.normal;
  bool _isRunningRound = false;
  bool _warningActive = false;
  bool _memoryHidden = false;
  bool _wasInSafeZone = false;

  double _roundElapsed = 0;
  double _warningCountdown = 0;
  double _memoryPreviewLeft = 0;

  double _glitchLeft = 0;
  double _shakeLeft = 0;
  double _goalHintLeft = 0;
  int _audioFrameId = 0;

  Vector2 _inputDirection = Vector2.zero();

  List<FearFlipCharacter> get availableCharacters => FearFlipCharacter.catalog;
  FearFlipCharacter get selectedCharacter => _selectedCharacter;

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      for (final frameSet in CharacterSpriteSet.frameSetForId.values.toSet()) {
        _spriteSets[frameSet] = await CharacterSpriteSet.load(images, frameSet);
      }
    } catch (error, stackTrace) {
      ErrorReporter.report(
        reason: 'game_character_frames_load_failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
    camera.viewfinder.anchor = Anchor.center;
    _configureCameraForViewport();
    overlays.add('menu');
    await adsService.preload();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _configureCameraForViewport();
  }

  void _configureCameraForViewport() {
    final expandedRows = _runtimeConfig.logicalMazeRows * 2 + 1;
    final expandedCols = _runtimeConfig.logicalMazeCols * 2 + 1;
    final mazeSize = Vector2(
      expandedCols * GameBalanceConfig.tileSize,
      expandedRows * GameBalanceConfig.tileSize,
    );
    camera.viewfinder.position = Vector2(mazeSize.x / 2, mazeSize.y / 2);

    if (size.x <= 0 || size.y <= 0) {
      return;
    }

    final safeWidth = max(
      1.0,
      size.x - (GameBalanceConfig.viewportScreenPadding * 2),
    );
    final safeHeight = max(
      1.0,
      size.y - (GameBalanceConfig.viewportScreenPadding * 2),
    );

    final zoomX = safeWidth / mazeSize.x;
    final zoomY = safeHeight / mazeSize.y;
    final fitZoom = min(zoomX, zoomY);
    final zoom = fitZoom.clamp(0.01, GameBalanceConfig.maxCameraZoom);
    camera.viewfinder.zoom = zoom;
  }

  Future<void> startNewGame(
    FearFlipMode mode, {
    FearFlipCharacter? character,
  }) async {
    await audioManager.handle(GameAudioEvent.matchStart);

    _selectedCharacter = character ?? _selectedCharacter;
    _mode = mode;
    _isRunningRound = true;
    _wasInSafeZone = false;
    _warningActive = false;
    _memoryHidden = false;
    _roundElapsed = 0;
    _warningCountdown = 0;
    _memoryPreviewLeft = mode == FearFlipMode.memory
        ? GameBalanceConfig.memoryPreviewSeconds
        : 0;
    _glitchLeft = 0;
    _shakeLeft = 0;
    _goalHintLeft = GameBalanceConfig.alwaysShowGoalHint ? double.infinity : 4;
    _nextBreathingEventIndex = 0;
    _audioFrameId = 0;

    _difficulty = _progressionMode == ProgressionMode.levelBased
        ? _difficultyEngine.nextLevelBasedDifficulty(levelIndex: _levelIndex)
        : _difficultyEngine.timeBasedDifficulty(
            timeSurvivedSeconds: _roundElapsed,
            maxTimeSeconds: 240,
          );

    final generationSeed = DateTime.now().millisecondsSinceEpoch;
    final previewConfig = _levelGenerator.generate(
      difficulty: _difficulty,
      seed: generationSeed,
    );
    _runtimeConfig = _configAdapter.toRuntime(previewConfig);

    removeAll(children.toList(growable: false));

    _maze = MazeData.generate(
      logicalRows: _runtimeConfig.logicalMazeRows,
      logicalCols: _runtimeConfig.logicalMazeCols,
      seed: generationSeed,
    );

    _activeLevelConfig = _generationService.generateValidated(
      difficulty: _difficulty,
      maze: _maze,
      seed: generationSeed,
    );
    _runtimeConfig = _configAdapter.toRuntime(_activeLevelConfig!);

    _maze = MazeData.generate(
      logicalRows: _runtimeConfig.logicalMazeRows,
      logicalCols: _runtimeConfig.logicalMazeCols,
      seed: generationSeed,
    );

    _configureCameraForViewport();

    _mazeComponent = MazeComponent(maze: _maze);
    _mazeComponent.showGoalHint = true;
    _mazeComponent.devilPresent = false;
    add(_mazeComponent);

    _player = PlayerComponent(
      maze: _maze,
      config: _runtimeConfig,
      spriteSet: _setForCharacter(_selectedCharacter),
    )..position = _maze.cellCenter(_maze.startCell);
    add(_player);

    _safeZones
      ..clear()
      ..addAll(
        _maze.safeZones.map((cell) {
          return SafeZoneComponent(
            initialProtection: _runtimeConfig.safeZoneProtectionSeconds,
            tileSize: GameBalanceConfig.tileSize,
          )..position = _maze.cellCenter(cell);
        }),
      );
    addAll(_safeZones);

    _flipSystem = RealityFlipSystem(
      flipInterval: _runtimeConfig.flipInterval,
      warningDuration: _runtimeConfig.flipWarningDuration,
      flipRandomness: _runtimeConfig.flipRandomness,
      random: Random(generationSeed),
      onWarning: (secondsLeft) {
        _warningActive = true;
        _warningCountdown = secondsLeft;
        _shakeLeft = _runtimeConfig.preFlipShakeDuration;
      },
      onFlip: _triggerFlip,
    );
    add(_flipSystem);

    _devil = null;
    _shadowClone = null;

    overlays.remove('menu');
    overlays.remove('gameOver');
    overlays.remove('win');
    overlays.add('hud');

    _updateHud();
  }

  Future<void> restartRound() async {
    await startNewGame(_mode);
  }

  Sprite? spriteForCharacter(FearFlipCharacter character) {
    return _spriteForCharacter(character);
  }

  CharacterSpriteSet? _setForCharacter(FearFlipCharacter character) {
    return _spriteSets[CharacterSpriteSet.frameSetFor(character.id)];
  }

  Sprite? _spriteForCharacter(FearFlipCharacter character) {
    final set = _setForCharacter(character);
    if (set == null || set.frames.isEmpty) {
      return null;
    }
    return set.frameAt(0);
  }

  void setInputDirection(Vector2 direction) {
    _inputDirection = direction;
  }

  Future<void> _triggerFlip() async {
    if (!_isRunningRound) {
      return;
    }

    _warningActive = false;
    _warningCountdown = 0;
    _player.controlsInverted = !_player.controlsInverted;
    _mazeComponent.isInverted = _player.controlsInverted;

    _glitchLeft = _runtimeConfig.glitchDuration;
    _shakeLeft = max(_shakeLeft, 0.25);

    if (_devil == null) {
      final spawn = _devilSpawnBehindPlayer();
      final devil = DevilComponent(
        maze: _maze,
        config: _runtimeConfig,
        targetProvider: () => _player.position,
        blockedCellsProvider: _blockedCellsFromSafeZones,
        // The enemy always wears the horned devil frame set.
        spriteSet: _spriteSets[CharacterSpriteSet.defaultFrameSet],
      )..position = spawn;
      _devil = devil;
      add(devil);
      _mazeComponent.devilPresent = true;
    }

    final hasClone =
        _activeLevelConfig?.chaosEvents.contains(ChaosEventType.clone) ?? false;
    if (hasClone && _shadowClone == null) {
      final mirrored = Vector2(
        _mazeComponent.size.x - _player.position.x,
        _mazeComponent.size.y - _player.position.y,
      );
      final clone = ShadowCloneComponent(
        maze: _maze,
        config: _runtimeConfig,
        spawnAt: mirrored,
        random: _random,
        sprite: _spriteSets['phantom']?.frameAt(0),
      );
      _shadowClone = clone;
      add(clone);
    }

    final hasMazeShift =
        _activeLevelConfig?.chaosEvents.contains(ChaosEventType.mazeShift) ??
        false;
    if (hasMazeShift && !GameBalanceConfig.alwaysShowGoalHint) {
      _goalHintLeft = 0;
    }

    await audioManager.handle(
      GameAudioEvent.flipTriggered,
      frameId: _audioFrameId,
    );
    _updateHud();
  }

  Vector2 _devilSpawnBehindPlayer() {
    final tile = GameBalanceConfig.tileSize;
    final startWorld = _maze.cellCenter(_maze.startCell);
    final toStart = startWorld - _player.position;

    Vector2 backDir;
    if (_inputDirection.length2 > 0) {
      backDir = _inputDirection.normalized()..scale(-1);
    } else if (toStart.length2 > 0) {
      backDir = toStart.normalized();
    } else {
      backDir = Vector2(0, -1);
    }

    final perp = Vector2(-backDir.y, backDir.x);
    final progressTiles = (_player.position.distanceTo(startWorld) / tile)
        .clamp(0.0, 14.0);
    final minTiles = 3;
    final maxTiles = max(minTiles + 1, (progressTiles + 5).round());

    final blocked = _blockedCellsFromSafeZones();

    for (var i = 0; i < 28; i++) {
      final distanceTiles =
          minTiles + _random.nextDouble() * (maxTiles - minTiles);
      final lateralJitter = (_random.nextDouble() - 0.5) * tile * 2.2;

      final candidate =
          _player.position +
          backDir * (distanceTiles * tile) +
          perp * lateralJitter;
      final cell = _maze.worldToCell(candidate);

      if (!_maze.isWalkable(cell) || blocked.contains(cell)) {
        continue;
      }

      final world = _maze.cellCenter(cell);
      if (world.distanceTo(_player.position) < tile * 2.2) {
        continue;
      }

      return world;
    }

    // Fallback toward the start side if no valid random candidate is found.
    final startCellWorld = _maze.cellCenter(_maze.startCell);
    if (startCellWorld.distanceTo(_player.position) >= tile * 2) {
      return startCellWorld;
    }
    return _maze.cellCenter(_maze.goalCell);
  }

  Set<Point<int>> _blockedCellsFromSafeZones() {
    final blocked = <Point<int>>{};
    for (final zone in _safeZones) {
      if (!zone.isActive) {
        continue;
      }
      final c = _maze.worldToCell(zone.position);
      blocked.add(c);
      blocked.add(Point<int>(c.x + 1, c.y));
      blocked.add(Point<int>(c.x - 1, c.y));
      blocked.add(Point<int>(c.x, c.y + 1));
      blocked.add(Point<int>(c.x, c.y - 1));
    }
    return blocked.where(_maze.isInBounds).toSet();
  }

  @override
  void update(double dt) {
    _audioFrameId += 1;
    super.update(dt);

    if (!_isRunningRound) {
      return;
    }

    _player.setInput(_inputDirection);

    _roundElapsed += dt;

    if (_warningActive) {
      _warningCountdown = max(0, _warningCountdown - dt);
      if (_warningCountdown <= 0) {
        _warningActive = false;
      }
    }

    if (_mode == FearFlipMode.memory && !_memoryHidden) {
      _memoryPreviewLeft -= dt;
      if (_memoryPreviewLeft <= 0) {
        _memoryHidden = true;
        _mazeComponent.isMemoryHidden = true;
      }
    }

    _glitchLeft = max(0, _glitchLeft - dt);
    _shakeLeft = max(0, _shakeLeft - dt);
    if (!GameBalanceConfig.alwaysShowGoalHint) {
      _goalHintLeft = max(0, _goalHintLeft - dt);
    }
    _mazeComponent.showGoalHint =
        GameBalanceConfig.alwaysShowGoalHint || _goalHintLeft > 0;

    _processBreathingEvents();

    bool inSafeZone = false;
    for (final zone in _safeZones) {
      final inside = zone.containsPoint(_player.position);
      inSafeZone = inSafeZone || (inside && zone.isActive);
      zone.consume(dt, inside);
    }

    if (inSafeZone && !_wasInSafeZone) {
      unawaited(audioManager.handle(GameAudioEvent.safeZoneEntered));
    } else if (!inSafeZone && _wasInSafeZone) {
      unawaited(audioManager.handle(GameAudioEvent.safeZoneExited));
    }
    _wasInSafeZone = inSafeZone;

    if (_devil != null) {
      final devilCell = _maze.worldToCell(_devil!.position);
      final playerCell = _maze.worldToCell(_player.position);
      final distanceTiles =
          _maze.shortestPathDistance(devilCell, playerCell) ?? 99;
      final devilAudioEnabled = distanceTiles <= 6;
      unawaited(
        audioManager.handle(
          GameAudioEvent.devilDistanceChanged,
          devilDistanceTiles: distanceTiles,
          devilEnabled: devilAudioEnabled,
          safeZoneImmune: inSafeZone,
        ),
      );
    } else {
      unawaited(
        audioManager.handle(
          GameAudioEvent.devilDistanceChanged,
          devilDistanceTiles: 99,
          devilEnabled: false,
          safeZoneImmune: inSafeZone,
        ),
      );
    }

    final goalReached =
        _player.position.distanceTo(_maze.cellCenter(_maze.goalCell)) <
        GameBalanceConfig.tileSize * 0.35;
    if (goalReached) {
      _finishRound(won: true);
      return;
    }

    if (!inSafeZone && _devil != null) {
      final caught =
          _devil!.position.distanceTo(_player.position) <
          (_runtimeConfig.devilRadius + _runtimeConfig.playerRadius - 1);
      if (caught) {
        _finishRound(won: false);
        return;
      }
    }

    _updateHud();
  }

  Future<void> _finishRound({required bool won}) async {
    if (!_isRunningRound) {
      return;
    }

    _isRunningRound = false;
    _inputDirection = Vector2.zero();
    _wasInSafeZone = false;
    await audioManager.handle(
      GameAudioEvent.devilDistanceChanged,
      devilDistanceTiles: 99,
      devilEnabled: false,
      safeZoneImmune: false,
    );

    if (won) {
      await audioManager.handle(GameAudioEvent.playerWon);
      _levelIndex++;
      overlays.remove('hud');
      overlays.add('win');
      await leaderboardService.submitRun(
        scoreSeconds: _roundElapsed.floor(),
        mode: _mode.name,
      );
    } else {
      await audioManager.handle(GameAudioEvent.playerLost);
      overlays.remove('hud');
      overlays.add('gameOver');
      await adsService.showInterstitialAfterGameOver();
    }

    _updateHud(roundResult: won ? RoundResult.won : RoundResult.lost);
  }

  Future<void> tryRevive() async {
    if (hud.value.roundResult != RoundResult.lost || !hud.value.canRevive) {
      return;
    }

    final rewarded = await adsService.showRewardedForRevive();
    if (!rewarded) {
      return;
    }

    overlays.remove('gameOver');
    overlays.add('hud');

    _isRunningRound = true;
    _roundElapsed = max(0, _roundElapsed - 2);

    _player.position = _maze.cellCenter(_maze.startCell);
    _player.controlsInverted = false;
    _mazeComponent.isInverted = false;

    _devil?.position = _maze.cellCenter(_maze.goalCell);
    _devil?.resetChase();
    _mazeComponent.devilPresent = _devil != null;

    await audioManager.handle(GameAudioEvent.matchRestart);
    _updateHud(roundResult: RoundResult.playing, canRevive: false);
  }

  void _updateHud({RoundResult? roundResult, bool? canRevive}) {
    final mazeShiftActive =
        _activeLevelConfig?.chaosEvents.contains(ChaosEventType.mazeShift) ??
        false;
    hud.value = hud.value.copyWith(
      level: _levelIndex + 1,
      secondsAlive: _roundElapsed.floor(),
      secondsUntilFlip: _flipSystem.secondsUntilFlip,
      warningActive: _warningActive,
      controlsInverted: _player.controlsInverted,
      mode: _mode,
      roundResult:
          roundResult ??
          (_isRunningRound ? RoundResult.playing : hud.value.roundResult),
      canRevive: canRevive ?? hud.value.canRevive,
      memoryHidden: _memoryHidden,
      mazeShiftActive: mazeShiftActive,
    );
  }

  void _processBreathingEvents() {
    final level = _activeLevelConfig;
    if (level == null ||
        _nextBreathingEventIndex >= level.breathingPattern.length) {
      return;
    }

    final nextEvent = level.breathingPattern[_nextBreathingEventIndex];
    if (_roundElapsed < nextEvent.timeSeconds) {
      return;
    }

    switch (nextEvent.type) {
      case BreathingEventType.clearCorridor:
        _goalHintLeft = max(_goalHintLeft, 2.0);
        break;
      case BreathingEventType.noFlipWindow:
        _flipSystem.reset();
        _warningActive = false;
        _warningCountdown = 0;
        break;
      case BreathingEventType.slightSlowdown:
        _devil?.applySlowdown(secondsReduction: 1.2);
        break;
    }
    _nextBreathingEventIndex++;
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    if (_shakeLeft > 0) {
      final strength =
          (_shakeLeft / GameBalanceConfig.preFlipShakeDuration).clamp(
            0.0,
            1.0,
          ) *
          4;
      final dx = (_random.nextDouble() - 0.5) * strength;
      final dy = (_random.nextDouble() - 0.5) * strength;
      canvas.translate(dx, dy);
    }

    super.render(canvas);
    canvas.restore();

    if (_glitchLeft > 0) {
      final alpha = (_glitchLeft / _runtimeConfig.glitchDuration).clamp(
        0.0,
        1.0,
      );
      final stripe = Paint()
        ..color = Colors.white.withValues(alpha: alpha * 0.25);
      for (var i = 0; i < 14; i++) {
        final y = _random.nextDouble() * size.y;
        final h = 2 + _random.nextDouble() * 4;
        canvas.drawRect(Rect.fromLTWH(0, y, size.x, h), stripe);
      }
    }
  }

  @override
  void onRemove() {
    hud.dispose();
    adsService.dispose();
    unawaited(audioManager.handle(GameAudioEvent.matchExit));
    super.onRemove();
  }
}
