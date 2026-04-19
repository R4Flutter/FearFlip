import 'dart:async';
import 'dart:math';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

enum AudioPriority { ambient, gameplay, danger, critical }

enum _AudioCue {
  calmLoop,
  intenseLoop,
  heartbeat,
  flip,
  devilProximity,
  lowTimeAlarm,
  safeZone,
  winningLoop,
  gameLost,
  glitch,
}

enum _AudioState { calm, danger, critical }

class AudioService {
  AudioService() {
    _instances.add(this);
  }

  static final Set<AudioService> _instances = <AudioService>{};
  static double _masterVolume = 1.0;
  static bool _muted = false;

  static const double _minimumAudibleVolume = 0.25;
  static const Duration _crossfadeDuration = Duration(milliseconds: 480);
  static const Duration _fadeOutDuration = Duration(milliseconds: 320);

  static bool _debugAudio = kDebugMode;

  static const Map<_AudioCue, List<String>> _cueCandidates =
      <_AudioCue, List<String>>{
        _AudioCue.calmLoop: <String>[
          'calm_loop.mp3',
          'safe_zone_sound.mp3',
          'wining_soundeffect.mp3',
        ],
        _AudioCue.intenseLoop: <String>[
          'intense_loop.mp3',
          'fahhhhh_flippingtime.mp3',
          'devil_approach.wav',
        ],
        _AudioCue.heartbeat: <String>[
          'heartbeat.mp3',
          'heartbeat.wav',
          'low_time_alarm.wav',
          'low_time_alarm_6s.wav',
          'low_time_alarm (6s left).wav',
          'low_time_alarm_10s.wav',
          'low_time_alaram (10s left).wav',
        ],
        _AudioCue.flip: <String>['fahhhhh_flippingtime.mp3'],
        _AudioCue.devilProximity: <String>[
          'devil_approach.wav',
          'devil_approaching_character.wav',
          'devil is appoarching to chacter.wav',
        ],
        _AudioCue.lowTimeAlarm: <String>[
          'low_time_alarm.wav',
          'low_time_alarm_6s.wav',
          'low_time_alarm (6s left).wav',
          'low_time_alarm_10s.wav',
          'low_time_alaram (10s left).wav',
        ],
        _AudioCue.safeZone: <String>['safe_zone_sound.mp3'],
        _AudioCue.winningLoop: <String>[
          'winning_soundeffect.mp3',
          'wining_soundeffect.mp3',
        ],
        _AudioCue.gameLost: <String>[
          'game_lost_soundeffect.mp3',
          'gamelost_soundeffect.mp3',
        ],
        _AudioCue.glitch: <String>[
          'glitch_screen_sound_effect.mp3',
          'glitch_screen_sound_eefect.mp3',
          'fahhhhh_flippingtime.mp3',
        ],
      };

  static const Map<_AudioCue, List<_AudioCue>>
  _fallbackCues = <_AudioCue, List<_AudioCue>>{
    _AudioCue.calmLoop: <_AudioCue>[_AudioCue.safeZone, _AudioCue.winningLoop],
    _AudioCue.intenseLoop: <_AudioCue>[
      _AudioCue.devilProximity,
      _AudioCue.flip,
    ],
    _AudioCue.heartbeat: <_AudioCue>[_AudioCue.lowTimeAlarm, _AudioCue.flip],
    _AudioCue.glitch: <_AudioCue>[_AudioCue.flip, _AudioCue.devilProximity],
  };

  static const Map<_AudioCue, Duration> _sfxCooldowns = <_AudioCue, Duration>{
    _AudioCue.flip: Duration(milliseconds: 220),
    _AudioCue.safeZone: Duration(milliseconds: 350),
    _AudioCue.glitch: Duration(milliseconds: 300),
    _AudioCue.devilProximity: Duration(milliseconds: 320),
    _AudioCue.lowTimeAlarm: Duration(milliseconds: 450),
  };

  static double get masterVolume => _masterVolume;
  static bool get isMuted => _muted;
  static bool get debugAudio => _debugAudio;

  static Future<void> configureGlobalAudio({
    double? volume,
    bool? muted,
    bool? debugAudio,
  }) async {
    var changed = false;

    if (volume != null) {
      final normalized = volume.clamp(0.0, 1.0).toDouble();
      if ((_masterVolume - normalized).abs() > 0.001) {
        _masterVolume = normalized;
        changed = true;
      }
    }

    if (muted != null && _muted != muted) {
      _muted = muted;
      changed = true;
    }

    if (debugAudio != null && _debugAudio != debugAudio) {
      _debugAudio = debugAudio;
      changed = true;
    }

    if (!changed || _instances.isEmpty) {
      return;
    }

    for (final service in _instances) {
      await service._applyGlobalAudioSettings();
    }
  }

  Future<void>? _initFuture;
  final Map<_AudioCue, String?> _resolvedAssets = <_AudioCue, String?>{};
  final Map<_AudioCue, DateTime> _cooldownUntil = <_AudioCue, DateTime>{};

  bool _calmPlaying = false;
  bool _intensePlaying = false;
  _AudioState _state = _AudioState.calm;
  bool _lowTimeAlarmCuePlaying = false;
  bool _devilApproachPlaying = false;
  bool _heartbeatPlaying = false;
  bool _devilProximityLoopPlaying = false;
  bool _lowTimeAlarmLoopPlaying = false;
  bool _winningTransitionLoopPlaying = false;
  bool _criticalLayerActive = false;

  bool _stateTransitionInProgress = false;
  Future<void> _stateTransitionFuture = Future<void>.value();

  String? _activeBgmAsset;
  AudioPriority _activePriority = AudioPriority.ambient;

  int _bgmTransitionToken = 0;
  int _flipCueToken = 0;
  int _devilDuckToken = 0;
  int _safeZoneCueToken = 0;
  int _gameLostCueToken = 0;
  int _glitchScreenCueToken = 0;

