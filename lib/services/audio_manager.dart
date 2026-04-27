import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart' as ja;

import 'game_audio_event.dart';

enum _AudioCue {
  calmLoop,
  flip,
  devilApproach,
  mazeShift,
  safeZone,
  lowTimeAlarm,
  winning,
  playerLost,
  trapBreak,
}

class _ResolvedAsset {
  const _ResolvedAsset(this.fileName);

  final String fileName;

  String get bundlePath => 'assets/audio/$fileName';
  String get sfxPath => 'audio/$fileName';
}

class _AudioBusState {
  _AudioBusState();

  double volume = 1.0;
  bool muted = false;
  double duck = 1.0;
}

class _LoopChannel {
  _LoopChannel(this.player);

  final ja.AudioPlayer player;
  String? assetPath;
  bool prepared = false;
  bool isPlaying = false;
  bool resumeAfterPause = false;
  double baseVolume = 1.0;
  int fadeToken = 0;
}

class _OneShotVoice {
  _OneShotVoice(this.player);

  final ap.AudioPlayer player;
  StreamSubscription<dynamic>? completionSubscription;
  bool inUse = false;
  DateTime startedAt = DateTime.fromMillisecondsSinceEpoch(0);
  AudioBus bus = AudioBus.action;
  _AudioCue? cue;
  double baseVolume = 1.0;
}

class _QueuedAudioEvent {
  _QueuedAudioEvent(this.payload, this.completer, {this.devilRevision});

  final GameAudioEventPayload payload;
  final Completer<void> completer;
  final int? devilRevision;
}

class AudioManager {
  AudioManager._internal();

  static final AudioManager instance = AudioManager._internal();

  static const Duration _matchStartDelay = Duration(seconds: 2);
  static const Duration _calmFadeInDuration = Duration(milliseconds: 300);
  static const Duration _calmFadeOutWinDuration = Duration(milliseconds: 120);
  static const Duration _safeZoneCooldown = Duration(milliseconds: 350);
  static const Duration _loseSilence = Duration(milliseconds: 80);
  static const Duration _devilFadeInDuration = Duration(milliseconds: 150);
  static const Duration _loopDefaultFadeIn = Duration(milliseconds: 150);
  static const Duration _loopDefaultFadeOut = Duration(milliseconds: 160);
  static const Duration _safeZoneDuckDuration = Duration(milliseconds: 500);
  static const Duration _actionEnemyDuckHold = Duration(milliseconds: 220);
  static const Duration _actionEnemyDuckRelease = Duration(milliseconds: 320);
  static const Duration _flipEnemyDuckHold = Duration(milliseconds: 90);
  static const Duration _flipEnemyDuckRelease = Duration(milliseconds: 140);
  static const Duration _devilCueCooldown = Duration(milliseconds: 420);
  static const Duration _devilPriorityActionDuckHold = Duration(
    milliseconds: 180,
  );
  static const Duration _devilPriorityActionDuckRelease = Duration(
    milliseconds: 240,
  );
  static const Duration _winSafetyDelay = Duration(milliseconds: 30);
  static const Duration _flipRetryDelay = Duration(milliseconds: 12);
  static const Duration _oneShotPlayTimeout = Duration(milliseconds: 650);
  static const Duration _mazeShiftPriorityFallback = Duration(
    milliseconds: 5000,
  );

  static const int _devilStartDistanceTiles = 6;
  static const int _devilStopDistanceTiles = 7;

  static const bool _safeZoneDuckingEnabled = true;
  static const bool _safeZoneHalvesDevilVolume = true;
  static const int _oneShotVoicesPerBus = 4;

  static const double _calmBaseVolume = 0.45;
  static const double _flipBaseVolume = 0.92;
  static const double _devilBaseVolume = 1.0;
  static const double _devilAudibilityBoost = 2.50;
  static const double _devilMinTriggerVolume = 1.0;
  static const double _devilPriorityActionDuckFactor = 0.62;
  static const double _devilLoopMaxVolume = 1.0;
  static const double _actionEnemyDuckFactor = 0.30;
  // Keep devil presence stronger while the flip cue is playing.
  static const double _flipEnemyDuckFactor = 0.90;
  static const double _safeZoneBaseVolume = 0.75;
  static const double _mazeShiftBaseVolume = 1.0;
  static const double _lowTimeBaseVolume = 0.80;
  static const double _winBaseVolume = 1.0;
  static const double _loseBaseVolume = 1.0;

  static bool _debugLogsEnabled = kDebugMode;

  final ValueNotifier<AudioDebugSnapshot> debugSnapshot =
      ValueNotifier<AudioDebugSnapshot>(AudioDebugSnapshot.initial);

  final Queue<_QueuedAudioEvent> _queue = Queue<_QueuedAudioEvent>();
  bool _isProcessingQueue = false;

  final Map<AudioBus, _AudioBusState> _buses = <AudioBus, _AudioBusState>{
    AudioBus.master: _AudioBusState(),
    AudioBus.bgm: _AudioBusState(),
    AudioBus.ambient: _AudioBusState(),
    AudioBus.enemy: _AudioBusState(),
    AudioBus.ui: _AudioBusState(),
    AudioBus.action: _AudioBusState(),
  };

  final _LoopChannel _calmLoop = _LoopChannel(ja.AudioPlayer());
  final _LoopChannel _devilLoop = _LoopChannel(ja.AudioPlayer());
  final _LoopChannel _lowTimeLoop = _LoopChannel(ja.AudioPlayer());

  final Map<AudioBus, List<_OneShotVoice>> _oneShotVoicePools =
      <AudioBus, List<_OneShotVoice>>{
        AudioBus.ambient: List<_OneShotVoice>.generate(
          _oneShotVoicesPerBus,
          (_) => _OneShotVoice(ap.AudioPlayer()),
          growable: false,
        ),
        AudioBus.enemy: List<_OneShotVoice>.generate(
          _oneShotVoicesPerBus,
          (_) => _OneShotVoice(ap.AudioPlayer()),
          growable: false,
        ),
        AudioBus.ui: List<_OneShotVoice>.generate(
          _oneShotVoicesPerBus,
          (_) => _OneShotVoice(ap.AudioPlayer()),
          growable: false,
        ),
        AudioBus.action: List<_OneShotVoice>.generate(
          _oneShotVoicesPerBus,
          (_) => _OneShotVoice(ap.AudioPlayer()),
          growable: false,
        ),
      };

  final Map<_AudioCue, _ResolvedAsset?> _resolvedAssets =
      <_AudioCue, _ResolvedAsset?>{};

  final Map<GameAudioEvent, DateTime> _cooldownUntil =
      <GameAudioEvent, DateTime>{};

  final Stopwatch _calmStartStopwatch = Stopwatch();
  Timer? _calmStartTimer;
  Duration _remainingCalmStartDelay = _matchStartDelay;
  bool _calmStartQueued = false;

  Timer? _safeZoneDuckTimer;
  Timer? _actionEnemyDuckTimer;
  Timer? _flipEnemyDuckTimer;
  Timer? _devilPriorityActionDuckTimer;
  Timer? _mazeShiftPriorityFallbackTimer;
  Timer? _alarmPulseTimer;
  bool _alarmPulseOn = false;
  double _alarmPulseBoost = 0;
  double _safeZoneEnemyDuck = 1.0;
  double _actionEnemyDuck = 1.0;
  double _flipEnemyDuck = 1.0;
  double _devilPriorityActionDuck = 1.0;
  int _actionEnemyDuckToken = 0;
  int _flipEnemyDuckToken = 0;
  int _devilPriorityActionDuckToken = 0;

  int _timelineToken = 0;
  int? _lastFlipFrameId;

  bool _initialized = false;
  bool _preloadAttempted = false;
  bool _disposing = false;

  MatchAudioState _matchState = MatchAudioState.idle;
  MatchAudioState _stateBeforePause = MatchAudioState.idle;

  bool isMatchActive = false;
  bool isWon = false;
  bool isLost = false;
  bool isPaused = false;
  bool isCalmPlaying = false;
  bool isDevilPlaying = false;
  bool isAlarmPlaying = false;
  bool _isSafeZoneImmune = false;
  bool _outcomeEventQueued = false;
  bool _devilThreatActive = false;
  bool _mazeShiftPriorityActive = false;

  int? _secondsLeft;
  int? _devilDistanceTiles;

  /// Authoritative latest devil distance written by every incoming event
  /// BEFORE queue processing.  This lets queue-processed handlers detect
  /// stale events:  if _latestDevilDistance >= 7 but the handler is running
  /// for an old dist=5 event, the handler knows to stop, not start.
  int _latestDevilDistance = 99;
  bool _latestDevilEnabled = false;
  bool _latestSafeZoneImmune = false;
  int _latestDevilRevision = 0;
  int _nextDevilRevision = 0;

  String _lastEvent = 'idle';

  static const Map<_AudioCue, List<String>> _assetCandidates =
      <_AudioCue, List<String>>{
        // Prefer the dedicated background track; keep legacy fallback.
        _AudioCue.calmLoop: <String>['background_audio.mp3', 'calm_loop.mp3'],
        _AudioCue.flip: <String>[
          'fahhhh_flippingtime.mp3',
          'fahhhhh_flippingtime.mp3',
        ],
        _AudioCue.devilApproach: <String>['devil_approach.wav'],
        _AudioCue.mazeShift: <String>['maze_shift_audio.mp3'],
        _AudioCue.safeZone: <String>['safe_zone_sound.mp3'],
        _AudioCue.lowTimeAlarm: <String>['low_time_alarm.wav'],
        _AudioCue.winning: <String>['winning_soundeffect.mp3'],
        _AudioCue.playerLost: <String>[
          'playerlost_soundeffect.mp3',
          'gamelost_soundeffect.mp3',
          'game_lost_soundeffect.mp3',
        ],
        _AudioCue.trapBreak: <String>['glass_break.mp3', 'glass_break.wav'],
      };

