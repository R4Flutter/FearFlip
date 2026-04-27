import 'dart:async';

import '../../services/audio_manager.dart';
import '../../services/game_audio_event.dart';

/// Dispatches trap-related audio events through the existing [AudioManager]
/// while respecting cooldowns and priority rules.
class TrapAudioController {
  TrapAudioController({required AudioManager audioManager})
      : _audioManager = audioManager;

  final AudioManager _audioManager;

  /// Minimum time between successive hidden-step creak sounds.
  static const Duration _hiddenCreakCooldown = Duration(seconds: 2);

  DateTime _lastHiddenCreak = DateTime(2000);

  /// Play the subtle creak when stepping over a hidden trap tile.
  ///
  /// Subject to a cooldown so that walking over consecutive hidden tiles
  /// doesn't create audio clutter.
  void playHiddenCreak() {
    final now = DateTime.now();
    if (now.difference(_lastHiddenCreak) < _hiddenCreakCooldown) return;
    _lastHiddenCreak = now;
    // Reuse existing glass_break asset at low volume (handled by AudioManager)
    unawaited(_audioManager.handle(GameAudioEvent.trapStepWarning));
  }

  /// Play the warning crack when a Hidden tile transitions to Cracked.
  void playCrackReveal() {
    unawaited(_audioManager.handle(GameAudioEvent.trapStepWarning));
  }

  /// Play the escalation sound when a Cracked tile becomes Critical.
  void playCriticalEscalation() {
    unawaited(_audioManager.handle(GameAudioEvent.trapProximityTension));
  }

  /// Play the first impact cue when the trap tile fractures.
  void playDeathCrack() {
    unawaited(_audioManager.handle(GameAudioEvent.trapDeathCrack));
  }

  /// Play the mid-sequence falling whoosh.
  void playDeathFall() {
    unawaited(_audioManager.handle(GameAudioEvent.trapDeathFall));
  }

  /// Play the end-of-sequence heavy impact.
  void playDeathImpact() {
    unawaited(_audioManager.handle(GameAudioEvent.trapDeathImpact));
  }

  /// Trigger the full trap-death audio sequence.
  ///
  /// This fires the composite death event — the AudioManager should
  /// interpret it as: crack burst → fall whoosh → bass impact → sting.
  Future<void> playTrapDeath() async {
    await _audioManager.handle(GameAudioEvent.trapDeath);
  }

  /// Reset any internal state (called on stage transitions).
  void reset() {
    _lastHiddenCreak = DateTime(2000);
  }
}