  AudioPlayer? _heartbeatPlayer;
  AudioPlayer? _flipCuePlayer;
  AudioPlayer? _devilProximityLoopPlayer;
  AudioPlayer? _lowTimeAlarmLoopPlayer;
  AudioPlayer? _safeZoneCuePlayer;
  AudioPlayer? _winningTransitionLoopPlayer;
  AudioPlayer? _gameLostCuePlayer;
  AudioPlayer? _glitchScreenCuePlayer;

  double _currentBgmBaseVolume = 0.4;
  double _heartbeatVolume = 0;
  double _smoothedHeartbeatIntensity = 0;
  double _flipCueBaseVolume = 0.92;
  double _devilProximityLoopBaseVolume = 1.0;
  double _lowTimeAlarmLoopBaseVolume = 1.0;
  double _safeZoneCueBaseVolume = 0.95;
  double _winningTransitionLoopBaseVolume = 1.0;
  double _gameLostCueBaseVolume = 1.0;
  double _glitchScreenCueBaseVolume = 1.0;

  Future<void> warmUp() async {
    await preloadAll();
  }

  Future<void> preloadAll() async {
    await _ensureInitialized();
  }

  Future<void> setCriticalGameplayAudioOnly(bool enabled) async {
    // Legacy entrypoint kept for compatibility; priorities now handle layering.
    _trace(
      'setCriticalGameplayAudioOnly($enabled) ignored (priority system active)',
    );
  }

  Future<void> _ensureInitialized() async {
    final existing = _initFuture;
    if (existing != null) {
      await existing;
      return;
    }

    final next = _initializeInternal();
    _initFuture = next;
    await next;
  }

  Future<void> _initializeInternal() async {
    _trace('Initializing audio service and preloading assets');
    await _safeAction('bgm.initialize', FlameAudio.bgm.initialize);
    await _resolveAllCueAssets();
    _trace('Audio preload complete');
  }

  Future<void> _resolveAllCueAssets() async {
    for (final entry in _cueCandidates.entries) {
      final cue = entry.key;
      final candidates = entry.value;
      _resolvedAssets[cue] = await _resolveCueAsset(
        cue: cue,
        candidates: candidates,
      );
    }

    for (final cue in _cueCandidates.keys) {
      final existing = _resolvedAssets[cue];
      if (existing != null) {
        continue;
      }
      final fallback = _resolveFallbackCue(cue);
      if (fallback != null) {
        _resolvedAssets[cue] = fallback;
        _trace('Fallback asset mapped for ${cue.name}: $fallback');
      } else {
        _trace('Missing audio for ${cue.name}; playback will log and skip');
      }
    }
  }

  Future<String?> _resolveCueAsset({
    required _AudioCue cue,
    required List<String> candidates,
  }) async {
    for (var index = 0; index < candidates.length; index++) {
      final asset = candidates[index];
      try {
        await FlameAudio.audioCache.load(asset);
        if (index > 0) {
          _trace('Resolved ${cue.name} with alias filename: $asset');
        } else {
          _trace('Resolved ${cue.name}: $asset');
        }
        return asset;
      } catch (error, stackTrace) {
        _logAudioError('resolve:${cue.name}:$asset', error, stackTrace);
      }
    }
    return null;
  }

  String? _resolveFallbackCue(_AudioCue cue) {
    final fallbackChain = _fallbackCues[cue];
    if (fallbackChain == null || fallbackChain.isEmpty) {
      return null;
    }
    for (final fallbackCue in fallbackChain) {
      final resolved = _resolvedAssets[fallbackCue];
      if (resolved != null) {
        return resolved;
      }
    }
    return null;
  }

  Future<String?> _ensureCueAsset(_AudioCue cue) async {
    await _ensureInitialized();
    final resolved = _resolvedAssets[cue];
    if (resolved != null) {
      return resolved;
    }

    final candidates = _cueCandidates[cue] ?? const <String>[];
    final next = await _resolveCueAsset(cue: cue, candidates: candidates);
    _resolvedAssets[cue] = next ?? _resolveFallbackCue(cue);
    return _resolvedAssets[cue];
  }

  double _effectiveVolume(double baseVolume, {bool applyMinimumFloor = true}) {
    if (_muted) {
      return 0;
    }

    final normalized = baseVolume.clamp(0.0, 1.0).toDouble();
    if (normalized <= 0) {
      return 0;
    }

    final scaled = (normalized * _masterVolume).clamp(0.0, 1.0).toDouble();
    if (!applyMinimumFloor) {
      return scaled;
    }

    return max(_minimumAudibleVolume, scaled).clamp(0.0, 1.0).toDouble();
  }

  bool _canPlay(AudioPriority priority, String scope) {
    if (_criticalLayerActive && priority != AudioPriority.critical) {
      _trace('$scope skipped because critical audio has priority');
      return false;
    }
    return true;
  }

  void _refreshPriority(String reason) {
    final next = _computePriority();
    if (next == _activePriority) {
      return;
    }
    _activePriority = next;
    _trace('Priority -> ${_activePriority.name} ($reason)');
  }

  AudioPriority _computePriority() {
    if (_criticalLayerActive) {
      return AudioPriority.critical;
    }
    if (_state == _AudioState.danger ||
        _devilProximityLoopPlaying ||
        _lowTimeAlarmLoopPlaying ||
        _heartbeatPlaying ||
        _intensePlaying) {
      return AudioPriority.danger;
    }
    return AudioPriority.ambient;
  }

  bool _isInCooldown(_AudioCue cue) {
    final until = _cooldownUntil[cue];
    if (until == null) {
      return false;
    }
    return DateTime.now().isBefore(until);
  }

  void _markCooldown(_AudioCue cue) {
    final cooldown = _sfxCooldowns[cue];
    if (cooldown == null) {
      return;
    }
    _cooldownUntil[cue] = DateTime.now().add(cooldown);
  }

