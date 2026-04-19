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
  safeZone,
  lowTimeAlarm,
  winning,
  playerLost,
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
  double baseVolume = 1.0;
}

class _QueuedAudioEvent {
  _QueuedAudioEvent(this.payload, this.completer);

  final GameAudioEventPayload payload;
  final Completer<void> completer;
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
  static const Duration _devilFadeOutDuration = Duration(milliseconds: 180);
  static const Duration _loopDefaultFadeIn = Duration(milliseconds: 150);
  static const Duration _loopDefaultFadeOut = Duration(milliseconds: 160);
  static const Duration _safeZoneDuckDuration = Duration(milliseconds: 500);
  static const Duration _actionEnemyDuckHold = Duration(milliseconds: 220);
  static const Duration _actionEnemyDuckRelease = Duration(milliseconds: 320);

  static const int _devilStartDistanceTiles = 6;
  static const int _devilStopDistanceTiles = 7;
  static const int _devilStartStableTicks = 1;
  static const int _devilStopStableTicks = 1;

  static const bool _safeZoneDuckingEnabled = true;
  static const bool _safeZoneHalvesDevilVolume = true;
  static const int _oneShotVoicesPerBus = 4;

  static const double _calmBaseVolume = 0.45;
  static const double _flipBaseVolume = 1.0;
  static const double _devilBaseVolume = 0.75;
  static const double _devilLoopMaxVolume = 0.52;
  static const double _actionEnemyDuckFactor = 0.30;
  static const double _safeZoneBaseVolume = 0.75;
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
  Timer? _alarmPulseTimer;
  bool _alarmPulseOn = false;
  double _alarmPulseBoost = 0;
  double _safeZoneEnemyDuck = 1.0;
  double _actionEnemyDuck = 1.0;
  int _actionEnemyDuckToken = 0;

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

  int? _secondsLeft;
  int? _lastSecondsLeft;
  int? _devilDistanceTiles;
  int _devilStartStableCount = 0;
  int _devilStopStableCount = 0;

  String _lastEvent = 'idle';

  static const Map<_AudioCue, List<String>> _assetCandidates =
      <_AudioCue, List<String>>{
        _AudioCue.calmLoop: <String>['calm_loop.mp3'],
        _AudioCue.flip: <String>[
          'fahhhh_flippingtime.mp3',
          'fahhhhh_flippingtime.mp3',
        ],
        _AudioCue.devilApproach: <String>['devil_approach.wav'],
        _AudioCue.safeZone: <String>['safe_zone_sound.mp3'],
        _AudioCue.lowTimeAlarm: <String>['low_time_alarm.wav'],
        _AudioCue.winning: <String>['winning_soundeffect.mp3'],
        _AudioCue.playerLost: <String>[
          'playerlost_soundeffect.mp3',
          'gamelost_soundeffect.mp3',
          'game_lost_soundeffect.mp3',
        ],
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
          voice.inUse = false;
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

    if (_isQueueBoundaryEvent(payload.type)) {
      _clearQueuedEvents();
    }

    if (payload.type == GameAudioEvent.devilDistanceChanged) {
      _coalesceQueuedDevilDistanceEvents();
    }

    final queued = _QueuedAudioEvent(payload, completer);
    if (payload.type == GameAudioEvent.flipTriggered ||
        payload.type == GameAudioEvent.playerWon ||
        payload.type == GameAudioEvent.playerLost ||
        payload.type == GameAudioEvent.matchExit) {
      _queue.addFirst(queued);
    } else {
      _queue.add(queued);
    }

    unawaited(_drainQueue());
    return completer.future;
  }

