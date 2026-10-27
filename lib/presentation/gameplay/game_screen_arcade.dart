part of 'game_screen.dart';

/// Arcade state of one session in the maze: the run's tally, soul wisps,
/// power-ups, boosts, world twists and the result screens.
class _ArcadeState {
  RunTally tally = RunTally(mode: PlayMode.campaign);

  /// Boosts carried into this stage (re-applied on every retry of it).
  Set<BoostType> boosts = const <BoostType>{};

  bool revivedThisAttempt = false;
  bool endlessReviveUsed = false;
  int endlessDepth = 0;
  int endlessTimeBank = 0;

  final Set<Point<int>> wisps = <Point<int>>{};
  final Map<Point<int>, BoostType> pickups = <Point<int>, BoostType>{};
  int shield = 0;
  int clockBonus = 0;

  double frozenUntil = -100;
  double seerUntil = -100;
  bool frostOnSpawn = false;
  double graceUntil = -100;
  double nextRageAt = 12;
  double rageUntil = -100;
  bool rageAnnounced = false;
  bool devilWasClose = false;
  double lastFlipAt = 0;

  double shakeUntil = -100;
  double shakeAmp = 0;
  final List<TrailDot> trail = <TrailDot>[];
  double lastTrailAt = -1;
  final List<FloatingLabel> labels = <FloatingLabel>[];

  List<Point<int>> seerPath = const <Point<int>>[];
  Point<int>? seerFrom;

  bool touchSeen = false;
  bool sawFirstFlip = false;
  bool sawFirstDevil = false;
  Timer? introTimer;

  StageClearResult? victory;
  RunTally? victoryTally;
  bool victoryDoubled = false;
  int endlessWisps = 0;
  EndlessResult? endlessResult;
  Reward? dailyReward;
  bool? liveReported;
}

extension _ArcadeRunLogic on _GameScreenState {
  bool get _arcade => widget.arcadeRun != null;
  ArcadeRun get _run => widget.arcadeRun!;
  PlayMode get _mode => widget.arcadeRun?.session.mode ?? PlayMode.campaign;
  ProgressController get _progress => _run.arcade.progress;

  /// The world rule in force: the campaign world's twist, Endless Night
  /// walks through all of them, the Daily Nightmare has none (it must be the
  /// same maze for everyone).
  WorldTwist get _twist {
    if (!_arcade) return WorldTwist.none;
    return switch (_mode) {
      PlayMode.campaign => Worlds.forStage(_stage).twist,
      PlayMode.endless => Worlds.all[min(4, _a.endlessDepth ~/ 5)].twist,
      PlayMode.daily => WorldTwist.none,
    };
  }

  /// The stage rules an Endless Night depth plays by.
  static int endlessStageFor(int depth) => min(96, 3 + depth * 4);

  bool get _devilFrozen => _stageElapsedSeconds < _a.frozenUntil;
  bool get _inGrace => _stageElapsedSeconds < _a.graceUntil;
  bool get _raging => _stageElapsedSeconds < _a.rageUntil;
  bool get _seerActive => _stageElapsedSeconds < _a.seerUntil;

  bool get _showTouchControls =>
      !kIsWeb || _a.touchSeen || InputMode.touchSeen.value;

  // ---------------------------------------------------------------------------
  // Stage setup
  // ---------------------------------------------------------------------------

  /// Runs at the end of [_applyStageRule]: wisps, power-ups and boosts.
  void _prepareArcadeStage() {
    if (!_arcade) return;
    _a.frozenUntil = -100;
    _a.seerUntil = -100;
    _a.graceUntil = -100;
    _a.rageUntil = -100;
    _a.nextRageAt = 10 + _random.nextDouble() * 4;
    _a.devilWasClose = false;
    _a.lastFlipAt = 0;
    _a.frostOnSpawn = false;
    _a.trail.clear();
    _a.labels.clear();
    _a.seerPath = const <Point<int>>[];
    _a.seerFrom = null;
    _a.shield = 0;
    _a.tally.stage = _stage;

    for (final boost in _a.boosts) {
      switch (boost) {
        case BoostType.shield:
          _a.shield += 1;
        case BoostType.hourglass:
          break; // in the clock already (see _arcadeClockBonus)
        case BoostType.frost:
          _a.frostOnSpawn = true;
        case BoostType.seer:
          _a.seerUntil = Boosts.seerSeconds;
      }
    }
    _placeWispsAndPickups();
    _scheduleIntroBanner();
  }

