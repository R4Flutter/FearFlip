import 'package:flame_audio/flame_audio.dart';

class AudioService {
  bool _calmPlaying = false;
  bool _intensePlaying = false;

  Future<void> playCalm() async {
    if (_calmPlaying) {
      return;
    }
    _calmPlaying = true;
    _intensePlaying = false;
    try {
      await FlameAudio.bgm.stop();
      await FlameAudio.bgm.play('calm_loop.mp3', volume: 0.4);
    } catch (_) {
      // Placeholder assets may be missing while prototyping.
    }
  }

  Future<void> playIntense() async {
    if (_intensePlaying) {
      return;
    }
    _calmPlaying = false;
    _intensePlaying = true;
    try {
      await FlameAudio.bgm.stop();
      await FlameAudio.bgm.play('intense_loop.mp3', volume: 0.6);
    } catch (_) {
      // Placeholder assets may be missing while prototyping.
    }
  }

  Future<void> setHeartbeatIntensity(double intensity) async {
    final clamped = intensity.clamp(0.0, 1.0);
    if (clamped < 0.25) {
      return;
    }

    try {
      await FlameAudio.play('heartbeat.mp3', volume: clamped * 0.75);
    } catch (_) {
      // Placeholder assets may be missing while prototyping.
    }
  }

  Future<void> stopAll() async {
    _calmPlaying = false;
    _intensePlaying = false;
    try {
      await FlameAudio.bgm.stop();
    } catch (_) {
      // Ignore stop failures.
    }
  }
}
