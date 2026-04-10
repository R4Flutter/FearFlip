import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  AudioService() {
    _instances.add(this);
  }

  static final Set<AudioService> _instances = <AudioService>{};
  static double _masterVolume = 1.0;
  static bool _muted = false;

  static double get masterVolume => _masterVolume;
  static bool get isMuted => _muted;

  static Future<void> configureGlobalAudio({
    double? volume,
    bool? muted,
  }) async {
    var changed = false;

    if (volume != null) {
      final normalized = volume.clamp(0.0, 1.0);
      if ((_masterVolume - normalized).abs() > 0.001) {
        _masterVolume = normalized;
        changed = true;
      }
    }

    if (muted != null && _muted != muted) {
      _muted = muted;
      changed = true;
    }

    if (!changed || _instances.isEmpty) {
      return;
    }

    await Future.wait<void>(
      _instances.map((service) => service._applyGlobalAudioSettings()),
    );
  }

  static const String _calmLoopAsset = 'calm_loop.mp3';
  static const String _intenseLoopAsset = 'intense_loop.mp3';
  static const String _heartbeatAsset = 'heartbeat.mp3';
  static const List<String> _flipCueCandidates = <String>[
    'fahhhhh_flippingtime.mp3',
  ];
  static const List<String> _devilApproachCandidates = <String>[
    'devil_approach.wav',
    'devil_approaching_character.wav',
    'devil is appoarching to chacter.wav',
  ];
  static const List<String> _lowTimeAlarmCandidates = <String>[
    'low_time_alarm.wav',
    'low_time_alarm_10s.wav',
    'low_time_alaram (10s left).wav',
  ];
  static const List<String> _safeZoneCueCandidates = <String>[
    'safe_zone_sound.mp3',
  ];
  static const List<String> _winningTransitionLoopCandidates = <String>[
    'wining_soundeffect.mp3',
    'winning_soundeffect.mp3',
  ];
  static const List<String> _gameLostCueCandidates = <String>[
    'gamelost_soundeffect.mp3',
    'game_lost_soundeffect.mp3',
  ];
  static const List<String> _glitchScreenCueCandidates = <String>[
    'glitch_screen_sound_eefect.mp3',
  ];

  Future<void>? _initFuture;
  String? _flipCueAsset;
  String? _devilApproachAsset;
  String? _lowTimeAlarmAsset;
  String? _safeZoneCueAsset;
  String? _winningTransitionLoopAsset;
  String? _gameLostCueAsset;
  String? _glitchScreenCueAsset;

  bool _calmPlaying = false;
  bool _intensePlaying = false;
  bool _lowTimeAlarmCuePlaying = false;
  bool _devilApproachPlaying = false;
  bool _heartbeatPlaying = false;
  bool _criticalGameplayAudioOnly = false;
  bool _devilProximityLoopPlaying = false;
  bool _lowTimeAlarmLoopPlaying = false;
  bool _winningTransitionLoopPlaying = false;
  String? _activeBgmAsset;
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
  double _currentBgmBaseVolume = 0;
  double _heartbeatVolume = 0;
  double _flipCueBaseVolume = 0.92;
  double _devilProximityLoopBaseVolume = 1.0;
  double _lowTimeAlarmLoopBaseVolume = 1.0;
  double _safeZoneCueBaseVolume = 0.95;
  double _winningTransitionLoopBaseVolume = 1.0;
  double _gameLostCueBaseVolume = 1.0;
  double _glitchScreenCueBaseVolume = 1.0;

  Future<void> warmUp() async {
    await _ensureInitialized();
  }

  Future<void> setCriticalGameplayAudioOnly(bool enabled) async {
    _criticalGameplayAudioOnly = enabled;
    if (!enabled) {
      return;
    }

    await Future.wait<void>([
      _stopBgmForCriticalMode(),
      _stopHeartbeatInternal(),
      _stopFlipCueInternal(),
      stopSafeZoneCue(),
      stopWinningTransitionLoop(),
      _stopGlitchScreenCueInternal(),
    ]);
  }

  Future<void> _stopBgmForCriticalMode() async {
    _calmPlaying = false;
    _intensePlaying = false;
    _activeBgmAsset = null;
    _currentBgmBaseVolume = 0;
    try {
      await FlameAudio.bgm.stop();
    } catch (error) {
      _logAudioError('stopBgmForCriticalMode', error);
    }
  }

  Future<void> _stopHeartbeatInternal() async {
    _heartbeatPlaying = false;
    _heartbeatVolume = 0;
    final player = _heartbeatPlayer;
    _heartbeatPlayer = null;
    if (player == null) {
      return;
    }
    try {
      await player.stop();
      await player.dispose();
    } catch (error) {
      _logAudioError('stopHeartbeatInternal', error);
    }
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
    try {
      await FlameAudio.bgm.initialize();
    } catch (error) {
      _logAudioError('bgm.initialize', error);
    }

    await _ensureCueAssetsResolved();

    for (final asset in <String>[
      _calmLoopAsset,
      _intenseLoopAsset,
      _heartbeatAsset,
    ]) {
      try {
        await FlameAudio.audioCache.load(asset);
      } catch (error) {
        _logAudioError('optional-load:$asset', error);
      }
    }
  }

  Future<void> _ensureCueAssetsResolved() async {
    _flipCueAsset ??= await _resolveCueAsset(
      scope: 'flip_cue',
      candidates: _flipCueCandidates,
    );
    _devilApproachAsset ??= await _resolveCueAsset(
      scope: 'devil_approach',
      candidates: _devilApproachCandidates,
    );
    _lowTimeAlarmAsset ??= await _resolveCueAsset(
      scope: 'low_time_alarm',
      candidates: _lowTimeAlarmCandidates,
    );
    _safeZoneCueAsset ??= await _resolveCueAsset(
      scope: 'safe_zone_cue',
      candidates: _safeZoneCueCandidates,
    );
    _winningTransitionLoopAsset ??= await _resolveCueAsset(
      scope: 'winning_transition_loop',
      candidates: _winningTransitionLoopCandidates,
    );
    _gameLostCueAsset ??= await _resolveCueAsset(
      scope: 'game_lost_cue',
      candidates: _gameLostCueCandidates,
    );
    _glitchScreenCueAsset ??= await _resolveCueAsset(
      scope: 'glitch_screen_cue',
      candidates: _glitchScreenCueCandidates,
    );
  }

  Future<String?> _resolveCueAsset({
    required String scope,
    required List<String> candidates,
  }) async {
    for (final asset in candidates) {
      try {
        await FlameAudio.audioCache.load(asset);
        return asset;
      } catch (error) {
        _logAudioError('load:$scope:$asset', error);
      }
    }
    return null;
  }

  double _effectiveVolume(double volume) {
    if (_muted) {
      return 0;
    }
    return (volume.clamp(0.0, 1.0) * _masterVolume).clamp(0.0, 1.0);
  }

  Future<void> _setPlayerVolume(
    AudioPlayer? player,
    double baseVolume,
    String scope,
  ) async {
    if (player == null) {
      return;
    }

    try {
      await player.setVolume(_effectiveVolume(baseVolume));
    } catch (error) {
      _logAudioError(scope, error);
    }
  }

  Future<void> _applyGlobalAudioSettings() async {
    if (_initFuture == null) {
      return;
    }

    await _setBgmVolume(_currentBgmBaseVolume);
    await Future.wait<void>([
      _setPlayerVolume(
        _heartbeatPlayer,
        _heartbeatVolume,
        'applySettings:heartbeat',
      ),
      _setPlayerVolume(
        _flipCuePlayer,
        _flipCueBaseVolume,
        'applySettings:flip',
      ),
      _setPlayerVolume(
        _devilProximityLoopPlayer,
        _devilProximityLoopBaseVolume,
        'applySettings:devilLoop',
      ),
      _setPlayerVolume(
        _lowTimeAlarmLoopPlayer,
        _lowTimeAlarmLoopBaseVolume,
        'applySettings:alarmLoop',
      ),
      _setPlayerVolume(
        _safeZoneCuePlayer,
        _safeZoneCueBaseVolume,
        'applySettings:safeCue',
      ),
      _setPlayerVolume(
        _winningTransitionLoopPlayer,
        _winningTransitionLoopBaseVolume,
        'applySettings:winningLoop',
      ),
      _setPlayerVolume(
        _gameLostCuePlayer,
        _gameLostCueBaseVolume,
        'applySettings:lostCue',
      ),
      _setPlayerVolume(
        _glitchScreenCuePlayer,
        _glitchScreenCueBaseVolume,
        'applySettings:glitchCue',
      ),
    ]);
  }

  Future<void> _playBgm(String asset, double volume) async {
    final normalizedVolume = volume.clamp(0.0, 1.0);
    final alreadyActive = _activeBgmAsset == asset;
    if (alreadyActive) {
      await _setBgmVolume(normalizedVolume);
      return;
    }

    await FlameAudio.bgm.stop();
    await FlameAudio.bgm.play(
      asset,
      volume: _effectiveVolume(normalizedVolume),
    );
    _activeBgmAsset = asset;
    await _setBgmVolume(normalizedVolume);
  }

  Future<void> playCalm() async {
    if (_criticalGameplayAudioOnly) {
      return;
    }

    await _ensureInitialized();
    if (_calmPlaying) {
      await _setBgmVolume(0.4);
      return;
    }
    _calmPlaying = true;
    _intensePlaying = false;
    try {
      await _playBgm(_calmLoopAsset, 0.4);
    } catch (error) {
      _logAudioError('playCalm', error);
    }
  }

  Future<void> playIntense() async {
    if (_criticalGameplayAudioOnly) {
      return;
    }

    await _ensureInitialized();
    if (_intensePlaying) {
      await _setBgmVolume(0.6);
      return;
    }
    _calmPlaying = false;
    _intensePlaying = true;
    try {
      await _playBgm(_intenseLoopAsset, 0.6);
    } catch (error) {
      _logAudioError('playIntense', error);
    }
  }

  Future<void> setHeartbeatIntensity(double intensity) async {
    if (_criticalGameplayAudioOnly) {
      return;
    }

    await _ensureInitialized();

    final clamped = intensity.clamp(0.0, 1.0);
    final target = clamped < 0.25 ? 0.0 : (clamped * 0.85);

    if (target <= 0) {
      if (!_heartbeatPlaying) {
        return;
      }
      _heartbeatPlaying = false;
      _heartbeatVolume = 0;
      final player = _heartbeatPlayer;
      _heartbeatPlayer = null;
      if (player == null) {
        return;
      }
      try {
        await player.stop();
        await player.dispose();
      } catch (error) {
        _logAudioError('setHeartbeatIntensity:stop', error);
      }
      return;
    }

    final player = _heartbeatPlayer;
    if (player == null) {
      try {
        _heartbeatPlayer = await FlameAudio.loop(
          _heartbeatAsset,
          volume: _effectiveVolume(target),
        );
        _heartbeatPlaying = true;
        _heartbeatVolume = target;
      } catch (error) {
        _logAudioError('setHeartbeatIntensity:start', error);
      }
      return;
    }

    if ((target - _heartbeatVolume).abs() < 0.03) {
      return;
    }

    try {
      await player.setVolume(_effectiveVolume(target));
      _heartbeatVolume = target;
    } catch (error) {
      _logAudioError('setHeartbeatIntensity:update', error);
    }
  }

  Future<void> playFlipCue({double volume = 0.92}) async {
    if (_criticalGameplayAudioOnly) {
      return;
    }

    await _ensureInitialized();
    if (_flipCueAsset == null) {
      await _ensureCueAssetsResolved();
    }
    final asset = _flipCueAsset;
    if (asset == null) {
      return;
    }

    _flipCueBaseVolume = volume.clamp(0.0, 1.0);
    final token = ++_flipCueToken;

    final previous = _flipCuePlayer;
    _flipCuePlayer = null;
    if (previous != null) {
      try {
        await previous.stop();
        await previous.dispose();
      } catch (error) {
        _logAudioError('playFlipCue:cleanupPrevious', error);
      }
    }

    try {
      final player = await FlameAudio.playLongAudio(
        asset,
        volume: _effectiveVolume(_flipCueBaseVolume),
      );

      if (token != _flipCueToken) {
        await player.stop();
        await player.dispose();
        return;
      }

      _flipCuePlayer = player;
      unawaited(
        player.onPlayerComplete.first
            .then((_) async {
              if (token != _flipCueToken) {
                return;
              }
              if (!identical(_flipCuePlayer, player)) {
                return;
              }
              _flipCuePlayer = null;
              try {
                await player.dispose();
              } catch (error) {
                _logAudioError('playFlipCue:dispose', error);
              }
            })
            .catchError((error) {
              _logAudioError('playFlipCue:onComplete', error);
            }),
      );
    } catch (error) {
      _logAudioError('playFlipCue:stream', error);
      try {
        await FlameAudio.play(
          asset,
          volume: _effectiveVolume(_flipCueBaseVolume),
        );
      } catch (fallbackError) {
        _logAudioError('playFlipCue:fallback', fallbackError);
      }
    }
  }

  Future<void> _stopFlipCueInternal() async {
    ++_flipCueToken;
    final player = _flipCuePlayer;
    _flipCuePlayer = null;

    if (player == null) {
      return;
    }

    try {
      await player.stop();
      await player.dispose();
    } catch (error) {
      _logAudioError('stopFlipCue', error);
    }
  }

  Future<void> playSafeZoneCue({
    Duration maxDuration = const Duration(seconds: 1),
    double volume = 0.95,
  }) async {
    if (_criticalGameplayAudioOnly) {
      return;
    }

    await _ensureInitialized();
    if (_safeZoneCueAsset == null) {
      await _ensureCueAssetsResolved();
    }
    final asset = _safeZoneCueAsset;
    if (asset == null) {
      return;
    }

    _safeZoneCueBaseVolume = volume.clamp(0.0, 1.0);

    final token = ++_safeZoneCueToken;
    final previous = _safeZoneCuePlayer;
    _safeZoneCuePlayer = null;
    if (previous != null) {
      try {
        await previous.stop();
        await previous.dispose();
      } catch (error) {
        _logAudioError('playSafeZoneCue:cleanupPrevious', error);
      }
    }

    try {
      final player = await FlameAudio.playLongAudio(
        asset,
        volume: _effectiveVolume(_safeZoneCueBaseVolume),
      );

      if (token != _safeZoneCueToken) {
        await player.stop();
        await player.dispose();
        return;
      }

      _safeZoneCuePlayer = player;

      unawaited(
        Future<void>.delayed(maxDuration, () async {
          if (token != _safeZoneCueToken) {
            return;
          }
          if (!identical(_safeZoneCuePlayer, player)) {
            return;
          }
          _safeZoneCuePlayer = null;
          try {
            await player.stop();
            await player.dispose();
          } catch (error) {
            _logAudioError('playSafeZoneCue:timedStop', error);
          }
        }),
      );

      unawaited(
        player.onPlayerComplete.first
            .then((_) async {
              if (!identical(_safeZoneCuePlayer, player)) {
                return;
              }
              _safeZoneCuePlayer = null;
              try {
                await player.dispose();
              } catch (error) {
                _logAudioError('playSafeZoneCue:dispose', error);
              }
            })
            .catchError((error) {
              _logAudioError('playSafeZoneCue:onComplete', error);
            }),
      );
    } catch (error) {
      _logAudioError('playSafeZoneCue:stream', error);
      try {
        await FlameAudio.play(
          asset,
          volume: _effectiveVolume(_safeZoneCueBaseVolume),
        );
      } catch (fallbackError) {
        _logAudioError('playSafeZoneCue:fallback', fallbackError);
      }
    }
  }

  Future<void> stopSafeZoneCue() async {
    ++_safeZoneCueToken;
    final player = _safeZoneCuePlayer;
    _safeZoneCuePlayer = null;

    if (player == null) {
      return;
    }

    try {
      await player.stop();
      await player.dispose();
    } catch (error) {
      _logAudioError('stopSafeZoneCue', error);
    }
  }

  Future<void> startWinningTransitionLoop({double volume = 1.0}) async {
    if (_criticalGameplayAudioOnly) {
      return;
    }

    await _ensureInitialized();
    if (_winningTransitionLoopAsset == null) {
      await _ensureCueAssetsResolved();
    }
    final asset = _winningTransitionLoopAsset;
    if (asset == null || _winningTransitionLoopPlaying) {
      return;
    }

    _winningTransitionLoopPlaying = true;
    _winningTransitionLoopBaseVolume = volume.clamp(0.0, 1.0);
    try {
      final player = await FlameAudio.loop(
        asset,
        volume: _effectiveVolume(_winningTransitionLoopBaseVolume),
      );
      if (!_winningTransitionLoopPlaying) {
        await player.stop();
        await player.dispose();
        return;
      }
      _winningTransitionLoopPlayer = player;
    } catch (error) {
      _winningTransitionLoopPlaying = false;
      _winningTransitionLoopPlayer = null;
      _logAudioError('startWinningTransitionLoop', error);
    }
  }

  Future<void> stopWinningTransitionLoop() async {
    _winningTransitionLoopPlaying = false;
    final player = _winningTransitionLoopPlayer;
    _winningTransitionLoopPlayer = null;

    if (player == null) {
      return;
    }

    try {
      await player.stop();
      await player.dispose();
    } catch (error) {
      _logAudioError('stopWinningTransitionLoop', error);
    }
  }

  Future<void> playGameLostCue({double volume = 1.0}) async {
    await _ensureInitialized();
    if (_gameLostCueAsset == null) {
      await _ensureCueAssetsResolved();
    }
    final asset = _gameLostCueAsset;
    if (asset == null) {
      return;
    }

    _gameLostCueBaseVolume = volume.clamp(0.0, 1.0);

    final token = ++_gameLostCueToken;
    final previous = _gameLostCuePlayer;
    _gameLostCuePlayer = null;
    if (previous != null) {
      try {
        await previous.stop();
        await previous.dispose();
      } catch (error) {
        _logAudioError('playGameLostCue:cleanupPrevious', error);
      }
    }

    try {
      final player = await FlameAudio.playLongAudio(
        asset,
        volume: _effectiveVolume(_gameLostCueBaseVolume),
      );
      if (token != _gameLostCueToken) {
        await player.stop();
        await player.dispose();
        return;
      }
      _gameLostCuePlayer = player;
      unawaited(
        player.onPlayerComplete.first
            .then((_) async {
              if (!identical(_gameLostCuePlayer, player)) {
                return;
              }
              _gameLostCuePlayer = null;
              try {
                await player.dispose();
              } catch (error) {
                _logAudioError('playGameLostCue:dispose', error);
              }
            })
            .catchError((error) {
              _logAudioError('playGameLostCue:onComplete', error);
            }),
      );
    } catch (error) {
      _logAudioError('playGameLostCue:stream', error);
      try {
        await FlameAudio.play(
          asset,
          volume: _effectiveVolume(_gameLostCueBaseVolume),
        );
      } catch (fallbackError) {
        _logAudioError('playGameLostCue:fallback', fallbackError);
      }
    }
  }

  Future<void> stopGameLostCue() async {
    ++_gameLostCueToken;
    final player = _gameLostCuePlayer;
    _gameLostCuePlayer = null;

    if (player == null) {
      return;
    }

    try {
      await player.stop();
      await player.dispose();
    } catch (error) {
      _logAudioError('stopGameLostCue', error);
    }
  }

  Future<void> playGlitchScreenCue({double volume = 1.0}) async {
    if (_criticalGameplayAudioOnly) {
      return;
    }

    await _ensureInitialized();
    if (_glitchScreenCueAsset == null) {
      await _ensureCueAssetsResolved();
    }

    final asset = _glitchScreenCueAsset;
    if (asset == null || _glitchScreenCuePlayer != null) {
      return;
    }

    final token = ++_glitchScreenCueToken;
    _glitchScreenCueBaseVolume = volume.clamp(0.0, 1.0);

    try {
      final player = await FlameAudio.playLongAudio(
        asset,
        volume: _effectiveVolume(_glitchScreenCueBaseVolume),
      );

      if (token != _glitchScreenCueToken) {
        await player.stop();
        await player.dispose();
        return;
      }

      _glitchScreenCuePlayer = player;
      unawaited(
        player.onPlayerComplete.first
            .then((_) async {
              if (token != _glitchScreenCueToken) {
                return;
              }
              if (!identical(_glitchScreenCuePlayer, player)) {
                return;
              }
              _glitchScreenCuePlayer = null;
              try {
                await player.dispose();
              } catch (error) {
                _logAudioError('playGlitchScreenCue:dispose', error);
              }
            })
            .catchError((error) {
              _logAudioError('playGlitchScreenCue:onComplete', error);
            }),
      );
    } catch (error) {
      _logAudioError('playGlitchScreenCue:stream', error);
      _glitchScreenCuePlayer = null;
      try {
        await FlameAudio.play(
          asset,
          volume: _effectiveVolume(_glitchScreenCueBaseVolume),
        );
      } catch (fallbackError) {
        _logAudioError('playGlitchScreenCue:fallback', fallbackError);
      }
    }
  }

  Future<void> _stopGlitchScreenCueInternal() async {
    ++_glitchScreenCueToken;
    final player = _glitchScreenCuePlayer;
    _glitchScreenCuePlayer = null;

    if (player == null) {
      return;
    }

    try {
      await player.stop();
      await player.dispose();
    } catch (error) {
      _logAudioError('stopGlitchScreenCue', error);
    }
  }

  Future<void> startDevilProximityLoop({double volume = 1.0}) async {
    await _ensureInitialized();
    if (_devilApproachAsset == null) {
      await _ensureCueAssetsResolved();
    }
    final asset = _devilApproachAsset;
    if (asset == null || _devilProximityLoopPlaying) {
      return;
    }

    _devilProximityLoopPlaying = true;
    _devilProximityLoopBaseVolume = volume.clamp(0.0, 1.0);
    final token = ++_devilDuckToken;
    try {
      await _setBgmVolume(0.0);
      final player = await FlameAudio.loop(
        asset,
        volume: _effectiveVolume(_devilProximityLoopBaseVolume),
      );
      if (!_devilProximityLoopPlaying || token != _devilDuckToken) {
        await player.stop();
        await player.dispose();
        return;
      }
      _devilProximityLoopPlayer = player;
    } catch (error) {
      _devilProximityLoopPlaying = false;
      _devilProximityLoopPlayer = null;
      _logAudioError('startDevilProximityLoop', error);
      await _setBgmVolume(_intensePlaying ? 0.6 : 0.4);
    }
  }

  Future<void> stopDevilProximityLoop() async {
    ++_devilDuckToken;
    _devilProximityLoopPlaying = false;
    final player = _devilProximityLoopPlayer;
    _devilProximityLoopPlayer = null;

    if (player != null) {
      try {
        await player.stop();
        await player.dispose();
      } catch (error) {
        _logAudioError('stopDevilProximityLoop', error);
      }
    }

    await _setBgmVolume(_intensePlaying ? 0.6 : 0.4);
  }

  Future<void> startLowTimeAlarmLoop({double volume = 1.0}) async {
    await _ensureInitialized();
    if (_lowTimeAlarmAsset == null) {
      await _ensureCueAssetsResolved();
    }
    final asset = _lowTimeAlarmAsset;
    if (asset == null || _lowTimeAlarmLoopPlaying) {
      return;
    }

    _lowTimeAlarmLoopPlaying = true;
    _lowTimeAlarmLoopBaseVolume = volume.clamp(0.0, 1.0);
    try {
      final player = await FlameAudio.loop(
        asset,
        volume: _effectiveVolume(_lowTimeAlarmLoopBaseVolume),
      );
      if (!_lowTimeAlarmLoopPlaying) {
        await player.stop();
        await player.dispose();
        return;
      }
      _lowTimeAlarmLoopPlayer = player;
    } catch (error) {
      _lowTimeAlarmLoopPlaying = false;
      _lowTimeAlarmLoopPlayer = null;
      _logAudioError('startLowTimeAlarmLoop', error);
    }
  }

  Future<void> stopLowTimeAlarmLoop() async {
    _lowTimeAlarmLoopPlaying = false;
    final player = _lowTimeAlarmLoopPlayer;
    _lowTimeAlarmLoopPlayer = null;

    if (player == null) {
      return;
    }

    try {
      await player.stop();
      await player.dispose();
    } catch (error) {
      _logAudioError('stopLowTimeAlarmLoop', error);
    }
  }

  Future<void> playLowTimeAlarm() async {
    await _ensureInitialized();
    if (_lowTimeAlarmAsset == null) {
      await _ensureCueAssetsResolved();
    }
    final asset = _lowTimeAlarmAsset;
    if (asset == null) {
      return;
    }
    if (_lowTimeAlarmCuePlaying || _lowTimeAlarmLoopPlaying) {
      return;
    }
    _lowTimeAlarmCuePlaying = true;
    try {
      await _playCueLong(asset, volume: 1.0);
    } catch (error) {
      _logAudioError('playLowTimeAlarm', error);
    } finally {
      _lowTimeAlarmCuePlaying = false;
    }
  }

  Future<void> playDevilApproachingCue() async {
    await _ensureInitialized();
    if (_devilApproachAsset == null) {
      await _ensureCueAssetsResolved();
    }
    final asset = _devilApproachAsset;
    if (asset == null) {
      return;
    }
    if (_devilApproachPlaying || _devilProximityLoopPlaying) {
      return;
    }
    _devilApproachPlaying = true;
    final token = ++_devilDuckToken;
    try {
      // Prioritize this danger cue over BGM so it is clearly audible.
      await _setBgmVolume(0.0);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await _playCueLong(asset, volume: 1.0);
    } catch (error) {
      _logAudioError('playDevilApproachingCue', error);
    } finally {
      _devilApproachPlaying = false;
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 900), () async {
          if (token != _devilDuckToken) {
            return;
          }
          await _setBgmVolume(_intensePlaying ? 0.6 : 0.4);
        }),
      );
    }
  }

  Future<void> _playCueLong(String asset, {required double volume}) async {
    final effectiveVolume = _effectiveVolume(volume);
    try {
      final player = await FlameAudio.playLongAudio(
        asset,
        volume: effectiveVolume,
      );
      unawaited(
        player.onPlayerComplete.first.then((_) => player.dispose()).catchError((
          error,
        ) {
          _logAudioError('_playCueLong:dispose', error);
        }),
      );
    } catch (error) {
      _logAudioError('_playCueLong:stream', error);
      await FlameAudio.play(asset, volume: effectiveVolume);
    }
  }

  Future<void> _setBgmVolume(double volume) async {
    _currentBgmBaseVolume = volume.clamp(0.0, 1.0);
    try {
      await FlameAudio.bgm.audioPlayer.setVolume(
        _effectiveVolume(_currentBgmBaseVolume),
      );
    } catch (error) {
      _logAudioError('_setBgmVolume', error);
    }
  }

  void _logAudioError(String scope, Object error) {
    if (kDebugMode) {
      debugPrint('AudioService::$scope failed: $error');
    }
  }

  Future<void> stopAll() async {
    await _ensureInitialized();
    _calmPlaying = false;
    _intensePlaying = false;
    _lowTimeAlarmCuePlaying = false;
    _devilApproachPlaying = false;
    _winningTransitionLoopPlaying = false;
    _activeBgmAsset = null;
    ++_flipCueToken;
    ++_devilDuckToken;
    ++_safeZoneCueToken;
    ++_gameLostCueToken;
    ++_glitchScreenCueToken;

    final flipCue = _flipCuePlayer;
    _flipCuePlayer = null;

    if (flipCue != null) {
      try {
        await flipCue.stop();
        await flipCue.dispose();
      } catch (error) {
        _logAudioError('stopAll:flipCue', error);
      }
    }

    final devilLoop = _devilProximityLoopPlayer;
    _devilProximityLoopPlayer = null;
    _devilProximityLoopPlaying = false;

    if (devilLoop != null) {
      try {
        await devilLoop.stop();
        await devilLoop.dispose();
      } catch (error) {
        _logAudioError('stopAll:devilLoop', error);
      }
    }

    final alarmLoop = _lowTimeAlarmLoopPlayer;
    _lowTimeAlarmLoopPlayer = null;
    _lowTimeAlarmLoopPlaying = false;

    if (alarmLoop != null) {
      try {
        await alarmLoop.stop();
        await alarmLoop.dispose();
      } catch (error) {
        _logAudioError('stopAll:alarmLoop', error);
      }
    }

    final safeZoneCue = _safeZoneCuePlayer;
    _safeZoneCuePlayer = null;

    if (safeZoneCue != null) {
      try {
        await safeZoneCue.stop();
        await safeZoneCue.dispose();
      } catch (error) {
        _logAudioError('stopAll:safeZoneCue', error);
      }
    }

    final winningLoop = _winningTransitionLoopPlayer;
    _winningTransitionLoopPlayer = null;

    if (winningLoop != null) {
      try {
        await winningLoop.stop();
        await winningLoop.dispose();
      } catch (error) {
        _logAudioError('stopAll:winningLoop', error);
      }
    }

    final gameLostCue = _gameLostCuePlayer;
    _gameLostCuePlayer = null;

    if (gameLostCue != null) {
      try {
        await gameLostCue.stop();
        await gameLostCue.dispose();
      } catch (error) {
        _logAudioError('stopAll:gameLostCue', error);
      }
    }

    final glitchCue = _glitchScreenCuePlayer;
    _glitchScreenCuePlayer = null;

    if (glitchCue != null) {
      try {
        await glitchCue.stop();
        await glitchCue.dispose();
      } catch (error) {
        _logAudioError('stopAll:glitchCue', error);
      }
    }

    final heartbeat = _heartbeatPlayer;
    _heartbeatPlayer = null;
    _heartbeatPlaying = false;
    _heartbeatVolume = 0;

    if (heartbeat != null) {
      try {
        await heartbeat.stop();
        await heartbeat.dispose();
      } catch (error) {
        _logAudioError('stopAll:heartbeat', error);
      }
    }

    try {
      await FlameAudio.bgm.stop();
    } catch (error) {
      _logAudioError('stopAll', error);
    }
  }
}