  /// Extra seconds on this stage's clock from a carried hourglass.
  int get _arcadeClockBonus =>
      _arcade && _a.boosts.contains(BoostType.hourglass) ? Boosts.hourglassSeconds : 0;

  void _placeWispsAndPickups() {
    _a.wisps.clear();
    _a.pickups.clear();
    final rng = Random(_stageTrapSeed() ^ 0x5011);
    final blocked = <Point<int>>{
      _maze.start,
      _maze.end,
      ..._safeZones.keys,
      for (final box in _keyHunt.boxes) box.cell,
      for (final trap in _trapStateController.activeTiles) trap.cell,
    };
    final deadEnds = <Point<int>>[];
    final open = <Point<int>>[];
    for (var y = 0; y < _maze.rows; y++) {
      for (var x = 0; x < _maze.cols; x++) {
        final cell = Point<int>(x, y);
        if (blocked.contains(cell)) continue;
        if ((_distanceFromStart[cell] ?? 0) < 2) continue;
        final exits = Direction4.values.where((d) => _maze.canMove(cell, d)).length;
        (exits == 1 ? deadEnds : open).add(cell);
      }
    }
    deadEnds.shuffle(rng);
    open.shuffle(rng);

    // Power-ups wait at the far dead ends (worth the detour).
    final wantPickups = switch (_mode) {
      PlayMode.campaign => _stage >= 4 ? (Worlds.isGate(_stage) ? 2 : 1) : 0,
      PlayMode.endless => _a.endlessDepth >= 1 ? 1 : 0,
      PlayMode.daily => 0,
    };
    final byDistance = List<Point<int>>.of(deadEnds)
      ..sort((a, b) => (_distanceFromStart[b] ?? 0).compareTo(_distanceFromStart[a] ?? 0));
    const kinds = [
      BoostType.hourglass,
      BoostType.hourglass,
      BoostType.shield,
      BoostType.frost,
      BoostType.frost,
      BoostType.seer,
    ];
    for (final cell in byDistance.take(wantPickups)) {
      _a.pickups[cell] = kinds[rng.nextInt(kinds.length)];
    }

    final want = ((_maze.rows * _maze.cols) / 11).round().clamp(5, 18);
    bool spaced(Point<int> cell) => _a.wisps.every(
      (w) => (w.x - cell.x).abs() + (w.y - cell.y).abs() >= 2,
    );
    for (final cell in [...deadEnds, ...open]) {
      if (_a.wisps.length >= want) break;
      if (_a.pickups.containsKey(cell) || !spaced(cell)) continue;
      _a.wisps.add(cell);
    }
  }

  void _scheduleIntroBanner() {
    _a.introTimer?.cancel();
    final session = _run.session;
    String? title;
    String? subtitle;
    var color = NightHud.gold;
    if (session.tutorial && _stage == 1 && _mode == PlayMode.campaign) {
      title = _showTouchControls ? 'USE THE PAD TO MOVE' : 'ARROWS OR WASD TO MOVE';
      subtitle = 'REACH THE GLOWING STAIRS';
    } else if (_mode == PlayMode.campaign && Worlds.opensWorld(_stage)) {
      final world = Worlds.forStage(_stage);
      title = 'WORLD ${world.number}: ${world.name.toUpperCase()}';
      subtitle = world.twistText.toUpperCase();
      color = Color(world.accent);
    } else if (_mode == PlayMode.campaign && Worlds.isGate(_stage)) {
      title = 'GATE STAGE';
      subtitle = 'SURVIVE IT FOR A CHEST';
      color = NightHud.blood;
    } else if (_mode == PlayMode.endless) {
      title = 'DEPTH ${_a.endlessDepth + 1}';
      final twist = _twist;
      subtitle = twist == WorldTwist.none ? 'KEEP DESCENDING' : Worlds.all[min(4, _a.endlessDepth ~/ 5)].twistText.toUpperCase();
      color = NightHud.spirit;
    }
    if (title == null) return;
    final delay = _keyHunt.isActive ? const Duration(milliseconds: 2500) : const Duration(milliseconds: 250);
    final t = title;
    final s = subtitle;
    _a.introTimer = Timer(delay, () {
      if (!mounted || _roundResolved) return;
      _showBanner(t, subtitle: s, color: color, duration: const Duration(milliseconds: 2600));
    });
  }

