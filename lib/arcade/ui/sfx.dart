import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../services/audio_manager.dart';
import '../../services/game_audio_event.dart';

/// Menu and pickup sounds (assets/audio/ui, made by tool/audio/ui_sfx.py).
enum Sound {
  click,
  wisp,
  coins,
  star1,
  star2,
  star3,
  chest,
  denied,
  purchase,
  powerup,
  shield,
  swoosh,
  levelup,
}

/// Plays [Sound]s and decides what may be heard: the player's music and
/// sound switches, the portal's mute, and silence while an ad plays.
class Sfx {
  Sfx._();

  static final Sfx instance = Sfx._();

  static const int _voices = 4;
  final List<AudioPlayer> _players = <AudioPlayer>[];
  int _next = 0;

  bool _sfxOn = true;
  bool _musicOn = true;
  bool _portalMuted = false;
  bool _adPlaying = false;
  bool _paused = false;

  bool get _silent => !_sfxOn || _portalMuted || _adPlaying || _paused;

  void play(Sound sound, {double volume = 0.8}) {
    if (_silent) return;
    unawaited(_play(sound, volume));
  }

  Future<void> _play(Sound sound, double volume) async {
    try {
      if (_players.isEmpty) {
        for (var i = 0; i < _voices; i++) {
          final player = AudioPlayer();
          await player.setReleaseMode(ReleaseMode.stop);
          _players.add(player);
        }
      }
      final player = _players[_next];
      _next = (_next + 1) % _players.length;
      await player.stop();
      await player.play(AssetSource('audio/ui/${sound.name}.mp3'), volume: volume);
    } catch (error) {
      if (kDebugMode) debugPrint('[Sfx] ${sound.name}: $error');
    }
  }

  /// The player's switches (settings).
  void setSwitches({required bool musicOn, required bool sfxOn}) {
    _musicOn = musicOn;
    _sfxOn = sfxOn;
    _apply();
  }

  /// The portal asked for silence (CrazyGames mute button).
  void setPortalMuted(bool muted) {
    _portalMuted = muted;
    _apply();
  }

  /// An ad is on screen: everything goes quiet until it ends.
  void setAdPlaying(bool playing) {
    _adPlaying = playing;
    _apply();
  }

  /// The tab is hidden.
  void setPaused(bool paused) {
    _paused = paused;
  }

  void _apply() {
    final hush = _portalMuted || _adPlaying;
    final audio = AudioManager.instance;
    unawaited(audio.setBusMuted(AudioBus.master, hush));
    unawaited(audio.setBusMuted(AudioBus.bgm, !_musicOn));
    for (final bus in const [
      AudioBus.ambient,
      AudioBus.enemy,
      AudioBus.ui,
      AudioBus.action,
    ]) {
      unawaited(audio.setBusMuted(bus, !_sfxOn));
    }
  }
}