  Future<void> _runWithStateTransitionLock(
    String scope,
    Future<void> Function() action,
  ) async {
    while (_stateTransitionInProgress) {
      await _stateTransitionFuture;
    }

    final completer = Completer<void>();
    _stateTransitionInProgress = true;
    _stateTransitionFuture = completer.future;
    try {
      await action();
    } catch (error, stackTrace) {
      _logAudioError('$scope:stateLock', error, stackTrace);
    } finally {
      _stateTransitionInProgress = false;
      completer.complete();
    }
  }

  Future<void> _transitionState({
    required _AudioState next,
    required String reason,
  }) async {
    await _runWithStateTransitionLock('transitionState:$reason', () async {
      if (!_criticalLayerActive &&
          next != _AudioState.critical &&
          _state == next) {
        final expectedCue = next == _AudioState.calm
            ? _AudioCue.calmLoop
            : _AudioCue.intenseLoop;
        final hasExpectedLayerFlag = next == _AudioState.calm
            ? _calmPlaying
            : _intensePlaying;
        final expectedAsset = await _ensureCueAsset(expectedCue);
        final isExpectedTrackActive =
            expectedAsset != null && _activeBgmAsset == expectedAsset;
        if (isExpectedTrackActive && hasExpectedLayerFlag) {
          _trace('State unchanged (${next.name}) for $reason');
          return;
        }
      }

      final previous = _state;
      _state = next;
      _trace('State: ${previous.name} -> ${_state.name} ($reason)');

      switch (next) {
        case _AudioState.calm:
          _calmPlaying = true;
          _intensePlaying = false;
          await _transitionBgm(
            cue: _AudioCue.calmLoop,
            targetVolume: 0.4,
            scope: 'stateCalm:$reason',
          );
          break;
        case _AudioState.danger:
          _calmPlaying = false;
          _intensePlaying = true;
          await _transitionBgm(
            cue: _AudioCue.intenseLoop,
            targetVolume: 0.62,
            scope: 'stateDanger:$reason',
          );
          break;
        case _AudioState.critical:
          _calmPlaying = false;
          _intensePlaying = false;
          await _stopBgm(scope: 'stateCritical:$reason');
          break;
      }
      _refreshPriority('state:${_state.name}:$reason');
    });
  }

  Future<void> _setPlayerVolume(
    AudioPlayer? player,
    double baseVolume,
    String scope,
  ) async {
    if (player == null) {
      return;
    }
    await _safeAction(scope, () async {
      await player.setVolume(_effectiveVolume(baseVolume));
    });
  }

  Future<void> _applyGlobalAudioSettings() async {
    if (_initFuture == null) {
      return;
    }

    _trace(
      'Applying global settings muted=$_muted masterVolume=${_masterVolume.toStringAsFixed(2)}',
    );

    await _setBgmVolume(
      _currentBgmBaseVolume,
      scope: 'applyGlobalAudioSettings:bgm',
      applyMinimumFloor: false,
    );
    await Future.wait<void>(<Future<void>>[
      _setPlayerVolume(
        _heartbeatPlayer,
        _heartbeatVolume,
        'applyGlobalAudioSettings:heartbeat',
      ),
      _setPlayerVolume(
        _flipCuePlayer,
        _flipCueBaseVolume,
        'applyGlobalAudioSettings:flip',
      ),
      _setPlayerVolume(
        _devilProximityLoopPlayer,
        _devilProximityLoopBaseVolume,
        'applyGlobalAudioSettings:devilLoop',
      ),
      _setPlayerVolume(
        _lowTimeAlarmLoopPlayer,
        _lowTimeAlarmLoopBaseVolume,
        'applyGlobalAudioSettings:alarmLoop',
      ),
      _setPlayerVolume(
        _safeZoneCuePlayer,
        _safeZoneCueBaseVolume,
        'applyGlobalAudioSettings:safeZone',
      ),
      _setPlayerVolume(
        _winningTransitionLoopPlayer,
        _winningTransitionLoopBaseVolume,
        'applyGlobalAudioSettings:winningLoop',
      ),
      _setPlayerVolume(
        _gameLostCuePlayer,
        _gameLostCueBaseVolume,
        'applyGlobalAudioSettings:gameLost',
      ),
      _setPlayerVolume(
        _glitchScreenCuePlayer,
        _glitchScreenCueBaseVolume,
        'applyGlobalAudioSettings:glitch',
      ),
    ]);
  }

  Future<void> _transitionBgm({
    required _AudioCue cue,
    required double targetVolume,
    required String scope,
  }) async {
    final asset = await _ensureCueAsset(cue);
    if (asset == null) {
      _trace('$scope skipped: no asset resolved for ${cue.name}');
      return;
    }

    final normalized = targetVolume.clamp(0.0, 1.0).toDouble();
    final token = ++_bgmTransitionToken;
    final isSameTrack = _activeBgmAsset == asset;

    if (isSameTrack) {
      if ((_currentBgmBaseVolume - normalized).abs() < 0.015) {
        _trace('$scope skipped: BGM already at target volume');
        return;
      }
      await _setBgmVolume(normalized, scope: '$scope:setVolume');
      return;
    }

    await _fadeBgm(
      to: 0,
      duration: _fadeOutDuration,
      token: token,
      scope: '$scope:fadeOut',
    );
    if (token != _bgmTransitionToken) {
      return;
    }

    await _safeAction('$scope:bgm.stop', FlameAudio.bgm.stop);
    if (token != _bgmTransitionToken) {
      return;
    }

    final started = await _safeBool('$scope:bgm.play', () async {
      await FlameAudio.bgm.play(
        asset,
        volume: _effectiveVolume(0.01, applyMinimumFloor: false),
      );
      return true;
    });
    if (!started || token != _bgmTransitionToken) {
      return;
    }

    _activeBgmAsset = asset;
    await _fadeBgm(
      to: normalized,
      duration: _crossfadeDuration,
      token: token,
      scope: '$scope:fadeIn',
    );
  }