  bool _isQueueBoundaryEvent(GameAudioEvent event) {
    return event == GameAudioEvent.matchStart ||
        event == GameAudioEvent.matchRestart ||
        event == GameAudioEvent.matchExit ||
        event == GameAudioEvent.playerWon ||
        event == GameAudioEvent.playerLost;
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
          await _processEvent(queued.payload);
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

  Future<void> _processEvent(GameAudioEventPayload payload) async {
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
        await _onDevilDistanceChanged(
          distanceTiles: payload.devilDistanceTiles,
          devilEnabled: payload.devilEnabled ?? true,
          safeZoneImmune: payload.safeZoneImmune,
        );
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

    _queue.clear();
    _cancelCalmStartTimer();
    _cancelActionEnemyDuckTimer(resetFactor: true);
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
    _matchState = MatchAudioState.exited;

    _emitDebugSnapshot();
  }

  Future<void> _onMatchStart() async {
    _timelineToken++;

    _matchState = MatchAudioState.active;
    isMatchActive = true;
    isWon = false;
    isLost = false;
    isPaused = false;
    _isSafeZoneImmune = false;
    _secondsLeft = null;
    _lastSecondsLeft = null;
    _devilDistanceTiles = null;
    _devilStartStableCount = 0;
    _devilStopStableCount = 0;

    _cancelAlarmPulseTimer();
    _cancelSafeZoneDuckTimer(resetFactor: true);
    _cancelActionEnemyDuckTimer(resetFactor: true);
    _clearTransientCooldowns();

    _safeZoneEnemyDuck = 1.0;
    _actionEnemyDuck = 1.0;
    final enemyBus = _buses[AudioBus.enemy];
    if (enemyBus != null) {
      enemyBus.duck = 1.0;
    }

    await _stopAllLoopAudio(immediate: true);
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

    if (_calmLoop.resumeAfterPause && _canUseMatchAudioLayer) {
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

    isMatchActive = false;
    isPaused = false;
    isWon = false;
    isLost = false;
    isCalmPlaying = false;
    isDevilPlaying = false;
    isAlarmPlaying = false;
    _isSafeZoneImmune = false;
    _secondsLeft = null;
    _lastSecondsLeft = null;
    _devilDistanceTiles = null;
    _devilStartStableCount = 0;
    _devilStopStableCount = 0;
    _matchState = MatchAudioState.exited;

    _cancelCalmStartTimer();
    _cancelActionEnemyDuckTimer(resetFactor: true);
    _cancelAlarmPulseTimer();
    _cancelSafeZoneDuckTimer(resetFactor: true);

    _safeZoneEnemyDuck = 1.0;
    _actionEnemyDuck = 1.0;
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

    final playbackRate = 0.97 + (Random().nextDouble() * 0.08);
    await _playOneShot(
      _AudioCue.flip,
      bus: AudioBus.action,
      baseVolume: _flipBaseVolume,
      playbackRate: playbackRate,
    );
  }

  Future<void> _onDevilDistanceChanged({
    required int? distanceTiles,
    required bool devilEnabled,
    required bool? safeZoneImmune,
  }) async {
    _devilDistanceTiles = distanceTiles;
    if (safeZoneImmune != null) {
      _isSafeZoneImmune = safeZoneImmune;
    }

    if (!_canUseMatchAudioLayer || !devilEnabled || distanceTiles == null) {
      _devilStartStableCount = 0;
      _devilStopStableCount = 0;
      await _stopDevilLoop(immediate: true);
      return;
    }

    final isCloseToDevil =
        distanceTiles <= _devilStartDistanceTiles && !_isSafeZoneImmune;

    // Devil should not run as a continuous loop; keep it one-shot proximity only.
    await _stopDevilLoop(immediate: true);

    if (!isCloseToDevil) {
      return;
    }

    if (_isInCooldown(GameAudioEvent.devilDistanceChanged)) {
      return;
    }

    _markCooldown(
      GameAudioEvent.devilDistanceChanged,
      const Duration(milliseconds: 850),
    );

    final mapped = _mapDevilDistanceToVolume(distanceTiles);
    final cueVolume = (_devilBaseVolume * mapped).clamp(0.25, 1.0).toDouble();
    final playbackRate = 0.97 + (Random().nextDouble() * 0.06);

    await _playOneShot(
      _AudioCue.devilApproach,
      bus: AudioBus.enemy,
      baseVolume: cueVolume,
      playbackRate: playbackRate,
    );
  }

  Future<void> _onSafeZoneEntered() async {
    _isSafeZoneImmune = true;

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
    await _refreshAllVolumes();
  }

  Future<void> _onTimeChanged(int? secondsLeft) async {
    if (secondsLeft == null) {
      return;
    }

    _secondsLeft = secondsLeft;

    final previous = _lastSecondsLeft;
    _lastSecondsLeft = secondsLeft;

    if (!_canUseMatchAudioLayer) {
      return;
    }

    final crossedToTen =
        (previous == null && secondsLeft == 10) ||
        (previous != null && previous > 10 && secondsLeft == 10);

    if (crossedToTen && !isAlarmPlaying) {
      await _startLowTimeLoop();
    }

    if (isAlarmPlaying) {
      _updateAlarmPulse(secondsLeft);
    }

    if (secondsLeft <= 0 && isAlarmPlaying) {
      await _stopLowTimeLoop(immediate: true);
    }
  }

  Future<void> _onPlayerWon() async {
    if (!_canUseMatchAudioLayer) {
      return;
    }

    _timelineToken++;
    isWon = true;
    isLost = false;
    isMatchActive = false;
    _matchState = MatchAudioState.won;

    _cancelCalmStartTimer();
    await _stopLowTimeLoop(immediate: true);
    await _stopDevilLoop(immediate: true);
    unawaited(_fadeOutCalmOnWin());
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

    _timelineToken++;
    final token = _timelineToken;

    isLost = true;
    isWon = false;
    isMatchActive = false;
    _matchState = MatchAudioState.lost;

    _cancelCalmStartTimer();
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
    if (token != _timelineToken || !_canUseMatchAudioLayer) {
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

  Future<void> _startDevilLoop() async {
    if (isDevilPlaying || !_canUseMatchAudioLayer) {
      return;
    }

    final asset = _resolvedAssets[_AudioCue.devilApproach];
    if (asset == null || !_devilLoop.prepared) {
      _log('Devil loop asset unavailable; start skipped');
      return;
    }

    _devilLoop.baseVolume = 0.25;
    await _safe('devil.seek0', () async {
      await _devilLoop.player.seek(Duration.zero);
    });
    await _safe('devil.play', _devilLoop.player.play);
    isDevilPlaying = true;

    unawaited(
      _fadeLoopVolume(
        _devilLoop,
        bus: AudioBus.enemy,
        toBaseVolume: _devilLoop.baseVolume,
        duration: _devilFadeInDuration,
      ),
    );
  }

  Future<void> _updateDevilLoopVolume(int distanceTiles) async {
    if (!isDevilPlaying) {
      return;
    }

    final mapped = _mapDevilDistanceToVolume(distanceTiles);
    final safeZoneFactor = (_safeZoneHalvesDevilVolume && _isSafeZoneImmune)
        ? 0.5
        : 1.0;
    final alarmPriorityFactor = isAlarmPlaying ? 0.75 : 1.0;

    _devilLoop.baseVolume =
        (_devilBaseVolume * mapped * safeZoneFactor * alarmPriorityFactor)
            .clamp(0.0, _devilLoopMaxVolume)
            .toDouble();

    await _setLoopVolume(_devilLoop, AudioBus.enemy);
  }

  Future<void> _stopDevilLoop({required bool immediate}) async {
    if (!isDevilPlaying && !_devilLoop.player.playing) {
      return;
    }

    if (immediate) {
      await _safe('devil.stop', _devilLoop.player.stop);
      isDevilPlaying = false;
      _devilLoop.baseVolume = 0;
      return;
    }

    isDevilPlaying = false;
    unawaited(() async {
      await _fadeLoopVolume(
        _devilLoop,
        bus: AudioBus.enemy,
        toBaseVolume: 0,
        duration: _devilFadeOutDuration,
      );
      await _safe('devil.stopAfterFade', _devilLoop.player.stop);
      _devilLoop.baseVolume = 0;
      _emitDebugSnapshot();
    }());
  }

  Future<void> _startLowTimeLoop() async {
    if (isAlarmPlaying || !_canUseMatchAudioLayer) {
      return;
    }

    if (!_lowTimeLoop.prepared) {
      _log('Low time loop asset unavailable; start skipped');
      return;
    }

    _lowTimeLoop.baseVolume = _lowTimeBaseVolume;
    await _safe('alarm.seek0', () async {
      await _lowTimeLoop.player.seek(Duration.zero);
    });
    await _safe('alarm.play', _lowTimeLoop.player.play);
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
    }
  }

  Future<void> _playOneShot(
    _AudioCue cue, {
    required AudioBus bus,
    required double baseVolume,
    required double playbackRate,
  }) async {
    if (bus == AudioBus.ui || bus == AudioBus.action) {
      unawaited(_duckEnemyForActionSfx());
    }

    final resolved = _resolvedAssets[cue];
    if (resolved == null) {
      _log('Missing one-shot asset for ${cue.name}');
      return;
    }

    final voice = _acquireOneShotVoice(bus);
    if (voice == null) {
      _log('Missing one-shot pool for ${cue.name} on ${bus.name}');
      return;
    }

    if (voice.inUse) {
      await _safe('oneshot.steal.${bus.name}', () async {
        await voice.player.stop();
      });
    }

    voice.bus = bus;
    voice.baseVolume = baseVolume.clamp(0.0, 1.0).toDouble();
    voice.startedAt = DateTime.now();
    voice.inUse = true;

    final volume = _effectiveVolume(bus, voice.baseVolume);

    await _safe('oneshot.rate.${cue.name}', () async {
      await voice.player.setPlaybackRate(playbackRate);
    });

    await _safe('oneshot.play.${cue.name}', () async {
      await voice.player.play(ap.AssetSource(resolved.sfxPath), volume: volume);
    });
  }

  Future<void> _refreshAllVolumes() async {
    await _setLoopVolume(_calmLoop, AudioBus.bgm);
    await _setLoopVolume(_devilLoop, AudioBus.enemy);
    await _setLoopVolume(_lowTimeLoop, AudioBus.enemy);

    for (final voice in _allOneShotVoices()) {
      if (!voice.inUse) {
        continue;
      }
      final effective = _effectiveVolume(voice.bus, voice.baseVolume);
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
    final value =
        normalizedBase *
        master.volume *
        master.duck *
        busState.volume *
        busState.duck;
    return value.clamp(0.0, 1.0).toDouble();
  }

  bool get _canUseMatchAudioLayer {
    return isMatchActive && !isWon && !isLost && !isPaused;
  }

  bool get _canPlayGameplaySfx {
    return _canUseMatchAudioLayer;
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

  Future<void> _applyEnemyBusDuck() async {
    final enemyBus = _buses[AudioBus.enemy];
    if (enemyBus == null) {
      return;
    }
    enemyBus.duck = min(_safeZoneEnemyDuck, _actionEnemyDuck);
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

  double _mapDevilDistanceToVolume(int distanceTiles) {
    if (distanceTiles <= 1) {
      return 1.0;
    }
    if (distanceTiles == 2) {
      return 0.85;
    }
    if (distanceTiles == 3) {
      return 0.70;
    }
    if (distanceTiles == 4) {
      return 0.55;
    }
    if (distanceTiles == 5) {
      return 0.40;
    }
    if (distanceTiles == 6) {
      return 0.25;
    }
    return 0.0;
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