  // ---------------------------------------------------------------------------
  // In the maze
  // ---------------------------------------------------------------------------

  /// Every step: soul wisps and power-ups on the cell are picked up.
  void _onArcadeStep(Point<int> cell) {
    if (!_arcade || _roundResolved) return;
    final at = Offset(cell.x.toDouble(), cell.y.toDouble());
    if (_a.wisps.remove(cell)) {
      _a.tally.wisps += 1;
      Sfx.instance.play(Sound.wisp, volume: 0.55);
      _fx.add(MazeFx(MazeFxKind.wispPop, at, _stageElapsedSeconds));
      _float('+1', at, color: NightHud.spirit);
      if (_a.wisps.isEmpty) {
        _showBanner('EVERY SOUL FOUND', subtitle: 'THE MAZE IS EMPTY', color: NightHud.spirit);
      }
    }
    final pickup = _a.pickups.remove(cell);
    if (pickup != null) _usePowerUp(pickup, at);
    if (pickup != null || _a.tally.wisps > 0) _set(() {});
  }

  void _usePowerUp(BoostType type, Offset at) {
    _a.tally.powerUps += 1;
    Sfx.instance.play(Sound.powerup, volume: 0.7);
    _fx.add(MazeFx(MazeFxKind.wispPop, at, _stageElapsedSeconds));
    final info = Boosts.info[type]!;
    switch (type) {
      case BoostType.shield:
        _a.shield += 1;
        _showBanner(info.name.toUpperCase(), subtitle: 'BLOCKS ONE DEATH', color: NightHud.spirit);
      case BoostType.hourglass:
        _set(() => _remainingSeconds += Boosts.hourglassSeconds);
        _float('+${Boosts.hourglassSeconds}s', at, color: NightHud.gold);
        _showBanner(info.name.toUpperCase(), subtitle: '+${Boosts.hourglassSeconds} SECONDS', color: NightHud.gold);
      case BoostType.frost:
        if (_devilCell != null) {
          _a.frozenUntil = _stageElapsedSeconds + Boosts.frostSeconds;
          _a.tally.frozenDevils += 1;
        } else {
          _a.frostOnSpawn = true;
        }
        _showBanner(info.name.toUpperCase(), subtitle: 'THE DEVIL FREEZES', color: NightHud.spirit);
      case BoostType.seer:
        _a.seerUntil = _stageElapsedSeconds + Boosts.seerSeconds;
        _a.seerFrom = null;
        _showBanner(info.name.toUpperCase(), subtitle: 'FOLLOW THE LIGHT', color: NightHud.gold);
    }
  }

  void _float(String text, Offset at, {Color color = NightHud.bone, double size = 1}) {
    _a.labels.add(FloatingLabel(text, at, _stageElapsedSeconds, color: color, size: size));
  }

  void _shake(double amp, [double seconds = 0.35]) {
    _a.shakeAmp = amp;
    _a.shakeUntil = _stageElapsedSeconds + seconds;
  }

  /// Arcade bookkeeping for each stage tick.
  void _arcadeTick({required bool flipped, required double dt}) {
    if (!_arcade) return;
    final t = _stageElapsedSeconds;
    if (flipped) {
      _a.lastFlipAt = t;
      _a.tally.flips += 1;
      _shake(3, 0.25);
      if (_run.session.tutorial && !_a.sawFirstFlip) {
        _a.sawFirstFlip = true;
        _showBanner('THE WORLD FLIPPED!', subtitle: 'YOUR CONTROLS ARE REVERSED', color: NightHud.blood, duration: const Duration(milliseconds: 2800));
      }
    }
    // Footprints for the trail cosmetic.
    if (_playerController.isMoving && t - _a.lastTrailAt > 0.06) {
      _a.lastTrailAt = t;
      _a.trail.add(TrailDot(_playerController.renderPosition, t));
    }
    _a.trail.removeWhere((d) => t - d.time > 0.8);
    _a.labels.removeWhere((l) => t - l.start > FloatingLabel.life);

    // The Devil's rage (world 5): short sprints while it is far behind.
    if (_twist == WorldTwist.rage && _devilCell != null && t >= _a.nextRageAt) {
      _a.rageUntil = t + 2.2;
      _a.nextRageAt = t + 11 + _random.nextDouble() * 4;
      if (!_a.rageAnnounced) {
        _a.rageAnnounced = true;
        _showBanner('THE DEVIL RAGES!', subtitle: 'IT SPRINTS WHEN FAR BEHIND', color: NightHud.blood);
      }
    }

    // The seer's path, recomputed when the runner changes cell.
    if (_seerActive) {
      final from = _playerController.position;
      if (_a.seerFrom != from) {
        _a.seerFrom = from;
        Point<int>? target;
        if (!_keyHunt.exitUnsealed) {
          var best = 1 << 30;
          for (final box in _keyHunt.unopened) {
            if (!box.hasKey) continue;
            final d = _maze.shortestPathDistance(from, box.cell) ?? 9999;
            if (d < best) {
              best = d;
              target = box.cell;
            }
          }
        }
        target ??= _maze.end;
        _a.seerPath = _shortestPathCells(from, target);
      }
    } else if (_a.seerPath.isNotEmpty) {
      _a.seerPath = const <Point<int>>[];
    }
  }