  Future<void> _fadeBgm({
    required double to,
    required Duration duration,
    required int token,
    required String scope,
  }) async {
    final from = _currentBgmBaseVolume;
    final target = to.clamp(0.0, 1.0).toDouble();
    final steps = max(1, duration.inMilliseconds ~/ 40);

    for (var i = 1; i <= steps; i++) {
      if (token != _bgmTransitionToken) {
        return;
      }
      final t = i / steps;
      final easedT = t * t * (3 - 2 * t);
      final next = from + (target - from) * easedT;
      await _setBgmVolume(
        next,
        scope: '$scope:step$i',
        applyMinimumFloor: false,
      );
      if (i < steps) {
        await Future<void>.delayed(
          Duration(milliseconds: duration.inMilliseconds ~/ steps),
        );
      }
    }
  }

  Future<void> playCalm() async {
    await _ensureInitialized();
    if (!_canPlay(AudioPriority.ambient, 'playCalm')) {
      return;
    }

    _trace('Event: calm');
    await _transitionState(next: _AudioState.calm, reason: 'playCalm');
  }

  Future<void> playIntense() async {
    await _ensureInitialized();
    if (!_canPlay(AudioPriority.danger, 'playIntense')) {
      return;
    }

    _trace('Event: danger-intense');
    await _transitionState(next: _AudioState.danger, reason: 'playIntense');
  }

  Future<void> setHeartbeatIntensity(double intensity) async {
    await _ensureInitialized();
    if (!_canPlay(AudioPriority.danger, 'setHeartbeatIntensity')) {
      await _stopHeartbeatInternal();
      return;
    }

    final clamped = intensity.clamp(0.0, 1.0).toDouble();
    _smoothedHeartbeatIntensity = clamped <= 0.01
        ? 0
        : (_smoothedHeartbeatIntensity * 0.78 + clamped * 0.22)
              .clamp(0.0, 1.0)
              .toDouble();
    final target = _smoothedHeartbeatIntensity < 0.08
        ? 0.0
        : (0.3 + _smoothedHeartbeatIntensity * 0.55).clamp(0.0, 1.0).toDouble();

    _trace(
      'Event: heartbeat intensity=${clamped.toStringAsFixed(2)} smoothed=${_smoothedHeartbeatIntensity.toStringAsFixed(2)} target=${target.toStringAsFixed(2)}',
    );

    if (target <= 0) {
      await _stopHeartbeatInternal();
      _refreshPriority('heartbeatStop');
      return;
    }

    if (!_criticalLayerActive && _state != _AudioState.danger) {
      await _transitionState(
        next: _AudioState.danger,
        reason: 'heartbeatIntensity',
      );
    }

    final asset = await _ensureCueAsset(_AudioCue.heartbeat);
    if (asset == null) {
      _trace('setHeartbeatIntensity skipped: no heartbeat asset');
      return;
    }

    final player = _heartbeatPlayer;
    if (player == null) {
      final created = await _safeCreateLoopPlayer(
        asset: asset,
        baseVolume: target,
        scope: 'setHeartbeatIntensity:start',
      );
      if (created == null) {
        return;
      }
      _heartbeatPlayer = created;
      _heartbeatVolume = target;
      _heartbeatPlaying = true;
      _refreshPriority('heartbeatStart');
      return;
    }

    if ((target - _heartbeatVolume).abs() < 0.02) {
      return;
    }

    await _safeAction('setHeartbeatIntensity:update', () async {
      await player.setVolume(_effectiveVolume(target));
      _heartbeatVolume = target;
      _heartbeatPlaying = true;
    });
    _refreshPriority('heartbeatUpdate');
  }

  Future<void> playFlipCue({double volume = 0.92}) async {
    await _ensureInitialized();
    if (!_canPlay(AudioPriority.gameplay, 'playFlipCue')) {
      return;
    }
    if (_isInCooldown(_AudioCue.flip)) {
      _trace('playFlipCue skipped due to cooldown');
      return;
    }
    _markCooldown(_AudioCue.flip);

    final asset = await _ensureCueAsset(_AudioCue.flip);
    if (asset == null) {
      _trace('playFlipCue skipped: no flip asset');
      return;
    }

    _trace('Event: flip');
    _flipCueBaseVolume = volume.clamp(0.0, 1.0).toDouble();
    final token = ++_flipCueToken;

    final previous = _flipCuePlayer;
    _flipCuePlayer = null;
    await _stopAndDisposePlayer(previous, 'playFlipCue:cleanupPrevious');

    final player = await _safeCreateLongPlayer(
      asset: asset,
      baseVolume: _flipCueBaseVolume,
      scope: 'playFlipCue:playLong',
    );

    if (player == null) {
      await _safeAction('playFlipCue:fallback', () async {
        await FlameAudio.play(
          asset,
          volume: _effectiveVolume(_flipCueBaseVolume),
        );
      });
      return;
    }

    if (token != _flipCueToken) {
      await _stopAndDisposePlayer(player, 'playFlipCue:staleToken');
      return;
    }

    _flipCuePlayer = player;
    _attachCompletion(
      player: player,
      scope: 'playFlipCue',
      onComplete: () async {
        if (token != _flipCueToken || !identical(_flipCuePlayer, player)) {
          return;
        }
        _flipCuePlayer = null;
      },
    );
  }

  Future<void> _stopFlipCueInternal() async {
    ++_flipCueToken;
    final player = _flipCuePlayer;
    _flipCuePlayer = null;
    await _stopAndDisposePlayer(player, 'stopFlipCue');
  }