  static Future<void> configureGlobalAudio({
    double? volume,
    bool? muted,
    bool? debugLogs,
  }) async {
    if (volume != null) {
      await instance.setBusVolume(AudioBus.master, volume);
    }
    if (muted != null) {
      await instance.setBusMuted(AudioBus.master, muted);
    }
    if (debugLogs != null) {
      _debugLogsEnabled = debugLogs;
    }
  }

  Future<void> preload() async {
    if (_initialized || _disposing) {
      return;
    }
    if (_preloadAttempted) {
      return;
    }

    _preloadAttempted = true;

    await _resolveAssets();
    await _prepareLoopChannel(_calmLoop, _AudioCue.calmLoop);
    await _prepareLoopChannel(_devilLoop, _AudioCue.devilApproach);
    await _prepareLoopChannel(_lowTimeLoop, _AudioCue.lowTimeAlarm);

    for (final voice in _allOneShotVoices()) {
      if (voice.completionSubscription == null) {
        voice.completionSubscription = voice.player.onPlayerComplete.listen((
          _,
        ) {
          final completedCue = voice.cue;
          voice.inUse = false;
          voice.cue = null;
          if (completedCue == _AudioCue.mazeShift && _mazeShiftPriorityActive) {
            unawaited(_onMazeShiftEnded());
          }
        });
      }
      await _safe('oneshot.setReleaseMode', () async {
        await voice.player.setReleaseMode(ap.ReleaseMode.stop);
      });
      await _safe('oneshot.setPlayerMode', () async {
        await voice.player.setPlayerMode(ap.PlayerMode.lowLatency);
      });
    }

    _initialized = true;
    _log('AudioManager initialized');
    _emitDebugSnapshot();
  }

  Future<void> handle(
    GameAudioEvent event, {
    int? secondsLeft,
    int? devilDistanceTiles,
    bool? devilEnabled,
    bool? safeZoneImmune,
    int? frameId,
  }) {
    final payload = GameAudioEventPayload(
      event,
      secondsLeft: secondsLeft,
      devilDistanceTiles: devilDistanceTiles,
      devilEnabled: devilEnabled,
      safeZoneImmune: safeZoneImmune,
      frameId: frameId,
    );
    return handlePayload(payload);
  }

  Future<void> handlePayload(GameAudioEventPayload payload) {
    final completer = Completer<void>();
    var devilRevision = _latestDevilRevision;

    if (_shouldDropGameplayEvent(payload.type)) {
      completer.complete();
      return completer.future;
    }

    // Snapshot latest devil state for queue-bypass staleness detection.
    if (payload.type == GameAudioEvent.devilDistanceChanged) {
      _latestDevilDistance = payload.devilDistanceTiles ?? 99;
      _latestDevilEnabled = payload.devilEnabled ?? false;
      if (payload.safeZoneImmune != null) {
        _latestSafeZoneImmune = payload.safeZoneImmune!;
      }
      devilRevision = ++_nextDevilRevision;
      _latestDevilRevision = devilRevision;

      if (_mustStopDevilImmediatelyFromLatestState) {
        _forceKillDevilLoopSync();
      }
    }

    if (payload.type == GameAudioEvent.playerWon ||
        payload.type == GameAudioEvent.playerLost ||
        payload.type == GameAudioEvent.trapDeath) {
      _outcomeEventQueued = true;
      _latestDevilEnabled = false;
      _latestDevilDistance = 99;
      _latestSafeZoneImmune = false;
      _latestDevilRevision = ++_nextDevilRevision;
      _cancelAlarmPulseTimer();
      isAlarmPlaying = false;
      _lowTimeLoop.baseVolume = 0;
      unawaited(_safe('alarm.stopOnOutcomeQueue', _lowTimeLoop.player.stop));
      _forceKillMazeShiftPrioritySync();
      // Synchronous inline stop so devil threat cannot bleed into outcome.
      _forceKillDevilLoopSync();
    }

    if (payload.type == GameAudioEvent.matchStart ||
        payload.type == GameAudioEvent.matchRestart ||
        payload.type == GameAudioEvent.matchExit) {
      _outcomeEventQueued = false;
      _latestDevilEnabled = false;
      _latestDevilDistance = 99;
      _latestSafeZoneImmune = false;
      _latestDevilRevision = ++_nextDevilRevision;
      _forceKillMazeShiftPrioritySync();
    }

    if (_isQueueBoundaryEvent(payload.type)) {
      _clearQueuedEvents();
    }

    if (payload.type == GameAudioEvent.devilDistanceChanged) {
      _coalesceQueuedDevilDistanceEvents();
    }

    final queued = _QueuedAudioEvent(
      payload,
      completer,
      devilRevision: payload.type == GameAudioEvent.devilDistanceChanged
          ? devilRevision
          : null,
    );
    if (payload.type == GameAudioEvent.flipTriggered ||
        payload.type == GameAudioEvent.mazeShiftStarted ||
        payload.type == GameAudioEvent.mazeShiftEnded ||
        payload.type == GameAudioEvent.playerWon ||
        payload.type == GameAudioEvent.playerLost ||
        payload.type == GameAudioEvent.trapDeath ||
        payload.type == GameAudioEvent.trapDeathCrack ||
        payload.type == GameAudioEvent.trapDeathFall ||
        payload.type == GameAudioEvent.trapDeathImpact ||
        payload.type == GameAudioEvent.matchExit) {
      _queue.addFirst(queued);
    } else {
      _queue.add(queued);
    }

    unawaited(_drainQueue());
    return completer.future;
  }

  bool _shouldDropGameplayEvent(GameAudioEvent event) {
    final isResetEvent =
        event == GameAudioEvent.matchStart ||
        event == GameAudioEvent.matchRestart ||
        event == GameAudioEvent.matchExit;
    final isMazeShiftControlEvent =
        event == GameAudioEvent.mazeShiftStarted ||
        event == GameAudioEvent.mazeShiftEnded;
    final isLifecycleControlEvent =
        event == GameAudioEvent.matchPause ||
        event == GameAudioEvent.matchResume;

    if (_mazeShiftPriorityActive) {
      return event != GameAudioEvent.playerWon &&
          event != GameAudioEvent.playerLost &&
          event != GameAudioEvent.trapDeath &&
          event != GameAudioEvent.trapDeathCrack &&
          event != GameAudioEvent.trapDeathFall &&
          event != GameAudioEvent.trapDeathImpact &&
          !isResetEvent &&
          !isMazeShiftControlEvent &&
          !isLifecycleControlEvent;
    }

    if (_matchState == MatchAudioState.won) {
      return !isResetEvent;
    }

    if (_outcomeEventQueued) {
      // Flip must always play for tactile feedback, even during the brief
      // window between outcome-queue and actual outcome processing.
      return event != GameAudioEvent.playerWon &&
          event != GameAudioEvent.playerLost &&
          event != GameAudioEvent.trapDeath &&
          event != GameAudioEvent.flipTriggered &&
          !isMazeShiftControlEvent &&
          !isResetEvent;
    }

    return false;
  }

  bool _isQueueBoundaryEvent(GameAudioEvent event) {
    return event == GameAudioEvent.matchStart ||
        event == GameAudioEvent.matchRestart ||
        event == GameAudioEvent.matchExit ||
        event == GameAudioEvent.playerWon ||
        event == GameAudioEvent.playerLost ||
        event == GameAudioEvent.trapDeath;
  }

  void _clearQueuedEvents() {
    if (_queue.isEmpty) {
      return;
    }

    while (_queue.isNotEmpty) {
      final queued = _queue.removeFirst();
      if (!queued.completer.isCompleted) {
        queued.completer.complete();
      }
    }
  }

  void _coalesceQueuedDevilDistanceEvents() {
    if (_queue.isEmpty) {
      return;
    }

    // Drop ALL old devil-distance events from the queue.  The brand-new
    // incoming event (added right after this call) carries the latest
    // distance/enabled state and supersedes everything already queued.
    final retained = <_QueuedAudioEvent>[];
    while (_queue.isNotEmpty) {
      final queued = _queue.removeFirst();
      if (queued.payload.type == GameAudioEvent.devilDistanceChanged) {
        if (!queued.completer.isCompleted) {
          queued.completer.complete();
        }
        continue;
      }
      retained.add(queued);
    }

    _queue.addAll(retained);
  }