  /// A Devil just appeared.
  void _onArcadeDevilSpawned() {
    if (!_arcade) return;
    if (_a.frostOnSpawn) {
      _a.frostOnSpawn = false;
      _a.frozenUntil = _stageElapsedSeconds + Boosts.frostSeconds;
      _a.tally.frozenDevils += 1;
    }
    if (_run.session.tutorial && !_a.sawFirstDevil) {
      _a.sawFirstDevil = true;
      _showBanner('THE DEVIL WAKES!', subtitle: 'RUN! BLUE CANDLES KEEP YOU SAFE', color: NightHud.blood, duration: const Duration(milliseconds: 3000));
    }
  }

  /// Near misses: the Devil got right next to the runner and lost it.
  void _trackNearMiss(int distanceCells) {
    if (!_arcade) return;
    if (distanceCells <= 1 && !_playerSafe) {
      _a.devilWasClose = true;
    } else if (_a.devilWasClose && (distanceCells >= 4 || _playerSafe)) {
      _a.devilWasClose = false;
      _a.tally.nearMisses += 1;
      _float('CLOSE CALL!', _playerController.renderPosition, color: NightHud.blood, size: 1.25);
      Sfx.instance.play(Sound.swoosh, volume: 0.5);
    }
  }

  /// The safe zone banished the Devil while it was on the runner's heels.
  void _onArcadeSafeEntered() {
    if (!_arcade) return;
    _a.tally.safeVisits += 1;
    if (_a.devilWasClose) _trackNearMiss(99);
  }

  /// A holy ward takes the hit. True when it did.
  bool _absorbWithShield({TrapTile? trap}) {
    if (!_arcade || _a.shield <= 0) return false;
    _a.shield -= 1;
    Sfx.instance.play(Sound.shield, volume: 0.8);
    unawaited(HapticFeedback.heavyImpact());
    _shake(7, 0.4);
    _a.graceUntil = _stageElapsedSeconds + 1.6;
    if (trap != null) {
      _trapStateController.removeTilesOn({trap.cell});
    } else {
      _banishDevil();
    }
    _showBanner('WARD BROKEN', subtitle: 'IT SAVED YOU ONCE', color: NightHud.spirit);
    _markGameSurfaceDirty();
    return true;
  }

  void _banishDevil() {
    final devil = _devilCell;
    if (devil != null) _addSmoke(devil);
    _devilCell = null;
    _devilSpawned = false;
    _devilMoveAccumulator = 0;
    _stepsSinceSafeZone = 0;
    _awaitingDevilRespawnSteps = true;
    _dispatchDevilDistance(distanceTiles: 99, devilEnabled: false);
  }

  // ---------------------------------------------------------------------------
  // Endings
  // ---------------------------------------------------------------------------

  /// Sends the run's tally to progress (stats, missions, wisps as souls).
  void _flushTally({bool died = false}) {
    if (!_arcade) return;
    final tally = _a.tally;
    tally.died = died;
    tally.stage = _stage;
    if (tally.wisps > 0 ||
        tally.flips > 0 ||
        tally.escaped ||
        tally.died ||
        tally.keys > 0 ||
        tally.depth > 0) {
      _progress.recordRun(tally);
      _run.arcade.announceAchievements();
    }
    _a.tally = RunTally(mode: _mode, stage: _stage);
  }