  Future<void> playSafeZoneCue({
    Duration maxDuration = const Duration(seconds: 1),
    double volume = 0.95,
  }) async {
    await _ensureInitialized();
    if (!_canPlay(AudioPriority.gameplay, 'playSafeZoneCue')) {
      return;
    }
    if (_isInCooldown(_AudioCue.safeZone)) {
      _trace('playSafeZoneCue skipped due to cooldown');
      return;
    }
    _markCooldown(_AudioCue.safeZone);

    final asset = await _ensureCueAsset(_AudioCue.safeZone);
    if (asset == null) {
      _trace('playSafeZoneCue skipped: no safe-zone asset');
      return;
    }

    _trace('Event: enter-safe-zone');
    _safeZoneCueBaseVolume = volume.clamp(0.0, 1.0).toDouble();

    final token = ++_safeZoneCueToken;
    final previous = _safeZoneCuePlayer;
    _safeZoneCuePlayer = null;
    await _stopAndDisposePlayer(previous, 'playSafeZoneCue:cleanupPrevious');

    final player = await _safeCreateLongPlayer(
      asset: asset,
      baseVolume: _safeZoneCueBaseVolume,
      scope: 'playSafeZoneCue:playLong',
    );

    if (player == null) {
      await _safeAction('playSafeZoneCue:fallback', () async {
        await FlameAudio.play(
          asset,
          volume: _effectiveVolume(_safeZoneCueBaseVolume),
        );
      });
      return;
    }

    if (token != _safeZoneCueToken) {
      await _stopAndDisposePlayer(player, 'playSafeZoneCue:staleToken');
      return;
    }

    _safeZoneCuePlayer = player;

    unawaited(
      Future<void>.delayed(maxDuration, () async {
        if (token != _safeZoneCueToken ||
            !identical(_safeZoneCuePlayer, player)) {
          return;
        }
        _safeZoneCuePlayer = null;
        await _stopAndDisposePlayer(player, 'playSafeZoneCue:timedStop');
      }),
    );

    _attachCompletion(
      player: player,
      scope: 'playSafeZoneCue',
      onComplete: () async {
        if (!identical(_safeZoneCuePlayer, player)) {
          return;
        }
        _safeZoneCuePlayer = null;
      },
    );
  }

  Future<void> stopSafeZoneCue() async {
    ++_safeZoneCueToken;
    final player = _safeZoneCuePlayer;
    _safeZoneCuePlayer = null;
    await _stopAndDisposePlayer(player, 'stopSafeZoneCue');
  }

  Future<void> startWinningTransitionLoop({double volume = 1.0}) async {
    await _ensureInitialized();

    _trace('Event: win');
    await _enterCriticalLayer('startWinningTransitionLoop');

    ++_gameLostCueToken;
    final gameLostPlayer = _gameLostCuePlayer;
    _gameLostCuePlayer = null;
    await _stopAndDisposePlayer(
      gameLostPlayer,
      'startWinningTransitionLoop:stopGameLostCue',
    );

    final asset = await _ensureCueAsset(_AudioCue.winningLoop);
    if (asset == null) {
      _trace('startWinningTransitionLoop skipped: no winning asset');
      return;
    }

    _winningTransitionLoopBaseVolume = volume.clamp(0.0, 1.0).toDouble();

    if (_winningTransitionLoopPlaying) {
      await _setPlayerVolume(
        _winningTransitionLoopPlayer,
        _winningTransitionLoopBaseVolume,
        'startWinningTransitionLoop:updateVolume',
      );
      return;
    }

    _winningTransitionLoopPlaying = true;
    final player = await _safeCreateLoopPlayer(
      asset: asset,
      baseVolume: _winningTransitionLoopBaseVolume,
      scope: 'startWinningTransitionLoop:start',
    );

    if (player == null) {
      _winningTransitionLoopPlaying = false;
      _trace('startWinningTransitionLoop failed to start loop');
      return;
    }

    _winningTransitionLoopPlayer = player;
    _refreshPriority('winningLoopStart');
  }

  Future<void> stopWinningTransitionLoop() async {
    _winningTransitionLoopPlaying = false;
    final player = _winningTransitionLoopPlayer;
    _winningTransitionLoopPlayer = null;
    await _stopAndDisposePlayer(player, 'stopWinningTransitionLoop');

    if (_criticalLayerActive && _gameLostCuePlayer == null) {
      await _exitCriticalLayer('stopWinningTransitionLoop');
    }
  }

  Future<void> playGameLostCue({double volume = 1.0}) async {
    await _ensureInitialized();

    _trace('Event: lose');
    await _enterCriticalLayer('playGameLostCue');

    _winningTransitionLoopPlaying = false;
    final winningPlayer = _winningTransitionLoopPlayer;
    _winningTransitionLoopPlayer = null;
    await _stopAndDisposePlayer(
      winningPlayer,
      'playGameLostCue:stopWinningLoop',
    );

    final asset = await _ensureCueAsset(_AudioCue.gameLost);
    if (asset == null) {
      _trace('playGameLostCue skipped: no game-lost asset');
      return;
    }

    _gameLostCueBaseVolume = volume.clamp(0.0, 1.0).toDouble();

    final token = ++_gameLostCueToken;
    final previous = _gameLostCuePlayer;
    _gameLostCuePlayer = null;
    await _stopAndDisposePlayer(previous, 'playGameLostCue:cleanupPrevious');

    final player = await _safeCreateLongPlayer(
      asset: asset,
      baseVolume: _gameLostCueBaseVolume,
      scope: 'playGameLostCue:playLong',
    );

    if (player == null) {
      await _safeAction('playGameLostCue:fallback', () async {
        await FlameAudio.play(
          asset,
          volume: _effectiveVolume(_gameLostCueBaseVolume),
        );
      });
      await _exitCriticalLayer('playGameLostCue:fallbackComplete');
      return;
    }

    if (token != _gameLostCueToken) {
      await _stopAndDisposePlayer(player, 'playGameLostCue:staleToken');
      return;
    }

    _gameLostCuePlayer = player;
    _attachCompletion(
      player: player,
      scope: 'playGameLostCue',
      onComplete: () async {
        if (!identical(_gameLostCuePlayer, player)) {
          return;
        }
        _gameLostCuePlayer = null;
        await _exitCriticalLayer('playGameLostCue:onComplete');
      },
    );
    _refreshPriority('gameLostCueStart');
  }