  Future<void> _drainQueue() async {
    if (_isProcessingQueue || _disposing) {
      return;
    }

    _isProcessingQueue = true;
    try {
      while (_queue.isNotEmpty) {
        final queued = _queue.removeFirst();
        try {
          await _processEvent(
            queued.payload,
            devilRevision: queued.devilRevision,
          );
          queued.completer.complete();
        } catch (error, stackTrace) {
          _logError('event:${queued.payload.type.name}', error, stackTrace);
          if (!queued.completer.isCompleted) {
            queued.completer.completeError(error, stackTrace);
          }
        }
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  Future<void> _processEvent(
    GameAudioEventPayload payload, {
    int? devilRevision,
  }) async {
    await preload();

    _lastEvent = payload.type.name;

    switch (payload.type) {
      case GameAudioEvent.matchStart:
        await _onMatchStart();
        break;
      case GameAudioEvent.matchPause:
        await _onMatchPause();
        break;
      case GameAudioEvent.matchResume:
        await _onMatchResume();
        break;
      case GameAudioEvent.matchRestart:
        await _onMatchRestart();
        break;
      case GameAudioEvent.matchExit:
        await _onMatchExit();
        break;
      case GameAudioEvent.flipTriggered:
        await _onFlipTriggered(payload.frameId);
        break;
      case GameAudioEvent.devilDistanceChanged:
        final revision = devilRevision;
        if (revision == null || revision != _latestDevilRevision) {
          _log(
            'Skipping stale devil-distance event (rev=$revision latest=$_latestDevilRevision)',
          );
          break;
        }
        await _onDevilDistanceChanged(
          distanceTiles: payload.devilDistanceTiles,
          devilEnabled: payload.devilEnabled ?? true,
          safeZoneImmune: payload.safeZoneImmune,
          devilRevision: revision,
        );
        break;
      case GameAudioEvent.mazeShiftStarted:
        await _onMazeShiftStarted();
        break;
      case GameAudioEvent.mazeShiftEnded:
        await _onMazeShiftEnded();
        break;
      case GameAudioEvent.safeZoneEntered:
        await _onSafeZoneEntered();
        break;
      case GameAudioEvent.safeZoneExited:
        await _onSafeZoneExited();
        break;
      case GameAudioEvent.timeChanged:
        await _onTimeChanged(payload.secondsLeft);
        break;
      case GameAudioEvent.playerWon:
        await _onPlayerWon();
        break;
      case GameAudioEvent.playerLost:
        await _onPlayerLost();
        break;
      case GameAudioEvent.trapStepWarning:
        // Dedicated break cue when stepping on a fragile tile.
        if (_canPlayGameplaySfx) {
          await _playOneShot(
            _AudioCue.trapBreak,
            bus: AudioBus.action,
            baseVolume: 0.58,
            playbackRate: 0.96 + (Random().nextDouble() * 0.12),
          );
        }
        break;
      case GameAudioEvent.trapProximityTension:
        // Short glass effect for proximity escalation.
        if (_canPlayGameplaySfx) {
          await _playOneShot(
            _AudioCue.trapBreak,
            bus: AudioBus.action,
            baseVolume: 0.34,
            playbackRate: 0.82 + (Random().nextDouble() * 0.10),
          );
        }
        break;
      case GameAudioEvent.trapDeathCrack:
        // Initial shatter burst during death sequence.
        if (_canPlayGameplaySfx) {
          await _playOneShot(
            _AudioCue.trapBreak,
            bus: AudioBus.action,
            baseVolume: 0.92,
            playbackRate: 1.05,
          );
        }
        break;
      case GameAudioEvent.trapDeathFall:
        // Falling whoosh accent during the collapse sequence.
        if (_canPlayGameplaySfx) {
          await _playOneShot(
            _AudioCue.playerLost,
            bus: AudioBus.action,
            baseVolume: 0.65,
            playbackRate: 0.72,
          );
        }
        break;
      case GameAudioEvent.trapDeathImpact:
        // Heavy low-end impact at the end of the fall.
        if (_canPlayGameplaySfx) {
          await _playOneShot(
            _AudioCue.playerLost,
            bus: AudioBus.action,
            baseVolume: 0.90,
            playbackRate: 0.64,
          );
        }
        break;
      case GameAudioEvent.trapDeath:
        // Full trap death mirrors playerLost flow.
        await _onPlayerLost();
        break;
    }

    _emitDebugSnapshot();
  }

  Future<void> setBusVolume(AudioBus bus, double volume) async {
    final state = _buses[bus];
    if (state == null) {
      return;
    }

    state.volume = volume.clamp(0.0, 1.0).toDouble();
    await _refreshAllVolumes();
    _emitDebugSnapshot();
  }

  Future<void> setBusMuted(AudioBus bus, bool muted) async {
    final state = _buses[bus];
    if (state == null) {
      return;
    }

    state.muted = muted;
    await _refreshAllVolumes();
    _emitDebugSnapshot();
  }

  Future<void> fadeBus(
    AudioBus bus, {
    required double to,
    Duration duration = const Duration(milliseconds: 180),
  }) async {
    final state = _buses[bus];
    if (state == null) {
      return;
    }

    final from = state.volume;
    final target = to.clamp(0.0, 1.0).toDouble();
    final steps = max(1, duration.inMilliseconds ~/ 30);

    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      state.volume = from + (target - from) * t;
      await _refreshAllVolumes();
      if (i < steps) {
        await Future<void>.delayed(
          Duration(milliseconds: duration.inMilliseconds ~/ steps),
        );
      }
    }

    _emitDebugSnapshot();
  }

  Future<void> duckBus(
    AudioBus bus, {
    required double factor,
    Duration hold = const Duration(milliseconds: 250),
    Duration release = const Duration(milliseconds: 180),
  }) async {
    final state = _buses[bus];
    if (state == null) {
      return;
    }

    state.duck = factor.clamp(0.0, 1.0).toDouble();
    await _refreshAllVolumes();
    _emitDebugSnapshot();

    if (hold > Duration.zero) {
      await Future<void>.delayed(hold);
    }

    final from = state.duck;
    final steps = max(1, release.inMilliseconds ~/ 30);
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      state.duck = from + (1 - from) * t;
      await _refreshAllVolumes();
      if (i < steps) {
        await Future<void>.delayed(
          Duration(milliseconds: release.inMilliseconds ~/ steps),
        );
      }
    }

    _emitDebugSnapshot();
  }

  Future<void> dispose() async {
    _disposing = true;
    _timelineToken++;

    _clearQueuedEvents();
    _cancelCalmStartTimer();
    _cancelActionEnemyDuckTimer(resetFactor: true);
    _cancelFlipEnemyDuckTimer(resetFactor: true);
    _cancelDevilPriorityActionDuckTimer(resetFactor: true);
    _cancelMazeShiftPriorityFallbackTimer();
    _cancelAlarmPulseTimer();
    _cancelSafeZoneDuckTimer(resetFactor: true);

    await _stopAllLoopAudio(immediate: true);

    for (final voice in _allOneShotVoices()) {
      await _safe('oneshot.stop', () async {
        await voice.player.stop();
      });
      await _safe('oneshot.dispose', () async {
        await voice.player.dispose();
      });
      await voice.completionSubscription?.cancel();
      voice.completionSubscription = null;
    }

    await _safe('calm.dispose', _calmLoop.player.dispose);
    await _safe('devil.dispose', _devilLoop.player.dispose);
    await _safe('alarm.dispose', _lowTimeLoop.player.dispose);

    isMatchActive = false;
    isWon = false;
    isLost = false;
    isPaused = false;
    isCalmPlaying = false;
    isDevilPlaying = false;
    isAlarmPlaying = false;
    _devilThreatActive = false;
    _mazeShiftPriorityActive = false;
    _latestDevilDistance = 99;
    _latestDevilEnabled = false;
    _latestSafeZoneImmune = false;
    _latestDevilRevision = ++_nextDevilRevision;
    _safeZoneEnemyDuck = 1.0;
    _actionEnemyDuck = 1.0;
    _flipEnemyDuck = 1.0;
    _devilPriorityActionDuck = 1.0;
    _matchState = MatchAudioState.exited;

    _emitDebugSnapshot();
  }

  Future<void> _onMatchStart() async {
    _timelineToken++;

    _outcomeEventQueued = false;
    _matchState = MatchAudioState.active;
    isMatchActive = true;
    isWon = false;
    isLost = false;
    isPaused = false;
    _isSafeZoneImmune = false;
    _devilThreatActive = false;
    _secondsLeft = null;
    _devilDistanceTiles = null;
    _latestDevilDistance = 99;
    _latestDevilEnabled = false;
    _latestSafeZoneImmune = false;
    _latestDevilRevision = ++_nextDevilRevision;

    _cancelAlarmPulseTimer();
    _cancelMazeShiftPriorityFallbackTimer();
    _cancelSafeZoneDuckTimer(resetFactor: true);
    _cancelActionEnemyDuckTimer(resetFactor: true);
    _cancelFlipEnemyDuckTimer(resetFactor: true);
    _cancelDevilPriorityActionDuckTimer(resetFactor: true);
    _clearTransientCooldowns();

    _safeZoneEnemyDuck = 1.0;
    _actionEnemyDuck = 1.0;
    _flipEnemyDuck = 1.0;
    _devilPriorityActionDuck = 1.0;
    _mazeShiftPriorityActive = false;
    final enemyBus = _buses[AudioBus.enemy];
    if (enemyBus != null) {
      enemyBus.duck = 1.0;
    }

    await _stopAllLoopAudio(immediate: true);
    await _stopOneShotChannels();
    // Double-stop after a micro-delay handles platform-level race conditions
    // where a one-shot (e.g. game-lost SFX) is still latching at the native
    // audio layer after the first stop call.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await _stopOneShotChannels();

    _queueCalmStart();
    _log('Event handled: matchStart');
  }

  Future<void> _onMatchRestart() async {
    await _onMatchStart();
    _lastEvent = GameAudioEvent.matchRestart.name;
    _emitDebugSnapshot();
    _log('Event handled: matchRestart');
  }

  Future<void> _onMatchPause() async {
    if (isPaused || _matchState == MatchAudioState.exited) {
      return;
    }

    _stateBeforePause = _matchState;
    _matchState = MatchAudioState.paused;
    isPaused = true;

    _pauseCalmStartDelay();

    _calmLoop.resumeAfterPause = _calmLoop.player.playing;
    _devilLoop.resumeAfterPause = false;
    _lowTimeLoop.resumeAfterPause = false;

    await _safe('calm.pause', _calmLoop.player.pause);
    await _stopDevilLoop(immediate: true);
    await _stopLowTimeLoop(immediate: true);

    for (final voice in _allOneShotVoices()) {
      await _safe('oneshot.pause.${voice.bus.name}', () async {
        await voice.player.pause();
      });
    }

    _log('Event handled: matchPause');
  }

  Future<void> _onMatchResume() async {
    if (!isPaused || _matchState == MatchAudioState.exited) {
      return;
    }

    isPaused = false;

    if (_stateBeforePause == MatchAudioState.won ||
        _stateBeforePause == MatchAudioState.lost) {
      _matchState = _stateBeforePause;
    } else {
      _matchState = isMatchActive ? MatchAudioState.active : _stateBeforePause;
    }

    _armCalmStartTimer();

    if (_calmLoop.resumeAfterPause &&
        _canUseMatchAudioLayer &&
        !_isDevilPriorityActive &&
        !_isLowTimePriorityActive) {
      await _safe('calm.resume', _calmLoop.player.play);
    }
    if (_devilLoop.resumeAfterPause && _canUseMatchAudioLayer) {
      await _safe('devil.resume', _devilLoop.player.play);
    }
    if (_lowTimeLoop.resumeAfterPause && _canUseMatchAudioLayer) {
      await _safe('alarm.resume', _lowTimeLoop.player.play);
    }

    await _refreshAllVolumes();
    _log('Event handled: matchResume');
  }

  Future<void> _onMatchExit() async {
    _timelineToken++;

    _outcomeEventQueued = false;
    isMatchActive = false;
    isPaused = false;
    isWon = false;
    isLost = false;
    isCalmPlaying = false;
    isDevilPlaying = false;
    isAlarmPlaying = false;
    _isSafeZoneImmune = false;
    _devilThreatActive = false;
    _secondsLeft = null;
    _devilDistanceTiles = null;
    _latestDevilDistance = 99;
    _latestDevilEnabled = false;
    _latestSafeZoneImmune = false;
    _latestDevilRevision = ++_nextDevilRevision;
    _matchState = MatchAudioState.exited;

    _cancelCalmStartTimer();
    _cancelActionEnemyDuckTimer(resetFactor: true);
    _cancelFlipEnemyDuckTimer(resetFactor: true);
    _cancelDevilPriorityActionDuckTimer(resetFactor: true);
    _cancelMazeShiftPriorityFallbackTimer();
    _cancelAlarmPulseTimer();
    _cancelSafeZoneDuckTimer(resetFactor: true);

    _safeZoneEnemyDuck = 1.0;
    _actionEnemyDuck = 1.0;
    _flipEnemyDuck = 1.0;
    _devilPriorityActionDuck = 1.0;
    _mazeShiftPriorityActive = false;
    final enemyBus = _buses[AudioBus.enemy];
    if (enemyBus != null) {
      enemyBus.duck = 1.0;
    }

    await _stopAllLoopAudio(immediate: true);
    await _stopOneShotChannels();

    _log('Event handled: matchExit');
  }

  Future<void> _onFlipTriggered(int? frameId) async {
    if (!_canPlayGameplaySfx) {
      return;
    }

    if (frameId != null && frameId == _lastFlipFrameId) {
      return;
    }

    _lastFlipFrameId = frameId;

    final playbackRate = 0.985 + (Random().nextDouble() * 0.04);

    final played = await _playOneShot(
      _AudioCue.flip,
      bus: AudioBus.ui,
      baseVolume: _flipBaseVolume,
      playbackRate: playbackRate,
    );

    if (played) {
      return;
    }

    // Production fallback: if the first trigger failed at the plugin layer,
    // retry once on a separate bus pool so every flip still produces feedback.
    await Future<void>.delayed(_flipRetryDelay);
    await _playOneShot(
      _AudioCue.flip,
      bus: AudioBus.action,
      baseVolume: _flipBaseVolume,
      playbackRate: 1.0,
    );
  }

  Future<void> _onDevilDistanceChanged({
    required int? distanceTiles,
    required bool devilEnabled,
    required bool? safeZoneImmune,
    required int devilRevision,
  }) async {
    if (_isStaleDevilRevision(devilRevision)) {
      return;
    }

    _devilDistanceTiles = distanceTiles;
    if (safeZoneImmune != null) {
      _isSafeZoneImmune = safeZoneImmune;
      _latestSafeZoneImmune = safeZoneImmune;
    }

    // Authoritative values come from enqueue-time state, not this potentially
    // stale payload.
    final authDistance = _latestDevilDistance;
    final authEnabled = _latestDevilEnabled;
    final authSafeZoneImmune = _latestSafeZoneImmune;

    final shouldDevilPlay =
        _canUseMatchAudioLayer &&
        authEnabled &&
        !authSafeZoneImmune &&
        authDistance <= _devilStartDistanceTiles;

    final shouldDevilStop =
        !_canUseMatchAudioLayer ||
        !authEnabled ||
        authSafeZoneImmune ||
        authDistance >= _devilStopDistanceTiles;

    if (shouldDevilStop) {
      final wasActive = _devilThreatActive || isDevilPlaying;
      _devilThreatActive = false;
      await _stopDevilLoop(immediate: true);

      if (wasActive &&
          !_isStaleDevilRevision(devilRevision) &&
          _canUseMatchAudioLayer &&
          !_outcomeEventQueued) {
        await _resumeBackgroundAudioAfterThreat();
      }
      return;
    }

    if (!shouldDevilPlay || _isStaleDevilRevision(devilRevision)) {
      return;
    }

    _devilThreatActive = true;

    // Kill competing audio layers.
    if (_calmStartQueued) {
      _cancelCalmStartTimer();
      _calmStartQueued = false;
    }
    if (isCalmPlaying || _calmLoop.player.playing) {
      await _stopCalmLoop(immediate: true);
    }
    if (isAlarmPlaying || _lowTimeLoop.player.playing) {
      await _stopLowTimeLoop(immediate: true);
    }

    if (_isStaleDevilRevision(devilRevision)) {
      return;
    }

    // Start loop if not already running.
    if (!isDevilPlaying) {
      await _startDevilLoop(devilRevision: devilRevision);
    }

    if (!isDevilPlaying || _isStaleDevilRevision(devilRevision)) {
      return;
    }

    if (_mustStopDevilImmediatelyFromLatestState) {
      _devilThreatActive = false;
      await _stopDevilLoop(immediate: true);
      return;
    }

    await _updateDevilLoopVolume(_latestDevilDistance);

    if (_isInCooldown(GameAudioEvent.devilDistanceChanged)) {
      return;
    }

    _markCooldown(GameAudioEvent.devilDistanceChanged, _devilCueCooldown);
    unawaited(_duckActionForDevilCue());
  }

  Future<void> _onMazeShiftStarted() async {
    if (!_canUseMatchAudioLayer || _isOutcomePriorityActive) {
      return;
    }

    _mazeShiftPriorityActive = true;
    _armMazeShiftPriorityFallback();

    if (_calmStartQueued) {
      _cancelCalmStartTimer();
      _calmStartQueued = false;
    }

    await _stopLowTimeLoop(immediate: true);
    await _stopDevilLoop(immediate: true);
    await _stopCalmLoop(immediate: true);
    await _stopOneShotChannels();

    final played = await _playOneShot(
      _AudioCue.mazeShift,
      bus: AudioBus.ui,
      baseVolume: _mazeShiftBaseVolume,
      playbackRate: 1,
    );

    if (!played) {
      await _onMazeShiftEnded();
    }
  }

  Future<void> _onMazeShiftEnded({bool force = false}) async {
    if (!force && _isOneShotCueActive(_AudioCue.mazeShift)) {
      // Keep top priority until the one-shot actually finishes.
      return;
    }

    if (force && _isOneShotCueActive(_AudioCue.mazeShift)) {
      await _stopOneShotCue(_AudioCue.mazeShift);
    }

    _cancelMazeShiftPriorityFallbackTimer();
    final wasActive = _mazeShiftPriorityActive;
    _mazeShiftPriorityActive = false;

    if (!wasActive) {
      return;
    }

    await _resumeAudioAfterMazeShiftPriority();
  }

  Future<void> _resumeAudioAfterMazeShiftPriority() async {
    if (!_canUseMatchAudioLayer || _isOutcomePriorityActive) {
      return;
    }

    final shouldResumeDevil =
        _latestDevilEnabled &&
        !_latestSafeZoneImmune &&
        _latestDevilDistance <= _devilStartDistanceTiles;

    if (shouldResumeDevil) {
      _devilThreatActive = true;
      await _startDevilLoop(devilRevision: _latestDevilRevision);
      if (isDevilPlaying) {
        await _updateDevilLoopVolume(_latestDevilDistance);
      }
      return;
    }

    await _resumeBackgroundAudioAfterThreat();
  }

  void _forceKillMazeShiftPrioritySync() {
    _cancelMazeShiftPriorityFallbackTimer();
    _mazeShiftPriorityActive = false;

    for (final voice in _allOneShotVoices()) {
      if (voice.cue != _AudioCue.mazeShift) {
        continue;
      }
      voice.inUse = false;
      voice.cue = null;
      unawaited(
        _safe('oneshot.forceStop.mazeShift.${voice.bus.name}', () async {
          await voice.player.stop();
        }),
      );
    }
  }

  Future<void> _onSafeZoneEntered() async {
    _isSafeZoneImmune = true;
    _latestSafeZoneImmune = true;
    _latestDevilRevision = ++_nextDevilRevision;

    if (_devilThreatActive || isDevilPlaying || _devilLoop.player.playing) {
      _devilThreatActive = false;
      await _stopDevilLoop(immediate: true);
    }

    if (!_canPlayGameplaySfx) {
      return;
    }

    if (_isInCooldown(GameAudioEvent.safeZoneEntered)) {
      await _refreshAllVolumes();
      return;
    }

    _markCooldown(GameAudioEvent.safeZoneEntered, _safeZoneCooldown);

    if (_safeZoneDuckingEnabled) {
      _cancelSafeZoneDuckTimer(resetFactor: false);
      _safeZoneEnemyDuck = 0.6;
      await _applyEnemyBusDuck();
      _safeZoneDuckTimer = Timer(_safeZoneDuckDuration, () {
        _safeZoneEnemyDuck = 1.0;
        unawaited(_applyEnemyBusDuck());
      });
    }

    await _playOneShot(
      _AudioCue.safeZone,
      bus: AudioBus.ui,
      baseVolume: _safeZoneBaseVolume,
      playbackRate: 1,
    );
  }

  Future<void> _onSafeZoneExited() async {
    _isSafeZoneImmune = false;
    _latestSafeZoneImmune = false;
    _latestDevilRevision = ++_nextDevilRevision;
    await _refreshAllVolumes();
  }

  Future<void> _onTimeChanged(int? secondsLeft) async {
    if (secondsLeft == null) {
      return;
    }

    // Block alarm for BOTH win and loss outcomes — the previous check only
    // covered won, letting a queued timeChanged event restart the alarm after
    // playerLost had already stopped it.
    if (_matchState == MatchAudioState.won ||
        _matchState == MatchAudioState.lost ||
        isWon ||
        isLost ||
        _outcomeEventQueued) {
      if (isAlarmPlaying || _lowTimeLoop.player.playing) {
        await _stopLowTimeLoop(immediate: true);
      }
      return;
    }

    _secondsLeft = secondsLeft;

    if (!_canUseMatchAudioLayer) {
      return;
    }

    if (_isDevilPriorityActive) {
      if (isAlarmPlaying || _lowTimeLoop.player.playing) {
        await _stopLowTimeLoop(immediate: true);
      }
      return;
    }

    final shouldRunLowTimeAlarm = secondsLeft > 0 && secondsLeft <= 10;
    if (shouldRunLowTimeAlarm && !isAlarmPlaying) {
      await _startLowTimeLoop();
    }

    if (isAlarmPlaying) {
      if (isCalmPlaying || _calmLoop.player.playing) {
        await _stopCalmLoop(immediate: true);
      }
      _updateAlarmPulse(secondsLeft);
    }

    if (secondsLeft <= 0 && isAlarmPlaying) {
      await _stopLowTimeLoop(immediate: true);
    }
  }

  Future<void> _onPlayerWon() async {
    if (_matchState == MatchAudioState.exited) {
      return;
    }

    if (_matchState == MatchAudioState.won && isWon) {
      return;
    }

    _timelineToken++;
    isWon = true;
    isLost = false;
    isMatchActive = false;
    isPaused = false;
    _matchState = MatchAudioState.won;
    _outcomeEventQueued = true;
    _devilThreatActive = false;
    _latestDevilEnabled = false;
    _latestDevilDistance = 99;
    _latestSafeZoneImmune = false;
    _latestDevilRevision = ++_nextDevilRevision;

    _cancelCalmStartTimer();
    _cancelMazeShiftPriorityFallbackTimer();
    _cancelAlarmPulseTimer();
    _cancelSafeZoneDuckTimer(resetFactor: true);
    _cancelActionEnemyDuckTimer(resetFactor: true);
    _cancelFlipEnemyDuckTimer(resetFactor: true);
    _cancelDevilPriorityActionDuckTimer(resetFactor: true);
    _mazeShiftPriorityActive = false;
    await _applyEnemyBusDuck();

    await _stopOneShotCue(_AudioCue.mazeShift);
    await _stopLowTimeLoop(immediate: true);
    await _stopDevilLoop(immediate: true);

    if (isCalmPlaying || _calmLoop.player.playing) {
      await _fadeOutCalmOnWin();
    } else {
      await _stopCalmLoop(immediate: true);
    }

    await Future<void>.delayed(_winSafetyDelay);

    await _playOneShot(
      _AudioCue.winning,
      bus: AudioBus.ui,
      baseVolume: _winBaseVolume,
      playbackRate: 1,
    );
  }

  Future<void> _onPlayerLost() async {
    if (!_canUseMatchAudioLayer) {
      return;
    }

    _outcomeEventQueued = true;
    _latestDevilEnabled = false;
    _latestDevilDistance = 99;
    _latestSafeZoneImmune = false;
    _latestDevilRevision = ++_nextDevilRevision;

    _timelineToken++;
    final token = _timelineToken;

    isLost = true;
    isWon = false;
    isMatchActive = false;
    _matchState = MatchAudioState.lost;
    _devilThreatActive = false;

    _cancelCalmStartTimer();
    _cancelFlipEnemyDuckTimer(resetFactor: true);
    _cancelDevilPriorityActionDuckTimer(resetFactor: true);
    _cancelMazeShiftPriorityFallbackTimer();
    _mazeShiftPriorityActive = false;
    await _stopOneShotCue(_AudioCue.mazeShift);
    await _stopLowTimeLoop(immediate: true);
    await _stopDevilLoop(immediate: true);
    await _stopCalmLoop(immediate: true);

    await Future<void>.delayed(_loseSilence);
    if (token != _timelineToken || _matchState != MatchAudioState.lost) {
      return;
    }

    await _playOneShot(
      _AudioCue.playerLost,
      bus: AudioBus.ui,
      baseVolume: _loseBaseVolume,
      playbackRate: 1,
    );
  }

  Future<void> _startCalmLoopFromDelay(int token) async {
    if (token != _timelineToken ||
        !_canUseMatchAudioLayer ||
        _isDevilPriorityActive ||
        _isLowTimePriorityActive ||
        isCalmPlaying ||
        _calmLoop.player.playing) {
      return;
    }

    _calmStartQueued = false;
    _remainingCalmStartDelay = _matchStartDelay;

    final asset = _resolvedAssets[_AudioCue.calmLoop];
    if (asset == null || !_calmLoop.prepared) {
      _log('Calm loop asset unavailable; start skipped');
      return;
    }

    _calmLoop.baseVolume = _calmBaseVolume;
    await _safe('calm.seek0', () async {
      await _calmLoop.player.seek(Duration.zero);
    });

    await _safe('calm.play', _calmLoop.player.play);
    isCalmPlaying = true;

    unawaited(
      _fadeLoopVolume(
        _calmLoop,
        bus: AudioBus.bgm,
        toBaseVolume: _calmBaseVolume,
        duration: _calmFadeInDuration,
      ),
    );
  }

  Future<void> _fadeOutCalmOnWin() async {
    if (!isCalmPlaying) {
      return;
    }

    await _fadeLoopVolume(
      _calmLoop,
      bus: AudioBus.bgm,
      toBaseVolume: 0,
      duration: _calmFadeOutWinDuration,
    );
    await _stopCalmLoop(immediate: true);
  }

  /// Resumes the correct background audio layer after the devil threat ends.
  ///
  /// Priority: low-time alarm > calm loop.  If neither should play (e.g. the
  /// match has ended or another priority is active), this is a no-op.
  Future<void> _resumeBackgroundAudioAfterThreat() async {
    if (!_canUseMatchAudioLayer || _outcomeEventQueued) {
      return;
    }

    // If timer is <= 10s, the alarm takes priority over calm loop.
    final shouldRunLowTimeAlarm =
        _secondsLeft != null && _secondsLeft! > 0 && _secondsLeft! <= 10;
    if (shouldRunLowTimeAlarm && !isAlarmPlaying) {
      await _startLowTimeLoop();
      return;
    }

    // Otherwise resume the calm background loop if nothing else is active.
    if (!_isLowTimePriorityActive &&
        !isCalmPlaying &&
        !_calmLoop.player.playing &&
        !_calmStartQueued) {
      _queueCalmStart();
    }
  }

  Future<void> _startDevilLoop({required int devilRevision}) async {
    if (isDevilPlaying || !_canUseMatchAudioLayer) {
      return;
    }

    if (_isStaleDevilRevision(devilRevision) ||
        _mustStopDevilImmediatelyFromLatestState) {
      _log(
        'Devil start blocked by latest-state-wins (dist=$_latestDevilDistance)',
      );
      return;
    }

    final asset = _resolvedAssets[_AudioCue.devilApproach];
    if (asset == null || !_devilLoop.prepared) {
      _log('Devil loop asset unavailable; start skipped');
      return;
    }

    final targetVolume = _computeDevilLoopBaseVolume(_latestDevilDistance);
    if (targetVolume <= 0) {
      return;
    }

    _devilLoop.baseVolume = targetVolume * 0.3;
    await _safe('devil.seek0', () async {
      await _devilLoop.player.seek(Duration.zero);
    });
    await _setLoopVolume(_devilLoop, AudioBus.enemy);

    if (_isStaleDevilRevision(devilRevision) ||
        _mustStopDevilImmediatelyFromLatestState) {
      await _stopDevilLoop(immediate: true);
      return;
    }

    await _safe('devil.play', _devilLoop.player.play);

    if (_isStaleDevilRevision(devilRevision) ||
        _mustStopDevilImmediatelyFromLatestState) {
      await _stopDevilLoop(immediate: true);
      return;
    }

    isDevilPlaying = true;
    _devilThreatActive = true;

    unawaited(
      _fadeLoopVolume(
        _devilLoop,
        bus: AudioBus.enemy,
        toBaseVolume: targetVolume,
        duration: _devilFadeInDuration,
      ),
    );
  }

  Future<void> _updateDevilLoopVolume(int distanceTiles) async {
    if (!isDevilPlaying) {
      return;
    }

    _devilLoop.baseVolume = _computeDevilLoopBaseVolume(distanceTiles);

    await _setLoopVolume(_devilLoop, AudioBus.enemy);
  }

  double _computeDevilLoopBaseVolume(int distanceTiles) {
    final mapped = _mapDevilDistanceToVolume(distanceTiles);
    if (mapped <= 0) {
      return 0;
    }

    final safeZoneFactor = (_safeZoneHalvesDevilVolume && _isSafeZoneImmune)
        ? 0.5
        : 1.0;
    final alarmPriorityFactor = isAlarmPlaying ? 0.75 : 1.0;

    var target =
        _devilBaseVolume *
        mapped *
        safeZoneFactor *
        alarmPriorityFactor *
        _devilAudibilityBoost;

    if (!_isSafeZoneImmune && distanceTiles <= _devilStartDistanceTiles) {
      target = max(target, _devilMinTriggerVolume);
    }

    return target.clamp(0.0, _devilLoopMaxVolume).toDouble();
  }

  Future<void> _stopDevilLoop({required bool immediate}) async {
    // 1. Cancel any in-flight fade FIRST so it cannot overwrite baseVolume.
    _devilLoop.fadeToken++;

    // 2. Set flags immediately — no async gap before these.
    final wasPlaying = isDevilPlaying || _devilLoop.player.playing;
    isDevilPlaying = false;
    _devilThreatActive = false;
    _cancelDevilPriorityActionDuckTimer(resetFactor: true);

    if (!wasPlaying) {
      // Even if nothing was playing, zero the volume to be safe.
      _devilLoop.baseVolume = 0;
      return;
    }

    // 3. Zero volume at every level.
    _devilLoop.baseVolume = 0;
    await _safe('devil.vol0', () async {
      await _devilLoop.player.setVolume(0);
    });

    if (immediate) {
      await _safe('devil.pause', _devilLoop.player.pause);
      await _safe('devil.stop', _devilLoop.player.stop);
      await _safe('devil.seek0', () async {
        await _devilLoop.player.seek(Duration.zero);
      });
      _log('Devil loop stopped (immediate)');
      return;
    }

    // Non-immediate: already zeroed volume and flags above.
    // Fade is meaningless since volume is already 0; just stop.
    await _safe('devil.pause', _devilLoop.player.pause);
    await _safe('devil.stop', _devilLoop.player.stop);
    _log('Devil loop stopped (non-immediate)');
    _emitDebugSnapshot();
  }

  /// Synchronous-safe inline kill for the devil loop.  Used in handlePayload
  /// where we cannot await but need the loop silenced before any further
  /// queue processing.  Sets all flags and volumes to zero; the actual
  /// player.stop() is fire-and-forget but the audio is already at vol=0.
  void _forceKillDevilLoopSync() {
    _devilLoop.fadeToken++;
    _devilLoop.baseVolume = 0;
    isDevilPlaying = false;
    _devilThreatActive = false;
    _cancelDevilPriorityActionDuckTimer(resetFactor: true);
    unawaited(
      _safe('devil.forceVol0', () async {
        await _devilLoop.player.setVolume(0);
      }),
    );
    unawaited(_safe('devil.forcePause', _devilLoop.player.pause));
    unawaited(_safe('devil.forceStop', _devilLoop.player.stop));
  }

  Future<void> _startLowTimeLoop() async {
    if (_outcomeEventQueued ||
        isAlarmPlaying ||
        !_canUseMatchAudioLayer ||
        _isDevilPriorityActive) {
      return;
    }

    if (_calmStartQueued) {
      _cancelCalmStartTimer();
      _calmStartQueued = false;
    }
    if (isCalmPlaying || _calmLoop.player.playing) {
      await _stopCalmLoop(immediate: true);
    }

    if (!_lowTimeLoop.prepared) {
      _log('Low time loop asset unavailable; start skipped');
      return;
    }

    _lowTimeLoop.baseVolume = _lowTimeBaseVolume;
    await _safe('alarm.seek0', () async {
      await _lowTimeLoop.player.seek(Duration.zero);
    });

    if (_outcomeEventQueued || !_canUseMatchAudioLayer) {
      await _safe('alarm.stopBeforePlay', _lowTimeLoop.player.stop);
      _lowTimeLoop.baseVolume = 0;
      isAlarmPlaying = false;
      return;
    }

    await _safe('alarm.play', _lowTimeLoop.player.play);

    if (_outcomeEventQueued || !_canUseMatchAudioLayer) {
      await _safe('alarm.stopAfterPlay', _lowTimeLoop.player.stop);
      _lowTimeLoop.baseVolume = 0;
      isAlarmPlaying = false;
      return;
    }

    isAlarmPlaying = true;

    _updateAlarmPulse(_secondsLeft ?? 10);
    unawaited(
      _fadeLoopVolume(
        _lowTimeLoop,
        bus: AudioBus.enemy,
        toBaseVolume: _lowTimeLoop.baseVolume,
        duration: _loopDefaultFadeIn,
      ),
    );
  }

  Future<void> _stopLowTimeLoop({required bool immediate}) async {
    if (!isAlarmPlaying && !_lowTimeLoop.player.playing) {
      return;
    }

    _cancelAlarmPulseTimer();

    if (immediate) {
      await _safe('alarm.stop', _lowTimeLoop.player.stop);
    } else {
      await _fadeLoopVolume(
        _lowTimeLoop,
        bus: AudioBus.enemy,
        toBaseVolume: 0,
        duration: _loopDefaultFadeOut,
      );
      await _safe('alarm.stopAfterFade', _lowTimeLoop.player.stop);
    }

    isAlarmPlaying = false;
    _lowTimeLoop.baseVolume = 0;
  }

  Future<void> stopAlarmImmediately() async {
    await _stopLowTimeLoop(immediate: true);
    _emitDebugSnapshot();
  }

  Future<void> _stopCalmLoop({required bool immediate}) async {
    if (!isCalmPlaying && !_calmLoop.player.playing) {
      return;
    }

    if (immediate) {
      await _safe('calm.stop', _calmLoop.player.stop);
    } else {
      await _fadeLoopVolume(
        _calmLoop,
        bus: AudioBus.bgm,
        toBaseVolume: 0,
        duration: _loopDefaultFadeOut,
      );
      await _safe('calm.stopAfterFade', _calmLoop.player.stop);
    }

    isCalmPlaying = false;
    _calmLoop.baseVolume = 0;
  }

  Future<void> _stopAllLoopAudio({required bool immediate}) async {
    await _stopLowTimeLoop(immediate: immediate);
    await _stopDevilLoop(immediate: immediate);
    await _stopCalmLoop(immediate: immediate);
  }

  Iterable<_OneShotVoice> _allOneShotVoices() sync* {
    for (final pool in _oneShotVoicePools.values) {
      for (final voice in pool) {
        yield voice;
      }
    }
  }

  _OneShotVoice? _acquireOneShotVoice(AudioBus bus) {
    final pool = _oneShotVoicePools[bus];
    if (pool == null || pool.isEmpty) {
      return null;
    }

    for (final voice in pool) {
      if (!voice.inUse) {
        return voice;
      }
    }

    var oldest = pool.first;
    for (var i = 1; i < pool.length; i++) {
      final candidate = pool[i];
      if (candidate.startedAt.isBefore(oldest.startedAt)) {
        oldest = candidate;
      }
    }

    return oldest;
  }

  Future<void> _stopOneShotChannels() async {
    for (final voice in _allOneShotVoices()) {
      await _safe('oneshot.stop.${voice.bus.name}', () async {
        await voice.player.stop();
      });
      voice.inUse = false;
      voice.cue = null;
    }
  }

  Future<void> _stopOneShotCue(_AudioCue cue) async {
    for (final voice in _allOneShotVoices()) {
      if (!voice.inUse || voice.cue != cue) {
        continue;
      }
      await _safe('oneshot.stop.${cue.name}.${voice.bus.name}', () async {
        await voice.player.stop();
      });
      voice.inUse = false;
      voice.cue = null;
    }
  }

  bool _isOneShotCueActive(_AudioCue cue) {
    for (final voice in _allOneShotVoices()) {
      if (voice.inUse && voice.cue == cue) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _playOneShot(
    _AudioCue cue, {
    required AudioBus bus,
    required double baseVolume,
    required double playbackRate,
  }) async {
    // Flip cue must remain playable during devil proximity to preserve maze-shift feedback.
    if (cue != _AudioCue.flip && !_isOneShotAllowedForPriority(cue)) {
      _log('Suppressed one-shot ${cue.name} due to active priority layer');
      return false;
    }

    final shouldDuckEnemyBus =
        (bus == AudioBus.ui || bus == AudioBus.action) &&
        cue != _AudioCue.flip &&
        cue != _AudioCue.mazeShift;
    if (shouldDuckEnemyBus) {
      unawaited(_duckEnemyForActionSfx());
    }

    if (cue == _AudioCue.flip && (isDevilPlaying || _devilThreatActive)) {
      unawaited(_duckEnemyForFlipCue());
    }

    final resolved = _resolvedAssets[cue];
    if (resolved == null) {
      _log('Missing one-shot asset for ${cue.name}');
      return false;
    }

    final voice = _acquireOneShotVoice(bus);
    if (voice == null) {
      _log('Missing one-shot pool for ${cue.name} on ${bus.name}');
      return false;
    }

    if (voice.inUse) {
      await _safe('oneshot.steal.${bus.name}', () async {
        await voice.player.stop();
      });
    }

    voice.bus = bus;
    voice.cue = cue;
    voice.baseVolume = baseVolume.clamp(0.0, 1.0).toDouble();
    voice.startedAt = DateTime.now();
    voice.inUse = true;

    final volume = cue == _AudioCue.mazeShift
        ? _maxUnmutedVolumeForBus(bus)
        : _effectiveVolume(bus, voice.baseVolume);

    await _safe('oneshot.rate.${cue.name}', () async {
      await voice.player.setPlaybackRate(playbackRate);
    });

    final played = await _safeBool('oneshot.play.${cue.name}', () async {
      await voice.player
          .play(ap.AssetSource(resolved.sfxPath), volume: volume)
          .timeout(_oneShotPlayTimeout);
    });

    if (!played) {
      voice.inUse = false;
      voice.cue = null;
      return false;
    }

    return true;
  }

  Future<void> _refreshAllVolumes() async {
    await _setLoopVolume(_calmLoop, AudioBus.bgm);
    await _setLoopVolume(_devilLoop, AudioBus.enemy);
    await _setLoopVolume(_lowTimeLoop, AudioBus.enemy);

    for (final voice in _allOneShotVoices()) {
      if (!voice.inUse) {
        continue;
      }
      final effective = voice.cue == _AudioCue.mazeShift
          ? _maxUnmutedVolumeForBus(voice.bus)
          : _effectiveVolume(voice.bus, voice.baseVolume);
      await _safe('oneshot.volume.${voice.bus.name}', () async {
        await voice.player.setVolume(effective);
      });
    }
  }

  Future<void> _setLoopVolume(_LoopChannel channel, AudioBus bus) async {
    final effective = _effectiveVolume(bus, channel.baseVolume);
    await _safe('loop.setVolume.${bus.name}', () async {
      await channel.player.setVolume(effective);
    });
  }

  Future<void> _fadeLoopVolume(
    _LoopChannel channel, {
    required AudioBus bus,
    required double toBaseVolume,
    required Duration duration,
  }) async {
    final from = channel.baseVolume;
    final to = toBaseVolume.clamp(0.0, 1.0).toDouble();
    final token = ++channel.fadeToken;
    final steps = max(1, duration.inMilliseconds ~/ 30);

    for (var i = 1; i <= steps; i++) {
      if (channel.fadeToken != token) {
        return;
      }
      final t = i / steps;
      final eased = t * t * (3 - 2 * t);
      channel.baseVolume = from + (to - from) * eased;
      await _setLoopVolume(channel, bus);
      if (i < steps) {
        await Future<void>.delayed(
          Duration(milliseconds: duration.inMilliseconds ~/ steps),
        );
      }
    }
  }

  double _effectiveVolume(AudioBus bus, double baseVolume) {
    final master = _buses[AudioBus.master];
    final busState = _buses[bus];
    if (master == null || busState == null) {
      return 0;
    }

    if (master.muted || busState.muted) {
      return 0;
    }

    final normalizedBase = baseVolume.clamp(0.0, 1.0).toDouble();
    final devilPriorityDuck = bus == AudioBus.action
        ? _devilPriorityActionDuck
        : 1.0;
    final value =
        normalizedBase *
        master.volume *
        master.duck *
        busState.volume *
        busState.duck *
        devilPriorityDuck;
    return value.clamp(0.0, 1.0).toDouble();
  }

  double _maxUnmutedVolumeForBus(AudioBus bus) {
    final master = _buses[AudioBus.master];
    final busState = _buses[bus];
    if (master == null || busState == null) {
      return 0;
    }

    if (master.muted || busState.muted) {
      return 0;
    }

    return 1.0;
  }

  bool get _canUseMatchAudioLayer {
    return isMatchActive && !isWon && !isLost && !isPaused;
  }

  bool get _canPlayGameplaySfx {
    return _canUseMatchAudioLayer;
  }

  bool get _isOutcomePriorityActive {
    return _outcomeEventQueued ||
        isWon ||
        isLost ||
        _matchState == MatchAudioState.won ||
        _matchState == MatchAudioState.lost;
  }

  bool get _isDevilPriorityActive {
    return !_isOutcomePriorityActive &&
        !_mazeShiftPriorityActive &&
        _devilThreatActive;
  }

  bool get _isLowTimePriorityActive {
    final seconds = _secondsLeft;
    final inWindow = seconds != null && seconds > 0 && seconds <= 10;
    return !_isOutcomePriorityActive &&
        !_mazeShiftPriorityActive &&
        !_isDevilPriorityActive &&
        (isAlarmPlaying || inWindow);
  }

  bool _isOneShotAllowedForPriority(_AudioCue cue) {
    if (_isOutcomePriorityActive) {
      return cue == _AudioCue.winning || cue == _AudioCue.playerLost;
    }
    if (_mazeShiftPriorityActive) {
      return cue == _AudioCue.mazeShift;
    }
    if (_isDevilPriorityActive) {
      return cue == _AudioCue.flip;
    }
    return true;
  }

  void _queueCalmStart() {
    _cancelCalmStartTimer();
    _calmStartQueued = true;
    _remainingCalmStartDelay = _matchStartDelay;
    _armCalmStartTimer();
  }

  void _armCalmStartTimer() {
    if (!_calmStartQueued || !_canUseMatchAudioLayer) {
      return;
    }

    _cancelCalmStartTimer();
    _calmStartStopwatch
      ..reset()
      ..start();

    final token = _timelineToken;
    _calmStartTimer = Timer(_remainingCalmStartDelay, () {
      _calmStartStopwatch.stop();
      unawaited(_startCalmLoopFromDelay(token));
      _emitDebugSnapshot();
    });
  }

  void _pauseCalmStartDelay() {
    if (!_calmStartQueued || _calmStartTimer == null) {
      return;
    }

    final elapsed = _calmStartStopwatch.elapsed;
    _calmStartStopwatch.stop();

    _remainingCalmStartDelay -= elapsed;
    if (_remainingCalmStartDelay.isNegative) {
      _remainingCalmStartDelay = Duration.zero;
    }

    _cancelCalmStartTimer();
  }

  void _cancelCalmStartTimer() {
    _calmStartTimer?.cancel();
    _calmStartTimer = null;
    _calmStartStopwatch.stop();
  }

  void _armMazeShiftPriorityFallback() {
    _cancelMazeShiftPriorityFallbackTimer();
    _mazeShiftPriorityFallbackTimer = Timer(_mazeShiftPriorityFallback, () {
      unawaited(_onMazeShiftEnded(force: true));
    });
  }

  void _cancelMazeShiftPriorityFallbackTimer() {
    _mazeShiftPriorityFallbackTimer?.cancel();
    _mazeShiftPriorityFallbackTimer = null;
  }

  Future<void> _duckEnemyForActionSfx() async {
    _cancelActionEnemyDuckTimer(resetFactor: false);
    _actionEnemyDuckToken += 1;
    final token = _actionEnemyDuckToken;
    _actionEnemyDuck = _actionEnemyDuckFactor;
    await _applyEnemyBusDuck();

    _actionEnemyDuckTimer = Timer(_actionEnemyDuckHold, () {
      unawaited(_releaseActionEnemyDuck(token));
    });
  }

  Future<void> _duckEnemyForFlipCue() async {
    _cancelFlipEnemyDuckTimer(resetFactor: false);
    _flipEnemyDuckToken += 1;
    final token = _flipEnemyDuckToken;
    _flipEnemyDuck = _flipEnemyDuckFactor;
    await _applyEnemyBusDuck();

    _flipEnemyDuckTimer = Timer(_flipEnemyDuckHold, () {
      unawaited(_releaseFlipEnemyDuck(token));
    });
  }

  Future<void> _releaseFlipEnemyDuck(int token) async {
    if (token != _flipEnemyDuckToken) {
      return;
    }

    final from = _flipEnemyDuck;
    final steps = max(1, _flipEnemyDuckRelease.inMilliseconds ~/ 30);
    for (var i = 1; i <= steps; i++) {
      if (token != _flipEnemyDuckToken) {
        return;
      }
      final t = i / steps;
      _flipEnemyDuck = from + (1.0 - from) * t;
      await _applyEnemyBusDuck();
      if (i < steps) {
        await Future<void>.delayed(
          Duration(milliseconds: _flipEnemyDuckRelease.inMilliseconds ~/ steps),
        );
      }
    }
  }

  Future<void> _releaseActionEnemyDuck(int token) async {
    if (token != _actionEnemyDuckToken) {
      return;
    }

    final from = _actionEnemyDuck;
    final steps = max(1, _actionEnemyDuckRelease.inMilliseconds ~/ 30);
    for (var i = 1; i <= steps; i++) {
      if (token != _actionEnemyDuckToken) {
        return;
      }
      final t = i / steps;
      _actionEnemyDuck = from + (1.0 - from) * t;
      await _applyEnemyBusDuck();
      if (i < steps) {
        await Future<void>.delayed(
          Duration(
            milliseconds: _actionEnemyDuckRelease.inMilliseconds ~/ steps,
          ),
        );
      }
    }
  }

  Future<void> _duckActionForDevilCue() async {
    _cancelDevilPriorityActionDuckTimer(resetFactor: false);
    _devilPriorityActionDuckToken += 1;
    final token = _devilPriorityActionDuckToken;
    _devilPriorityActionDuck = _devilPriorityActionDuckFactor;
    await _refreshAllVolumes();
    _emitDebugSnapshot();

    _devilPriorityActionDuckTimer = Timer(_devilPriorityActionDuckHold, () {
      unawaited(_releaseDevilPriorityActionDuck(token));
    });
  }

  Future<void> _releaseDevilPriorityActionDuck(int token) async {
    if (token != _devilPriorityActionDuckToken) {
      return;
    }

    final from = _devilPriorityActionDuck;
    final steps = max(1, _devilPriorityActionDuckRelease.inMilliseconds ~/ 30);
    for (var i = 1; i <= steps; i++) {
      if (token != _devilPriorityActionDuckToken) {
        return;
      }
      final t = i / steps;
      _devilPriorityActionDuck = from + (1.0 - from) * t;
      await _refreshAllVolumes();
      if (i < steps) {
        await Future<void>.delayed(
          Duration(
            milliseconds:
                _devilPriorityActionDuckRelease.inMilliseconds ~/ steps,
          ),
        );
      }
    }
    _emitDebugSnapshot();
  }

  Future<void> _applyEnemyBusDuck() async {
    final enemyBus = _buses[AudioBus.enemy];
    if (enemyBus == null) {
      return;
    }
    enemyBus.duck = min(
      min(_safeZoneEnemyDuck, _actionEnemyDuck),
      _flipEnemyDuck,
    );
    await _refreshAllVolumes();
    _emitDebugSnapshot();
  }

  void _cancelSafeZoneDuckTimer({required bool resetFactor}) {
    _safeZoneDuckTimer?.cancel();
    _safeZoneDuckTimer = null;
    if (resetFactor) {
      _safeZoneEnemyDuck = 1.0;
    }
  }

  void _cancelActionEnemyDuckTimer({required bool resetFactor}) {
    _actionEnemyDuckTimer?.cancel();
    _actionEnemyDuckTimer = null;
    _actionEnemyDuckToken += 1;
    if (resetFactor) {
      _actionEnemyDuck = 1.0;
    }
  }

  void _cancelFlipEnemyDuckTimer({required bool resetFactor}) {
    _flipEnemyDuckTimer?.cancel();
    _flipEnemyDuckTimer = null;
    _flipEnemyDuckToken += 1;
    if (resetFactor) {
      _flipEnemyDuck = 1.0;
    }
  }

  void _cancelDevilPriorityActionDuckTimer({required bool resetFactor}) {
    _devilPriorityActionDuckTimer?.cancel();
    _devilPriorityActionDuckTimer = null;
    _devilPriorityActionDuckToken += 1;
    if (resetFactor) {
      _devilPriorityActionDuck = 1.0;
    }
  }

  void _cancelAlarmPulseTimer() {
    _alarmPulseTimer?.cancel();
    _alarmPulseTimer = null;
    _alarmPulseOn = false;
    _alarmPulseBoost = 0;
    if (_lowTimeLoop.baseVolume > 0) {
      _lowTimeLoop.baseVolume = _lowTimeBaseVolume;
      unawaited(_setLoopVolume(_lowTimeLoop, AudioBus.enemy));
    }
  }

  void _updateAlarmPulse(int secondsLeft) {
    final newBoost = secondsLeft <= 3 ? 0.15 : (secondsLeft <= 5 ? 0.10 : 0.0);

    if (newBoost == _alarmPulseBoost && _alarmPulseTimer != null) {
      return;
    }

    _alarmPulseBoost = newBoost;

    _alarmPulseTimer?.cancel();
    _alarmPulseTimer = null;

    if (_alarmPulseBoost <= 0) {
      _alarmPulseOn = false;
      _lowTimeLoop.baseVolume = _lowTimeBaseVolume;
      unawaited(_setLoopVolume(_lowTimeLoop, AudioBus.enemy));
      return;
    }

    _alarmPulseTimer = Timer.periodic(const Duration(milliseconds: 220), (_) {
      _alarmPulseOn = !_alarmPulseOn;
      final pulseFactor = _alarmPulseOn ? (1 + _alarmPulseBoost) : 1.0;
      _lowTimeLoop.baseVolume = (_lowTimeBaseVolume * pulseFactor)
          .clamp(0.0, 1.0)
          .toDouble();
      unawaited(_setLoopVolume(_lowTimeLoop, AudioBus.enemy));
      _emitDebugSnapshot();
    });
  }

  bool _isInCooldown(GameAudioEvent event) {
    final until = _cooldownUntil[event];
    if (until == null) {
      return false;
    }
    return DateTime.now().isBefore(until);
  }

  void _markCooldown(GameAudioEvent event, Duration duration) {
    _cooldownUntil[event] = DateTime.now().add(duration);
  }

  void _clearTransientCooldowns() {
    _cooldownUntil.remove(GameAudioEvent.flipTriggered);
    _cooldownUntil.remove(GameAudioEvent.safeZoneEntered);
    _cooldownUntil.remove(GameAudioEvent.devilDistanceChanged);
    _lastFlipFrameId = null;
  }

  bool get _mustStopDevilImmediatelyFromLatestState {
    return !_canUseMatchAudioLayer ||
        !_latestDevilEnabled ||
        _latestSafeZoneImmune ||
        _latestDevilDistance >= _devilStopDistanceTiles;
  }

  bool _isStaleDevilRevision(int revision) {
    return revision != _latestDevilRevision;
  }

  double _mapDevilDistanceToVolume(int distanceTiles) {
    // Contract: devil audio is ONLY audible within 6 path-tiles.
    // At 7+ tiles the loop must be silent / stopped — no ghost audio.
    if (distanceTiles >= _devilStopDistanceTiles) {
      return 0.0;
    }
    // Production volume curve per design spec.
    switch (distanceTiles) {
      case 1:
        return 1.00;
      case 2:
        return 0.88;
      case 3:
        return 0.75;
      case 4:
        return 0.65;
      case 5:
        return 0.55;
      case 6:
        return 0.45;
      default:
        return distanceTiles <= 0 ? 1.00 : 0.0;
    }
  }

  Future<void> _resolveAssets() async {
    for (final entry in _assetCandidates.entries) {
      final cue = entry.key;
      final candidates = entry.value;
      _resolvedAssets[cue] = await _resolveCueAsset(cue, candidates);
    }
  }

  Future<_ResolvedAsset?> _resolveCueAsset(
    _AudioCue cue,
    List<String> candidates,
  ) async {
    for (final candidate in candidates) {
      final bundlePath = 'assets/audio/$candidate';
      try {
        await rootBundle.load(bundlePath);
        _log('Resolved ${cue.name}: $candidate');
        return _ResolvedAsset(candidate);
      } catch (_) {
        // Try next candidate.
      }
    }
    _log('Missing assets for ${cue.name}: ${candidates.join(', ')}');
    return null;
  }

  Future<void> _prepareLoopChannel(_LoopChannel channel, _AudioCue cue) async {
    final resolved = _resolvedAssets[cue];
    if (resolved == null) {
      channel.prepared = false;
      return;
    }

    channel.assetPath = resolved.bundlePath;

    await _safe('loop.setAsset.${cue.name}', () async {
      await channel.player.setAsset(resolved.bundlePath);
      await channel.player.setLoopMode(ja.LoopMode.one);
      await channel.player.setVolume(0);
      channel.prepared = true;
    });
  }

  Map<GameAudioEvent, Duration> _activeCooldownSnapshot() {
    final now = DateTime.now();
    final map = <GameAudioEvent, Duration>{};

    for (final entry in _cooldownUntil.entries) {
      final remaining = entry.value.difference(now);
      if (remaining > Duration.zero) {
        map[entry.key] = remaining;
      }
    }

    return map;
  }

  Map<AudioBus, double> _busGainSnapshot() {
    return <AudioBus, double>{
      AudioBus.master: _effectiveVolume(AudioBus.master, 1),
      AudioBus.bgm: _effectiveVolume(AudioBus.bgm, 1),
      AudioBus.ambient: _effectiveVolume(AudioBus.ambient, 1),
      AudioBus.enemy: _effectiveVolume(AudioBus.enemy, 1),
      AudioBus.ui: _effectiveVolume(AudioBus.ui, 1),
      AudioBus.action: _effectiveVolume(AudioBus.action, 1),
    };
  }

  void _emitDebugSnapshot() {
    debugSnapshot.value = AudioDebugSnapshot(
      matchState: _matchState,
      isCalmPlaying: isCalmPlaying,
      isDevilPlaying: isDevilPlaying,
      isAlarmPlaying: isAlarmPlaying,
      isSafeZoneImmune: _isSafeZoneImmune,
      secondsLeft: _secondsLeft,
      devilDistanceTiles: _devilDistanceTiles,
      lastEvent: _lastEvent,
      activeCooldowns: _activeCooldownSnapshot(),
      busGains: _busGainSnapshot(),
    );
  }

  Future<void> _safe(String scope, Future<void> Function() action) async {
    try {
      await action();
    } catch (error, stackTrace) {
      _logError(scope, error, stackTrace);
    }
  }

  Future<bool> _safeBool(String scope, Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (error, stackTrace) {
      _logError(scope, error, stackTrace);
      return false;
    }
  }

  void _log(String message) {
    if (!_debugLogsEnabled) {
      return;
    }
    debugPrint('[AudioManager] $message');
  }

  void _logError(String scope, Object error, [StackTrace? stackTrace]) {
    debugPrint('[AudioManager][ERROR][$scope] $error');
    if (_debugLogsEnabled && stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }
}
