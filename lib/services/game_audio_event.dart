import 'package:flutter/foundation.dart';

enum AudioBus { master, bgm, ambient, enemy, ui, action }

enum MatchAudioState { idle, active, paused, won, lost, exited }

enum GameAudioEvent {
  matchStart,
  matchPause,
  matchResume,
  matchRestart,
  matchExit,
  flipTriggered,
  devilDistanceChanged,
  mazeShiftStarted,
  mazeShiftEnded,
  safeZoneEntered,
  safeZoneExited,
  timeChanged,
  playerWon,
  playerLost,
}

@immutable
class GameAudioEventPayload {
  const GameAudioEventPayload(
    this.type, {
    this.secondsLeft,
    this.devilDistanceTiles,
    this.devilEnabled,
    this.safeZoneImmune,
    this.frameId,
    this.timestamp,
  });

  final GameAudioEvent type;
  final int? secondsLeft;
  final int? devilDistanceTiles;
  final bool? devilEnabled;
  final bool? safeZoneImmune;
  final int? frameId;
  final DateTime? timestamp;

  DateTime get effectiveTimestamp => timestamp ?? DateTime.now();

  static GameAudioEventPayload matchStart() {
    return const GameAudioEventPayload(GameAudioEvent.matchStart);
  }

  static GameAudioEventPayload matchPause() {
    return const GameAudioEventPayload(GameAudioEvent.matchPause);
  }

  static GameAudioEventPayload matchResume() {
    return const GameAudioEventPayload(GameAudioEvent.matchResume);
  }

  static GameAudioEventPayload matchRestart() {
    return const GameAudioEventPayload(GameAudioEvent.matchRestart);
  }

  static GameAudioEventPayload matchExit() {
    return const GameAudioEventPayload(GameAudioEvent.matchExit);
  }

  static GameAudioEventPayload flipTriggered({required int frameId}) {
    return GameAudioEventPayload(
      GameAudioEvent.flipTriggered,
      frameId: frameId,
    );
  }

  static GameAudioEventPayload devilDistanceChanged({
    required int distanceTiles,
    required bool devilEnabled,
    required bool safeZoneImmune,
  }) {
    return GameAudioEventPayload(
      GameAudioEvent.devilDistanceChanged,
      devilDistanceTiles: distanceTiles,
      devilEnabled: devilEnabled,
      safeZoneImmune: safeZoneImmune,
    );
  }

  static GameAudioEventPayload mazeShiftStarted() {
    return const GameAudioEventPayload(GameAudioEvent.mazeShiftStarted);
  }

  static GameAudioEventPayload mazeShiftEnded() {
    return const GameAudioEventPayload(GameAudioEvent.mazeShiftEnded);
  }

  static GameAudioEventPayload safeZoneEntered() {
    return const GameAudioEventPayload(GameAudioEvent.safeZoneEntered);
  }

  static GameAudioEventPayload safeZoneExited() {
    return const GameAudioEventPayload(GameAudioEvent.safeZoneExited);
  }

  static GameAudioEventPayload timeChanged({required int secondsLeft}) {
    return GameAudioEventPayload(
      GameAudioEvent.timeChanged,
      secondsLeft: secondsLeft,
    );
  }

  static GameAudioEventPayload playerWon() {
    return const GameAudioEventPayload(GameAudioEvent.playerWon);
  }

  static GameAudioEventPayload playerLost() {
    return const GameAudioEventPayload(GameAudioEvent.playerLost);
  }
}

@immutable
class AudioDebugSnapshot {
  const AudioDebugSnapshot({
    required this.matchState,
    required this.isCalmPlaying,
    required this.isDevilPlaying,
    required this.isAlarmPlaying,
    required this.isSafeZoneImmune,
    required this.secondsLeft,
    required this.devilDistanceTiles,
    required this.lastEvent,
    required this.activeCooldowns,
    required this.busGains,
  });

  final MatchAudioState matchState;
  final bool isCalmPlaying;
  final bool isDevilPlaying;
  final bool isAlarmPlaying;
  final bool isSafeZoneImmune;
  final int? secondsLeft;
  final int? devilDistanceTiles;
  final String lastEvent;
  final Map<GameAudioEvent, Duration> activeCooldowns;
  final Map<AudioBus, double> busGains;

  static const AudioDebugSnapshot initial = AudioDebugSnapshot(
    matchState: MatchAudioState.idle,
    isCalmPlaying: false,
    isDevilPlaying: false,
    isAlarmPlaying: false,
    isSafeZoneImmune: false,
    secondsLeft: null,
    devilDistanceTiles: null,
    lastEvent: 'idle',
    activeCooldowns: <GameAudioEvent, Duration>{},
    busGains: <AudioBus, double>{
      AudioBus.master: 1,
      AudioBus.bgm: 1,
      AudioBus.ambient: 1,
      AudioBus.enemy: 1,
      AudioBus.ui: 1,
      AudioBus.action: 1,
    },
  );
}