  Future<void> stopGameLostCue() async {
    ++_gameLostCueToken;
    final player = _gameLostCuePlayer;
    _gameLostCuePlayer = null;
    await _stopAndDisposePlayer(player, 'stopGameLostCue');

    if (_criticalLayerActive && !_winningTransitionLoopPlaying) {
      await _exitCriticalLayer('stopGameLostCue');
    }
  }

  Future<void> playGlitchScreenCue({double volume = 1.0}) async {
    await _ensureInitialized();
    if (!_canPlay(AudioPriority.critical, 'playGlitchScreenCue')) {
      return;
    }
    if (_isInCooldown(_AudioCue.glitch)) {
      _trace('playGlitchScreenCue skipped due to cooldown');
      return;
    }
    _markCooldown(_AudioCue.glitch);

    final asset = await _ensureCueAsset(_AudioCue.glitch);
    if (asset == null) {
      _trace('playGlitchScreenCue skipped: no glitch asset');
      return;
    }

    _trace('Event: maze-shift-glitch');
    _glitchScreenCueBaseVolume = volume.clamp(0.0, 1.0).toDouble();
    final token = ++_glitchScreenCueToken;

    final previous = _glitchScreenCuePlayer;
    _glitchScreenCuePlayer = null;
    await _stopAndDisposePlayer(
      previous,
      'playGlitchScreenCue:cleanupPrevious',
    );

    final player = await _safeCreateLongPlayer(
      asset: asset,
      baseVolume: _glitchScreenCueBaseVolume,
      scope: 'playGlitchScreenCue:playLong',
    );

    if (player == null) {
      await _safeAction('playGlitchScreenCue:fallback', () async {
        await FlameAudio.play(
          asset,
          volume: _effectiveVolume(_glitchScreenCueBaseVolume),
        );
      });
      return;
    }

    if (token != _glitchScreenCueToken) {
      await _stopAndDisposePlayer(player, 'playGlitchScreenCue:staleToken');
      return;
    }

    _glitchScreenCuePlayer = player;
    _attachCompletion(
      player: player,
      scope: 'playGlitchScreenCue',
      onComplete: () async {
        if (token != _glitchScreenCueToken ||
            !identical(_glitchScreenCuePlayer, player)) {
          return;
        }
        _glitchScreenCuePlayer = null;
      },
    );
  }

  Future<void> _stopGlitchScreenCueInternal() async {
    ++_glitchScreenCueToken;
    final player = _glitchScreenCuePlayer;
    _glitchScreenCuePlayer = null;
    await _stopAndDisposePlayer(player, 'stopGlitchScreenCue');
  }

  Future<void> startDevilProximityLoop({double volume = 1.0}) async {
    await _ensureInitialized();
    if (!_canPlay(AudioPriority.danger, 'startDevilProximityLoop')) {
      return;
    }

    final asset = await _ensureCueAsset(_AudioCue.devilProximity);
    if (asset == null) {
      _trace('startDevilProximityLoop skipped: no devil-proximity asset');
      return;
    }

    _trace('Event: danger-proximity-start');
    _devilProximityLoopBaseVolume = volume.clamp(0.0, 1.0).toDouble();

    if (_devilProximityLoopPlaying && _devilProximityLoopPlayer != null) {
      await _setPlayerVolume(
        _devilProximityLoopPlayer,
        _devilProximityLoopBaseVolume,
        'startDevilProximityLoop:updateVolume',
      );
      await playIntense();
      return;
    }

    _devilProximityLoopPlaying = true;
    final token = ++_devilDuckToken;
    final player = await _safeCreateLoopPlayer(
      asset: asset,
      baseVolume: _devilProximityLoopBaseVolume,
      scope: 'startDevilProximityLoop:start',
    );

    if (!_devilProximityLoopPlaying || token != _devilDuckToken) {
      await _stopAndDisposePlayer(player, 'startDevilProximityLoop:stale');
      return;
    }

    if (player == null) {
      _devilProximityLoopPlaying = false;
      _refreshPriority('devilLoopStartFailed');
      return;
    }

    _devilProximityLoopPlayer = player;
    _refreshPriority('devilLoopStart');
    await playIntense();
  }

  Future<void> stopDevilProximityLoop() async {
    ++_devilDuckToken;
    _devilProximityLoopPlaying = false;
    final player = _devilProximityLoopPlayer;
    _devilProximityLoopPlayer = null;
    await _stopAndDisposePlayer(player, 'stopDevilProximityLoop');

    _refreshPriority('devilLoopStop');
    if (!_lowTimeAlarmLoopPlaying && !_criticalLayerActive) {
      await playCalm();
    }
  }