  Future<void> _onArcadeCleared() async {
    _mercy.clear();
    unawaited(HapticFeedback.heavyImpact());
    try {
      await _audioCue(_audioManager.handle(GameAudioEvent.playerWon));
    } catch (_) {}
    if (!mounted) return;
    if (_mode == PlayMode.endless) {
      await _onEndlessCleared();
      return;
    }
    final seconds = max(1, _stageElapsedSeconds.round());
    final stars = StageEconomy.stars(
      secondsLeft: _remainingSeconds,
      totalSeconds: _stageDurationSeconds,
      revived: _a.revivedThisAttempt,
    );
    _a.tally
      ..escaped = true
      ..stars = stars
      ..seconds = seconds;
    final tally = _a.tally;
    final result = _progress.recordStageClear(stage: _stage, stars: stars, seconds: seconds);
    _flushTally();
    if (stars >= 3 || result.worldCleared) _run.arcade.portal.happyTime();
    _set(() {
      _isStageTransition = true;
      _completedStage = _stage;
      _a.victory = result;
      _a.victoryDoubled = false;
      _a.victoryTally = tally;
    });
  }

  Future<void> _onEndlessCleared() async {
    _a.endlessDepth += 1;
    _a.tally.depth = _a.endlessDepth;
    _a.endlessTimeBank += _remainingSeconds;
    Sfx.instance.play(Sound.levelup, volume: 0.5);
    _set(() => _isStageTransition = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    _loadArcadeStage(endlessStageFor(_a.endlessDepth), freshAttempt: false);
  }

  void _endEndlessRun() {
    final depth = _a.endlessDepth;
    final score = StageEconomy.endlessScore(
      depth: depth,
      wisps: _a.tally.wisps,
      secondsLeftTotal: _a.endlessTimeBank,
    );
    final wisps = _a.tally.wisps;
    final result = _progress.recordEndless(depth: depth, score: score);
    _flushTally(died: true);
    if (result.newBestDepth || result.newBestScore) _run.arcade.portal.happyTime();
    _set(() {
      _showLossOverlay = false;
      _a.endlessResult = result;
      _a.endlessWisps = wisps;
    });
  }

  /// Loads [stage] fresh (a retry, the next stage, the next Endless depth).
  void _loadArcadeStage(int stage, {bool freshAttempt = true}) {
    _a.introTimer?.cancel();
    _countdownTimer?.cancel();
    _stageClearController.stop();
    _stageClearController.reset();
    if (freshAttempt) {
      _a.revivedThisAttempt = false;
      _a.tally = RunTally(mode: _mode, stage: stage);
    }
    _stage = stage.clamp(1, _GameScreenState._maxStage).toInt();
    _stageRule = StageRules.forStage(_stage);
    _difficulty = _difficultyForStage(_stage);
    _maze = _generateMaze();
    _rebuildPathMetrics();
    _isStageTransition = false;
    _isTimeUpHandling = false;
    _showLossOverlay = false;
    _lostByTime = false;
    _lostByTrap = false;
    _trapDeathQuote = null;
    _trapDeathInProgress = false;
    _trapDeathSequence.cancel();
    _adActionInProgress = false;
    _isPaused = false;
    _a.victory = null;
    _a.endlessResult = null;
    _playerController.resetForMaze(_maze);
    _applyStageRule(resetMaze: false);
    unawaited(_audioManager.handle(GameAudioEvent.matchExit));
    unawaited(_audioManager.handle(GameAudioEvent.matchRestart));
    _restartCountdown();
    _requestKeyboardFocusIfNeeded();
    _set(() {});
  }

  /// A new Endless Night run from depth 0.
  void _startEndlessRun() {
    _a.endlessDepth = 0;
    _a.endlessTimeBank = 0;
    _a.endlessReviveUsed = false;
    _loadArcadeStage(endlessStageFor(0));
  }

  /// Back in the maze where the run ended: the Devil is banished, a clock
  /// that ran out gets time back, a fallen floor holds again.
  void _reviveInPlace() {
    _a.revivedThisAttempt = true;
    if (_mode == PlayMode.endless) _a.endlessReviveUsed = true;
    if (_lostByTrap) {
      _trapStateController.removeTilesOn({_playerController.position});
    }
    if (_lostByTime || _remainingSeconds < 25) {
      _remainingSeconds = max(_remainingSeconds, 25);
    }
    _banishDevil();
    _trapDeathSequence.cancel();
    _a.graceUntil = _stageElapsedSeconds + 2.2;
    _set(() {
      _showLossOverlay = false;
      _roundResolved = false;
      _isTimeUpHandling = false;
      _trapDeathInProgress = false;
      _adActionInProgress = false;
      _lostByTime = false;
      _lostByTrap = false;
      _trapDeathQuote = null;
    });
    unawaited(_audioManager.handle(GameAudioEvent.matchExit));
    unawaited(_audioManager.handle(GameAudioEvent.matchRestart));
    unawaited(_audioManager.handle(GameAudioEvent.timeChanged, secondsLeft: _remainingSeconds));
    _startCountdown();
    _showBanner('SECOND CHANCE!', subtitle: 'THE DEVIL IS GONE, FOR NOW', color: NightHud.gold);
    _requestKeyboardFocusIfNeeded();
  }

  bool get _canRevive => switch (_mode) {
    PlayMode.campaign => !_a.revivedThisAttempt,
    PlayMode.endless => !_a.endlessReviveUsed,
    PlayMode.daily => false,
  };

  Future<void> _arcadeRevive() async {
    if (_adActionInProgress) return;
    _set(() => _adActionInProgress = true);
    final ok = await _run.arcade.watchRewarded();
    if (!mounted) return;
    if (ok) {
      _reviveInPlace();
    } else {
      _set(() => _adActionInProgress = false);
    }
  }

  Future<void> _arcadeNext() async {
    _a.boosts = const <BoostType>{};
    await _run.arcade.midgameIfDue();
    if (!mounted) return;
    _loadArcadeStage(_stage + 1);
  }

  Future<void> _arcadeDouble() async {
    final victory = _a.victory;
    if (victory == null || _a.victoryDoubled) return;
    if (!await _run.arcade.watchRewarded()) return;
    if (!mounted) return;
    _progress.grantBonusSouls(victory.souls);
    Sfx.instance.play(Sound.coins);
    _set(() => _a.victoryDoubled = true);
  }

  void _arcadeQuit({bool toMap = false}) {
    _a.introTimer?.cancel();
    _countdownTimer?.cancel();
    _playerController.stop();
    unawaited(_audioManager.handle(GameAudioEvent.matchExit));
    if (toMap && _mode == PlayMode.campaign) {
      _run.onOpenMap(_stage);
    } else {
      _run.onExit();
    }
  }

  /// Gameplay events for the portal: live only while the maze runs.
  void _reportGameplay() {
    if (!_arcade) return;
    final live =
        widget.isActive &&
        !_isPaused &&
        !_showLossOverlay &&
        !_isStageTransition &&
        !_trapDeathInProgress &&
        !_isExternallyInactive &&
        _a.victory == null &&
        _a.endlessResult == null &&
        _dailySummary == null;
    if (_a.liveReported == live) return;
    _a.liveReported = live;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (live) {
        _run.arcade.portal.gameplayStart();
      } else {
        _run.arcade.portal.gameplayStop();
      }
    });
  }

  /// How close the run came: tiles and keys when near, else how far along.
  String _arcadeNearMiss() {
    if (_lossDistanceToExit <= 12 || _startToGoalDistance <= 0) {
      return nearMissText(tilesToExit: _lossDistanceToExit, keysShort: _lossKeysShort);
    }
    final share = (1 - _lossDistanceToExit / _startToGoalDistance).clamp(0.0, 0.99);
    final percent = (share * 100).round();
    final keys = _lossKeysShort > 0 ? ' · $_lossKeysShort KEY${_lossKeysShort == 1 ? '' : 'S'} SHORT' : '';
    return percent <= 5 ? 'THE MAZE WAITS FOR YOU$keys' : '$percent% OF THE WAY OUT$keys';
  }

  /// The current stars if the runner escaped this instant.
  int get _starsNow => StageEconomy.stars(
    secondsLeft: _remainingSeconds,
    totalSeconds: _stageDurationSeconds,
    revived: _a.revivedThisAttempt,
  );

  Offset get _shakeOffset {
    if (_stageElapsedSeconds >= _a.shakeUntil) return Offset.zero;
    final left = (_a.shakeUntil - _stageElapsedSeconds).clamp(0.0, 1.0);
    final amp = _a.shakeAmp * left * 2.5;
    return Offset(
      sin(_stageElapsedSeconds * 91) * amp,
      cos(_stageElapsedSeconds * 77) * amp,
    );
  }

  // ---------------------------------------------------------------------------
  // Overlays
  // ---------------------------------------------------------------------------

  List<Widget> _arcadeOverlays() {
    if (!_arcade) return const <Widget>[];
    final overlays = <Widget>[];
    if (_isPaused) {
      overlays.add(
        PauseOverlay(
          heading: switch (_mode) {
            PlayMode.campaign => 'STAGE $_stage · ${Worlds.forStage(_stage).name.toUpperCase()}',
            PlayMode.endless => 'ENDLESS NIGHT · DEPTH ${_a.endlessDepth + 1}',
            PlayMode.daily => 'DAILY NIGHTMARE #${_daily?.number ?? 0}',
          },
          progress: _progress,
          onResume: _togglePause,
          onRestart: () {
            _flushTally();
            switch (_mode) {
              case PlayMode.campaign:
                _loadArcadeStage(_stage);
              case PlayMode.endless:
                _startEndlessRun();
              case PlayMode.daily:
                _restartDaily();
            }
          },
          quitLabel: _mode == PlayMode.campaign ? 'QUIT TO MAP' : 'QUIT TO MENU',
          onQuit: () {
            _flushTally();
            _arcadeQuit(toMap: true);
          },
        ),
      );
    }
    final victory = _a.victory;
    if (victory != null) {
      overlays.add(
        VictoryOverlay(
          result: victory,
          tally: _a.victoryTally ?? _a.tally,
          doubled: _a.victoryDoubled,
          onDouble: victory.souls > 0 ? _arcadeDouble : null,
          onNext: victory.stage < Worlds.maxStage ? () => unawaited(_arcadeNext()) : null,
          onReplay: () => _loadArcadeStage(_stage),
          onMap: () => _arcadeQuit(toMap: true),
        ),
      );
    }
    final endless = _a.endlessResult;
    if (endless != null) {
      overlays.add(
        EndlessOverOverlay(
          result: endless,
          wisps: _a.endlessWisps,
          onAgain: _startEndlessRun,
          onMenu: () => _arcadeQuit(),
        ),
      );
    }
    final daily = _dailySummary;
    if (daily != null) {
      overlays.add(
        DailyEscapeOverlay(
          summary: daily,
          reward: _a.dailyReward,
          onShare: _shareDaily,
          onAgain: _restartDaily,
          onMenu: () => _arcadeQuit(),
        ),
      );
    }
    if (_showLossOverlay) {
      final title = _lostByTrap ? 'Fallen' : (_lostByTime ? "Time's Up" : 'Caught!');
      final reason = _lostByTrap
          ? (_trapDeathQuote ?? 'The floor gave way beneath you.')
          : (_lostByTime ? 'The last candle burned out.' : 'The Devil caught you.');
      final near = _arcadeNearMiss();
      switch (_mode) {
        case PlayMode.campaign:
          overlays.add(
            DefeatOverlay(
              title: title,
              reason: reason,
              nearMiss: near,
              wisps: _a.tally.wisps,
              busy: _adActionInProgress,
              onRevive: _canRevive ? _arcadeRevive : null,
              onRetry: () {
                _flushTally(died: true);
                _loadArcadeStage(_stage);
              },
              onMenu: () {
                _flushTally(died: true);
                _arcadeQuit(toMap: true);
              },
            ),
          );
        case PlayMode.endless:
          overlays.add(
            DefeatOverlay(
              title: title,
              reason: reason,
              nearMiss: 'DEPTH ${_a.endlessDepth} · ${near.toUpperCase()}',
              busy: _adActionInProgress,
              onRevive: _canRevive ? _arcadeRevive : null,
              reviveText: 'KEEP YOUR DEPTH',
              retryLabel: 'END RUN',
              menuLabel: 'MENU',
              onRetry: _endEndlessRun,
              onMenu: () {
                _endEndlessRun();
              },
            ),
          );
        case PlayMode.daily:
          overlays.add(
            DefeatOverlay(
              title: title,
              reason: reason,
              nearMiss: near,
              retryLabel: 'TRY AGAIN',
              menuLabel: 'MENU',
              onRetry: () {
                _flushTally(died: true);
                _restartDaily();
              },
              onMenu: () {
                _flushTally(died: true);
                _arcadeQuit();
              },
            ),
          );
      }
    }
    return overlays;
  }
}