  Future<void> startLowTimeAlarmLoop({double volume = 1.0}) async {
    await _ensureInitialized();
    if (!_canPlay(AudioPriority.danger, 'startLowTimeAlarmLoop')) {
      return;
    }

    final asset = await _ensureCueAsset(_AudioCue.lowTimeAlarm);
    if (asset == null) {
      _trace('startLowTimeAlarmLoop skipped: no low-time asset');
      return;
    }

    _trace('Event: low-time-start');
    _lowTimeAlarmLoopBaseVolume = volume.clamp(0.0, 1.0).toDouble();

    if (_lowTimeAlarmLoopPlaying && _lowTimeAlarmLoopPlayer != null) {
      await _setPlayerVolume(
        _lowTimeAlarmLoopPlayer,
        _lowTimeAlarmLoopBaseVolume,
        'startLowTimeAlarmLoop:updateVolume',
      );
      _refreshPriority('lowTimeLoopVolumeUpdate');
      if (!_criticalLayerActive) {
        await _transitionState(
          next: _AudioState.danger,
          reason: 'startLowTimeAlarmLoop:updateVolume',
        );
      }
      return;
    }

    _lowTimeAlarmLoopPlaying = true;
    final player = await _safeCreateLoopPlayer(
      asset: asset,
      baseVolume: _lowTimeAlarmLoopBaseVolume,
      scope: 'startLowTimeAlarmLoop:start',
    );

    if (!_lowTimeAlarmLoopPlaying) {
      await _stopAndDisposePlayer(player, 'startLowTimeAlarmLoop:stale');
      return;
    }

    _lowTimeAlarmLoopPlayer = player;
    if (player == null) {
      _lowTimeAlarmLoopPlaying = false;
    }
    _refreshPriority('lowTimeLoopStart');
    if (player != null && !_criticalLayerActive) {
      await _transitionState(
        next: _AudioState.danger,
        reason: 'startLowTimeAlarmLoop:start',
      );
    }
  }

  Future<void> stopLowTimeAlarmLoop() async {
    _lowTimeAlarmLoopPlaying = false;
    final player = _lowTimeAlarmLoopPlayer;
    _lowTimeAlarmLoopPlayer = null;
    await _stopAndDisposePlayer(player, 'stopLowTimeAlarmLoop');
    _refreshPriority('lowTimeLoopStop');
    if (!_criticalLayerActive &&
        !_devilProximityLoopPlaying &&
        !_heartbeatPlaying) {
      await _transitionState(
        next: _AudioState.calm,
        reason: 'stopLowTimeAlarmLoop',
      );
    }
  }

  Future<void> playLowTimeAlarm() async {
    await _ensureInitialized();
    if (_lowTimeAlarmCuePlaying || _lowTimeAlarmLoopPlaying) {
      return;
    }
    if (_isInCooldown(_AudioCue.lowTimeAlarm)) {
      _trace('playLowTimeAlarm skipped due to cooldown');
      return;
    }
    _markCooldown(_AudioCue.lowTimeAlarm);

    final asset = await _ensureCueAsset(_AudioCue.lowTimeAlarm);
    if (asset == null) {
      _trace('playLowTimeAlarm skipped: no low-time asset');
      return;
    }

    _trace('Event: low-time-cue');
    _lowTimeAlarmCuePlaying = true;
    await _safeAction('playLowTimeAlarm', () async {
      await _playOneShotCue(
        asset: asset,
        baseVolume: 1.0,
        scope: 'playLowTimeAlarm',
      );
    });
    _lowTimeAlarmCuePlaying = false;
  }

  Future<void> playDevilApproachingCue() async {
    await _ensureInitialized();
    if (_devilApproachPlaying || _devilProximityLoopPlaying) {
      return;
    }
    if (!_canPlay(AudioPriority.danger, 'playDevilApproachingCue')) {
      return;
    }
    if (_isInCooldown(_AudioCue.devilProximity)) {
      _trace('playDevilApproachingCue skipped due to cooldown');
      return;
    }
    _markCooldown(_AudioCue.devilProximity);

    final asset = await _ensureCueAsset(_AudioCue.devilProximity);
    if (asset == null) {
      _trace('playDevilApproachingCue skipped: no devil asset');
      return;
    }

    _trace('Event: devil-approaching-cue');
    _devilApproachPlaying = true;
    final token = ++_devilDuckToken;
    await _playOneShotCue(
      asset: asset,
      baseVolume: 1.0,
      scope: 'playDevilApproachingCue',
    );
    _devilApproachPlaying = false;

    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 600), () async {
        if (token != _devilDuckToken || _criticalLayerActive) {
          return;
        }
        if (_devilProximityLoopPlaying) {
          await playIntense();
        } else {
          await playCalm();
        }
      }),
    );
  }

  Future<void> _enterCriticalLayer(String scope) async {
    if (_criticalLayerActive && _state == _AudioState.critical) {
      _trace('Critical layer already active ($scope)');
    }
    _criticalLayerActive = true;
    await _transitionState(next: _AudioState.critical, reason: '$scope:enter');
    await _stopNonCriticalLayers(scope: '$scope:stopNonCritical');
  }

  Future<void> _exitCriticalLayer(String scope) async {
    _criticalLayerActive = false;
    _state =
        (_devilProximityLoopPlaying ||
            _lowTimeAlarmLoopPlaying ||
            _heartbeatPlaying)
        ? _AudioState.danger
        : _AudioState.calm;
    _trace('State -> ${_state.name} ($scope:exitCritical)');
    _refreshPriority('$scope:exitCritical');
  }

  Future<void> _stopNonCriticalLayers({required String scope}) async {
    _trace(scope);
    await Future.wait<void>(<Future<void>>[
      _stopFlipCueInternal(),
      stopSafeZoneCue(),
      stopDevilProximityLoop(),
      stopLowTimeAlarmLoop(),
      _stopHeartbeatInternal(),
      _stopGlitchScreenCueInternal(),
    ]);
  }

  Future<void> _stopHeartbeatInternal() async {
    _heartbeatPlaying = false;
    _heartbeatVolume = 0;
    _smoothedHeartbeatIntensity = 0;
    final player = _heartbeatPlayer;
    _heartbeatPlayer = null;
    await _stopAndDisposePlayer(player, 'stopHeartbeatInternal');
    _refreshPriority('heartbeatStopInternal');
  }

  Future<void> _playOneShotCue({
    required String asset,
    required double baseVolume,
    required String scope,
  }) async {
    final longPlayer = await _safeCreateLongPlayer(
      asset: asset,
      baseVolume: baseVolume,
      scope: '$scope:playLong',
    );
    if (longPlayer != null) {
      _attachCompletion(player: longPlayer, scope: scope);
      return;
    }

    await _safeAction('$scope:playFallback', () async {
      await FlameAudio.play(asset, volume: _effectiveVolume(baseVolume));
    });
  }

  Future<AudioPlayer?> _safeCreateLongPlayer({
    required String asset,
    required double baseVolume,
    required String scope,
  }) async {
    try {
      final player = await FlameAudio.playLongAudio(
        asset,
        volume: _effectiveVolume(baseVolume),
      );
      return player;
    } catch (error, stackTrace) {
      _logAudioError(scope, error, stackTrace);
      return null;
    }
  }

  Future<AudioPlayer?> _safeCreateLoopPlayer({
    required String asset,
    required double baseVolume,
    required String scope,
  }) async {
    try {
      final player = await FlameAudio.loop(
        asset,
        volume: _effectiveVolume(baseVolume),
      );
      return player;
    } catch (error, stackTrace) {
      _logAudioError(scope, error, stackTrace);
      return null;
    }
  }

  void _attachCompletion({
    required AudioPlayer player,
    required String scope,
    Future<void> Function()? onComplete,
  }) {
    unawaited(
      player.onPlayerComplete.first
          .then((_) async {
            if (onComplete != null) {
              await onComplete();
            }
            await _safeAction('$scope:dispose', () async {
              await player.dispose();
            });
          })
          .catchError((Object error, StackTrace stackTrace) {
            _logAudioError('$scope:onComplete', error, stackTrace);
          }),
    );
  }

  Future<void> _stopAndDisposePlayer(AudioPlayer? player, String scope) async {
    if (player == null) {
      return;
    }
    await _safeAction('$scope:stop', () async {
      await player.stop();
    });
    await _safeAction('$scope:dispose', () async {
      await player.dispose();
    });
  }

  Future<void> _setBgmVolume(
    double volume, {
    String scope = '_setBgmVolume',
    bool applyMinimumFloor = true,
  }) async {
    _currentBgmBaseVolume = volume.clamp(0.0, 1.0).toDouble();
    final effective = _effectiveVolume(
      _currentBgmBaseVolume,
      applyMinimumFloor: applyMinimumFloor,
    );
    await _safeAction(scope, () async {
      await FlameAudio.bgm.audioPlayer.setVolume(effective);
    });
    if (!scope.contains(':step')) {
      _trace(
        'BGM volume -> base=${_currentBgmBaseVolume.toStringAsFixed(2)} effective=${effective.toStringAsFixed(2)} ($scope)',
      );
    }
  }

  Future<void> _stopBgm({String scope = '_stopBgm'}) async {
    _activeBgmAsset = null;
    _currentBgmBaseVolume = 0;
    await _safeAction(scope, FlameAudio.bgm.stop);
  }

  Future<bool> _safeBool(String scope, Future<bool> Function() action) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      _logAudioError(scope, error, stackTrace);
      return false;
    }
  }

  Future<void> _safeAction(String scope, Future<void> Function() action) async {
    try {
      await action();
    } catch (error, stackTrace) {
      _logAudioError(scope, error, stackTrace);
    }
  }

  void _trace(String message) {
    if (!_debugAudio) {
      return;
    }
    debugPrint('[Audio] $message');
  }

  void _logAudioError(String scope, Object error, [StackTrace? stackTrace]) {
    debugPrint('[Audio][ERROR][$scope] $error');
    if (_debugAudio && stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  Future<void> stopAll() async {
    await _ensureInitialized();

    _trace('Event: stopAll');
    _calmPlaying = false;
    _intensePlaying = false;
    _lowTimeAlarmCuePlaying = false;
    _devilApproachPlaying = false;
    _heartbeatPlaying = false;
    _devilProximityLoopPlaying = false;
    _lowTimeAlarmLoopPlaying = false;
    _winningTransitionLoopPlaying = false;
    _criticalLayerActive = false;
    _state = _AudioState.calm;
    _activeBgmAsset = null;
    _smoothedHeartbeatIntensity = 0;

    ++_bgmTransitionToken;
    ++_flipCueToken;
    ++_devilDuckToken;
    ++_safeZoneCueToken;
    ++_gameLostCueToken;
    ++_glitchScreenCueToken;

    final flipCue = _flipCuePlayer;
    _flipCuePlayer = null;

    final devilLoop = _devilProximityLoopPlayer;
    _devilProximityLoopPlayer = null;

    final alarmLoop = _lowTimeAlarmLoopPlayer;
    _lowTimeAlarmLoopPlayer = null;

    final safeZoneCue = _safeZoneCuePlayer;
    _safeZoneCuePlayer = null;

    final winningLoop = _winningTransitionLoopPlayer;
    _winningTransitionLoopPlayer = null;

    final gameLostCue = _gameLostCuePlayer;
    _gameLostCuePlayer = null;

    final glitchCue = _glitchScreenCuePlayer;
    _glitchScreenCuePlayer = null;

    final heartbeat = _heartbeatPlayer;
    _heartbeatPlayer = null;
    _heartbeatVolume = 0;

    await Future.wait<void>(<Future<void>>[
      _stopAndDisposePlayer(flipCue, 'stopAll:flipCue'),
      _stopAndDisposePlayer(devilLoop, 'stopAll:devilLoop'),
      _stopAndDisposePlayer(alarmLoop, 'stopAll:alarmLoop'),
      _stopAndDisposePlayer(safeZoneCue, 'stopAll:safeZoneCue'),
      _stopAndDisposePlayer(winningLoop, 'stopAll:winningLoop'),
      _stopAndDisposePlayer(gameLostCue, 'stopAll:gameLostCue'),
      _stopAndDisposePlayer(glitchCue, 'stopAll:glitchCue'),
      _stopAndDisposePlayer(heartbeat, 'stopAll:heartbeat'),
    ]);

    await _stopBgm(scope: 'stopAll:bgm');
    _refreshPriority('stopAll');
  }
}
