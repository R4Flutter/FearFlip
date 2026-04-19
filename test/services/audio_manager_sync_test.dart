import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:fearflipgame/services/audio_manager.dart';
import 'package:fearflipgame/services/game_audio_event.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final binaryMessenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late AudioManager manager;

  late _FakeAudioplayersPlatform fakeAudioPlatform;
  late _FakeGlobalAudioplayersPlatform fakeGlobalAudioPlatform;
  late _FakeJustAudioPlatform fakeJustAudioPlatform;

  late AudioplayersPlatformInterface originalAudioPlatform;
  late GlobalAudioplayersPlatformInterface originalGlobalAudioPlatform;
  late JustAudioPlatform originalJustAudioPlatform;
  late PathProviderPlatform originalPathProviderPlatform;

  setUpAll(() async {
    originalAudioPlatform = AudioplayersPlatformInterface.instance;
    originalGlobalAudioPlatform = GlobalAudioplayersPlatformInterface.instance;
    originalJustAudioPlatform = JustAudioPlatform.instance;
    originalPathProviderPlatform = PathProviderPlatform.instance;

    fakeAudioPlatform = _FakeAudioplayersPlatform();
    fakeGlobalAudioPlatform = _FakeGlobalAudioplayersPlatform();
    fakeJustAudioPlatform = _FakeJustAudioPlatform();

    AudioplayersPlatformInterface.instance = fakeAudioPlatform;
    GlobalAudioplayersPlatformInterface.instance = fakeGlobalAudioPlatform;
    JustAudioPlatform.instance = fakeJustAudioPlatform;
    PathProviderPlatform.instance = _FakePathProviderPlatform();

    binaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'),
      (MethodCall _) async => null,
    );

    binaryMessenger.setMockMessageHandler('flutter/assets', (
      ByteData? message,
    ) async {
      final key = const StringCodec().decodeMessage(message);
      if (key == null || key.isEmpty) {
        return null;
      }

      final relativePath = key.startsWith('/') ? key.substring(1) : key;
      final file = File(relativePath.replaceAll('/', Platform.pathSeparator));
      if (!await file.exists()) {
        return null;
      }

      final bytes = await file.readAsBytes();
      final typed = Uint8List.fromList(bytes);
      return ByteData.view(typed.buffer);
    });

    manager = AudioManager.instance;
    await manager.handlePayload(GameAudioEventPayload.matchExit());
  });

  setUp(() async {
    fakeAudioPlatform.clear();
    fakeGlobalAudioPlatform.clear();

    await manager.handlePayload(GameAudioEventPayload.matchExit());
    await Future<void>.delayed(const Duration(milliseconds: 20));

    fakeAudioPlatform.clear();
    fakeGlobalAudioPlatform.clear();
  });

  tearDownAll(() async {
    binaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'),
      null,
    );
    binaryMessenger.setMockMessageHandler('flutter/assets', null);

    AudioplayersPlatformInterface.instance = originalAudioPlatform;
    GlobalAudioplayersPlatformInterface.instance = originalGlobalAudioPlatform;
    JustAudioPlatform.instance = originalJustAudioPlatform;
    PathProviderPlatform.instance = originalPathProviderPlatform;
  });

  group('AudioManager sync integration', () {
    test('matchStart -> calm starts (delay policy)', () async {
      await manager.handlePayload(GameAudioEventPayload.matchStart());

      expect(manager.isCalmPlaying, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 2300));

      expect(manager.isCalmPlaying, isTrue);
      expect(manager.debugSnapshot.value.matchState, MatchAudioState.active);
    });

    test('devil distance 7 -> 6 starts loop', () async {
      await manager.handlePayload(GameAudioEventPayload.matchStart());

      await manager.handlePayload(
        GameAudioEventPayload.devilDistanceChanged(
          distanceTiles: 7,
          devilEnabled: true,
          safeZoneImmune: false,
        ),
      );
      expect(manager.isDevilPlaying, isFalse);

      await manager.handlePayload(
        GameAudioEventPayload.devilDistanceChanged(
          distanceTiles: 6,
          devilEnabled: true,
          safeZoneImmune: false,
        ),
      );

      expect(manager.isDevilPlaying, isTrue);
      expect(manager.debugSnapshot.value.devilDistanceTiles, 6);
    });

    test('devil distance 6 -> 7 stops loop immediately', () async {
      await manager.handlePayload(GameAudioEventPayload.matchStart());

      await manager.handlePayload(
        GameAudioEventPayload.devilDistanceChanged(
          distanceTiles: 6,
          devilEnabled: true,
          safeZoneImmune: false,
        ),
      );
      expect(manager.isDevilPlaying, isTrue);

      await manager.handlePayload(
        GameAudioEventPayload.devilDistanceChanged(
          distanceTiles: 7,
          devilEnabled: true,
          safeZoneImmune: false,
        ),
      );

      expect(manager.isDevilPlaying, isFalse);
      expect(manager.debugSnapshot.value.devilDistanceTiles, 7);
    });

    test('latest far state stops devil even if flip is queued first', () async {
      await manager.handlePayload(GameAudioEventPayload.matchStart());

      await manager.handlePayload(
        GameAudioEventPayload.devilDistanceChanged(
          distanceTiles: 6,
          devilEnabled: true,
          safeZoneImmune: false,
        ),
      );
      expect(manager.isDevilPlaying, isTrue);

      final farFuture = manager.handlePayload(
        GameAudioEventPayload.devilDistanceChanged(
          distanceTiles: 7,
          devilEnabled: true,
          safeZoneImmune: false,
        ),
      );

      final flipFuture = manager.handlePayload(
        GameAudioEventPayload.flipTriggered(frameId: 777),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(manager.isDevilPlaying, isFalse);

      await Future.wait<void>(<Future<void>>[farFuture, flipFuture]);
      expect(manager.isDevilPlaying, isFalse);
      expect(manager.debugSnapshot.value.devilDistanceTiles, 7);
    });

    test(
      'burst distance updates coalesce and latest far keeps devil off',
      () async {
        await manager.handlePayload(GameAudioEventPayload.matchStart());

        final futures = <Future<void>>[
          manager.handlePayload(
            GameAudioEventPayload.devilDistanceChanged(
              distanceTiles: 6,
              devilEnabled: true,
              safeZoneImmune: false,
            ),
          ),
          manager.handlePayload(
            GameAudioEventPayload.devilDistanceChanged(
              distanceTiles: 5,
              devilEnabled: true,
              safeZoneImmune: false,
            ),
          ),
          manager.handlePayload(
            GameAudioEventPayload.devilDistanceChanged(
              distanceTiles: 4,
              devilEnabled: true,
              safeZoneImmune: false,
            ),
          ),
          manager.handlePayload(
            GameAudioEventPayload.devilDistanceChanged(
              distanceTiles: 7,
              devilEnabled: true,
              safeZoneImmune: false,
            ),
          ),
        ];

        await Future.wait<void>(futures);
        expect(manager.isDevilPlaying, isFalse);
        expect(manager.debugSnapshot.value.devilDistanceTiles, 7);
      },
    );

    test('devil disabled while far stops loop immediately', () async {
      await manager.handlePayload(GameAudioEventPayload.matchStart());

      await manager.handlePayload(
        GameAudioEventPayload.devilDistanceChanged(
          distanceTiles: 6,
          devilEnabled: true,
          safeZoneImmune: false,
        ),
      );
      expect(manager.isDevilPlaying, isTrue);

      await manager.handlePayload(
        GameAudioEventPayload.devilDistanceChanged(
          distanceTiles: 12,
          devilEnabled: false,
          safeZoneImmune: false,
        ),
      );

      expect(manager.isDevilPlaying, isFalse);
      expect(manager.debugSnapshot.value.devilDistanceTiles, 12);
    });

    test('devil close + flip event still plays flip SFX', () async {
      await manager.handlePayload(GameAudioEventPayload.matchStart());
      await manager.handlePayload(
        GameAudioEventPayload.devilDistanceChanged(
          distanceTiles: 6,
          devilEnabled: true,
          safeZoneImmune: false,
        ),
      );

      await manager.handlePayload(
        GameAudioEventPayload.flipTriggered(frameId: 101),
      );

      expect(manager.isDevilPlaying, isTrue);
      expect(
        _hasSourceUrlContaining(fakeAudioPlatform, 'fahhhhh_flippingtime.mp3'),
        isTrue,
      );
    });

    test('plays fahh on every unique maze flip frame', () async {
      await manager.handlePayload(GameAudioEventPayload.matchStart());

      const frames = <int>[301, 302, 303, 304, 305, 306];
      for (final frame in frames) {
        await manager.handlePayload(
          GameAudioEventPayload.flipTriggered(frameId: frame),
        );
      }

      expect(
        _countSourceUrlContaining(fakeAudioPlatform, 'flippingtime.mp3'),
        equals(frames.length),
      );
    });

    test('duplicate flip frame id is deduped', () async {
      await manager.handlePayload(GameAudioEventPayload.matchStart());

      await manager.handlePayload(
        GameAudioEventPayload.flipTriggered(frameId: 410),
      );
      await manager.handlePayload(
        GameAudioEventPayload.flipTriggered(frameId: 410),
      );

      expect(
        _countSourceUrlContaining(fakeAudioPlatform, 'flippingtime.mp3'),
        equals(1),
      );
    });

    test('retries fahh once when initial playback fails', () async {
      await manager.handlePayload(GameAudioEventPayload.matchStart());
      fakeAudioPlatform.failNextSetSourceUrlContaining('flippingtime.mp3');

      await manager.handlePayload(
        GameAudioEventPayload.flipTriggered(frameId: 501),
      );

      expect(fakeAudioPlatform.injectedSetSourceFailures, equals(1));
      expect(
        _countSourceUrlContaining(fakeAudioPlatform, 'flippingtime.mp3'),
        equals(2),
      );
    });

    test('flip SFX continues across devil near/far transitions', () async {
      await manager.handlePayload(GameAudioEventPayload.matchStart());

      await manager.handlePayload(
        GameAudioEventPayload.devilDistanceChanged(
          distanceTiles: 6,
          devilEnabled: true,
          safeZoneImmune: false,
        ),
      );
      await manager.handlePayload(
        GameAudioEventPayload.flipTriggered(frameId: 201),
      );

      await manager.handlePayload(
        GameAudioEventPayload.devilDistanceChanged(
          distanceTiles: 7,
          devilEnabled: true,
          safeZoneImmune: false,
        ),
      );
      expect(manager.isDevilPlaying, isFalse);

      await manager.handlePayload(
        GameAudioEventPayload.flipTriggered(frameId: 202),
      );

      await manager.handlePayload(
        GameAudioEventPayload.devilDistanceChanged(
          distanceTiles: 6,
          devilEnabled: true,
          safeZoneImmune: false,
        ),
      );
      await manager.handlePayload(
        GameAudioEventPayload.flipTriggered(frameId: 203),
      );

      expect(
        _countSourceUrlContaining(
          fakeAudioPlatform,
          'fahhhhh_flippingtime.mp3',
        ),
        greaterThanOrEqualTo(3),
      );
    });

    test('time 10 starts alarm', () async {
      await manager.handlePayload(GameAudioEventPayload.matchStart());
      await manager.handlePayload(
        GameAudioEventPayload.timeChanged(secondsLeft: 10),
      );

      expect(manager.isAlarmPlaying, isTrue);
      expect(manager.debugSnapshot.value.secondsLeft, 10);
    });

    test('win at 5 seconds left stops alarm and plays win', () async {
      await manager.handlePayload(GameAudioEventPayload.matchStart());
      await manager.handlePayload(
        GameAudioEventPayload.timeChanged(secondsLeft: 5),
      );
      expect(manager.isAlarmPlaying, isTrue);

      await manager.handlePayload(GameAudioEventPayload.playerWon());

      expect(manager.isWon, isTrue);
      expect(manager.isAlarmPlaying, isFalse);
      expect(manager.debugSnapshot.value.matchState, MatchAudioState.won);
      expect(
        _hasSourceUrlContaining(fakeAudioPlatform, 'winning_soundeffect.mp3'),
        isTrue,
      );
    });

    test('devil catch stops devil immediately and plays loss', () async {
      await manager.handlePayload(GameAudioEventPayload.matchStart());
      await manager.handlePayload(
        GameAudioEventPayload.devilDistanceChanged(
          distanceTiles: 6,
          devilEnabled: true,
          safeZoneImmune: false,
        ),
      );
      expect(manager.isDevilPlaying, isTrue);

      await manager.handlePayload(GameAudioEventPayload.playerLost());

      expect(manager.isLost, isTrue);
      expect(manager.isDevilPlaying, isFalse);
      expect(manager.debugSnapshot.value.matchState, MatchAudioState.lost);
      expect(
        _hasAnySourceUrlContaining(fakeAudioPlatform, const <String>[
          'gamelost_soundeffect.mp3',
          'playerlost_soundeffect.mp3',
          'game_lost_soundeffect.mp3',
        ]),
        isTrue,
      );
    });

    test('restart/revive/exit after loss clears state and channels', () async {
      await manager.handlePayload(GameAudioEventPayload.matchStart());
      await manager.handlePayload(
        GameAudioEventPayload.devilDistanceChanged(
          distanceTiles: 6,
          devilEnabled: true,
          safeZoneImmune: false,
        ),
      );
      await manager.handlePayload(GameAudioEventPayload.playerLost());

      expect(manager.isLost, isTrue);
      expect(manager.debugSnapshot.value.matchState, MatchAudioState.lost);

      await manager.handlePayload(GameAudioEventPayload.matchRestart());

      expect(manager.isLost, isFalse);
      expect(manager.isWon, isFalse);
      expect(manager.isMatchActive, isTrue);
      expect(manager.isCalmPlaying, isFalse);
      expect(manager.isDevilPlaying, isFalse);
      expect(manager.isAlarmPlaying, isFalse);
      expect(manager.debugSnapshot.value.matchState, MatchAudioState.active);

      await manager.handlePayload(GameAudioEventPayload.matchExit());

      expect(manager.isMatchActive, isFalse);
      expect(manager.isLost, isFalse);
      expect(manager.isWon, isFalse);
      expect(manager.isCalmPlaying, isFalse);
      expect(manager.isDevilPlaying, isFalse);
      expect(manager.isAlarmPlaying, isFalse);
      expect(manager.debugSnapshot.value.matchState, MatchAudioState.exited);
      expect(
        manager.debugSnapshot.value.lastEvent,
        GameAudioEvent.matchExit.name,
      );
      expect(
        fakeAudioPlatform.calls.any((call) => call.method == 'stop'),
        isTrue,
      );
    });
  });
}

bool _hasSourceUrlContaining(
  _FakeAudioplayersPlatform platform,
  String fragment,
) {
  return platform.calls.any((call) {
    if (call.method != 'setSourceUrl' || call.value is! String) {
      return false;
    }
    return (call.value as String).contains(fragment);
  });
}

bool _hasAnySourceUrlContaining(
  _FakeAudioplayersPlatform platform,
  List<String> fragments,
) {
  for (final fragment in fragments) {
    if (_hasSourceUrlContaining(platform, fragment)) {
      return true;
    }
  }
  return false;
}

int _countSourceUrlContaining(
  _FakeAudioplayersPlatform platform,
  String fragment,
) {
  return platform.calls.where((call) {
    if (call.method != 'setSourceUrl' || call.value is! String) {
      return false;
    }
    return (call.value as String).contains(fragment);
  }).length;
}

class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getTemporaryPath() async {
    return Directory.systemTemp.path;
  }
}

class _FakeCall {
  _FakeCall({required this.id, required this.method, this.value});

  final String id;
  final String method;
  final Object? value;
}

class _FakeAudioplayersPlatform extends AudioplayersPlatformInterface {
  final List<_FakeCall> calls = <_FakeCall>[];
  final Map<String, StreamController<AudioEvent>> eventStreamControllers =
      <String, StreamController<AudioEvent>>{};
  String? _failNextSetSourceUrlContains;
  int injectedSetSourceFailures = 0;

  void failNextSetSourceUrlContaining(String fragment) {
    _failNextSetSourceUrlContains = fragment;
  }

  void clear() {
    calls.clear();
    _failNextSetSourceUrlContains = null;
    injectedSetSourceFailures = 0;
  }

  @override
  Future<void> create(String playerId) async {
    calls.add(_FakeCall(id: playerId, method: 'create'));
    eventStreamControllers[playerId] = StreamController<AudioEvent>.broadcast();
  }

  @override
  Future<void> dispose(String playerId) async {
    calls.add(_FakeCall(id: playerId, method: 'dispose'));
    await eventStreamControllers[playerId]?.close();
    eventStreamControllers.remove(playerId);
  }

  @override
  Future<void> emitError(String playerId, String code, String message) async {
    calls.add(_FakeCall(id: playerId, method: 'emitError'));
  }

  @override
  Future<void> emitLog(String playerId, String message) async {
    calls.add(_FakeCall(id: playerId, method: 'emitLog'));
  }

  @override
  Future<int?> getCurrentPosition(String playerId) async {
    calls.add(_FakeCall(id: playerId, method: 'getCurrentPosition'));
    return 0;
  }

  @override
  Future<int?> getDuration(String playerId) async {
    calls.add(_FakeCall(id: playerId, method: 'getDuration'));
    return 0;
  }

  @override
  Future<void> pause(String playerId) async {
    calls.add(_FakeCall(id: playerId, method: 'pause'));
  }

  @override
  Future<void> release(String playerId) async {
    calls.add(_FakeCall(id: playerId, method: 'release'));
  }

  @override
  Future<void> resume(String playerId) async {
    calls.add(_FakeCall(id: playerId, method: 'resume'));
  }

  @override
  Future<void> seek(String playerId, Duration position) async {
    calls.add(_FakeCall(id: playerId, method: 'seek', value: position));
  }

  @override
  Future<void> setAudioContext(
    String playerId,
    AudioContext audioContext,
  ) async {
    calls.add(
      _FakeCall(id: playerId, method: 'setAudioContext', value: audioContext),
    );
  }

  @override
  Future<void> setBalance(String playerId, double balance) async {
    calls.add(_FakeCall(id: playerId, method: 'setBalance', value: balance));
  }

  @override
  Future<void> setPlaybackRate(String playerId, double playbackRate) async {
    calls.add(
      _FakeCall(id: playerId, method: 'setPlaybackRate', value: playbackRate),
    );
  }

  @override
  Future<void> setPlayerMode(String playerId, PlayerMode playerMode) async {
    calls.add(
      _FakeCall(id: playerId, method: 'setPlayerMode', value: playerMode),
    );
  }

  @override
  Future<void> setReleaseMode(String playerId, ReleaseMode releaseMode) async {
    calls.add(
      _FakeCall(id: playerId, method: 'setReleaseMode', value: releaseMode),
    );
  }

  @override
  Future<void> setSourceBytes(
    String playerId,
    Uint8List bytes, {
    String? mimeType,
  }) async {
    calls.add(_FakeCall(id: playerId, method: 'setSourceBytes', value: bytes));
    eventStreamControllers[playerId]?.add(
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
  }

  @override
  Future<void> setSourceUrl(
    String playerId,
    String url, {
    bool? isLocal,
    String? mimeType,
  }) async {
    calls.add(_FakeCall(id: playerId, method: 'setSourceUrl', value: url));
    final failFragment = _failNextSetSourceUrlContains;
    if (failFragment != null && url.contains(failFragment)) {
      _failNextSetSourceUrlContains = null;
      injectedSetSourceFailures += 1;
      throw PlatformException(
        code: 'mock_set_source_fail',
        message: 'Injected setSourceUrl failure for testing',
      );
    }
    eventStreamControllers[playerId]?.add(
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
  }

  @override
  Future<void> setVolume(String playerId, double volume) async {
    calls.add(_FakeCall(id: playerId, method: 'setVolume', value: volume));
  }

  @override
  Future<void> stop(String playerId) async {
    calls.add(_FakeCall(id: playerId, method: 'stop'));
  }

  @override
  Stream<AudioEvent> getEventStream(String playerId) {
    calls.add(_FakeCall(id: playerId, method: 'getEventStream'));
    return eventStreamControllers[playerId]!.stream;
  }
}

class _FakeGlobalCall {
  _FakeGlobalCall({required this.method, this.value});

  final String method;
  final Object? value;
}

class _FakeGlobalAudioplayersPlatform
    extends GlobalAudioplayersPlatformInterface {
  final List<_FakeGlobalCall> calls = <_FakeGlobalCall>[];
  final StreamController<GlobalAudioEvent> eventStreamController =
      StreamController<GlobalAudioEvent>.broadcast();

  void clear() {
    calls.clear();
  }

  @override
  Future<void> init() async {
    calls.add(_FakeGlobalCall(method: 'init'));
  }

  @override
  Future<void> setGlobalAudioContext(AudioContext ctx) async {
    calls.add(_FakeGlobalCall(method: 'setGlobalAudioContext', value: ctx));
  }

  @override
  Future<void> emitGlobalLog(String message) async {
    calls.add(_FakeGlobalCall(method: 'emitGlobalLog', value: message));
  }

  @override
  Future<void> emitGlobalError(String code, String message) async {
    calls.add(_FakeGlobalCall(method: 'emitGlobalError', value: message));
  }

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() {
    calls.add(_FakeGlobalCall(method: 'getGlobalEventStream'));
    return eventStreamController.stream;
  }
}

class _FakeJustAudioPlatform extends JustAudioPlatform
    with MockPlatformInterfaceMixin {
  final Map<String, _FakeJustAudioPlayer> players =
      <String, _FakeJustAudioPlayer>{};

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    final player = _FakeJustAudioPlayer(request.id);
    players[request.id] = player;
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
    final player = players.remove(request.id);
    if (player != null) {
      await player.dispose(DisposeRequest());
    }
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async {
    for (final player in players.values) {
      await player.dispose(DisposeRequest());
    }
    players.clear();
    return DisposeAllPlayersResponse();
  }
}

class _FakeJustAudioPlayer extends AudioPlayerPlatform {
  _FakeJustAudioPlayer(String id) : super(id);

  final StreamController<PlaybackEventMessage> _eventController =
      StreamController<PlaybackEventMessage>.broadcast();
  final StreamController<PlayerDataMessage> _dataController =
      StreamController<PlayerDataMessage>.broadcast();

  ProcessingStateMessage _processingState = ProcessingStateMessage.idle;
  Duration _updatePosition = Duration.zero;
  DateTime _updateTime = DateTime.now();
  Duration? _duration;
  int? _index;

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream =>
      _eventController.stream;

  @override
  Stream<PlayerDataMessage> get playerDataMessageStream =>
      _dataController.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    _processingState = ProcessingStateMessage.loading;
    _emitPlaybackEvent();

    _duration = const Duration(seconds: 30);
    _index = request.initialIndex ?? 0;
    _updatePosition = request.initialPosition ?? Duration.zero;
    _updateTime = DateTime.now();

    _processingState = ProcessingStateMessage.ready;
    _emitPlaybackEvent();
    return LoadResponse(duration: _duration);
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    _dataController.add(PlayerDataMessage(playing: true));
    _emitPlaybackEvent();
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    _dataController.add(PlayerDataMessage(playing: false));
    _emitPlaybackEvent();
    return PauseResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async {
    _dataController.add(PlayerDataMessage(volume: request.volume));
    return SetVolumeResponse();
  }

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async {
    _dataController.add(PlayerDataMessage(speed: request.speed));
    return SetSpeedResponse();
  }

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async {
    _dataController.add(PlayerDataMessage(pitch: request.pitch));
    return SetPitchResponse();
  }

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
    SetSkipSilenceRequest request,
  ) async {
    return SetSkipSilenceResponse();
  }

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async {
    _dataController.add(PlayerDataMessage(loopMode: request.loopMode));
    return SetLoopModeResponse();
  }

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async {
    _dataController.add(PlayerDataMessage(shuffleMode: request.shuffleMode));
    return SetShuffleModeResponse();
  }

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
    SetShuffleOrderRequest request,
  ) async {
    return SetShuffleOrderResponse();
  }

  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse>
  setAutomaticallyWaitsToMinimizeStalling(
    SetAutomaticallyWaitsToMinimizeStallingRequest request,
  ) async {
    return SetAutomaticallyWaitsToMinimizeStallingResponse();
  }

  @override
  Future<SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse>
  setCanUseNetworkResourcesForLiveStreamingWhilePaused(
    SetCanUseNetworkResourcesForLiveStreamingWhilePausedRequest request,
  ) async {
    return SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse();
  }

  @override
  Future<SetPreferredPeakBitRateResponse> setPreferredPeakBitRate(
    SetPreferredPeakBitRateRequest request,
  ) async {
    return SetPreferredPeakBitRateResponse();
  }

  @override
  Future<SetAllowsExternalPlaybackResponse> setAllowsExternalPlayback(
    SetAllowsExternalPlaybackRequest request,
  ) async {
    return SetAllowsExternalPlaybackResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    _updatePosition = request.position ?? Duration.zero;
    _index = request.index ?? _index ?? 0;
    _updateTime = DateTime.now();
    _emitPlaybackEvent();
    return SeekResponse();
  }

  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
    SetAndroidAudioAttributesRequest request,
  ) async {
    return SetAndroidAudioAttributesResponse();
  }

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    _processingState = ProcessingStateMessage.idle;
    _emitPlaybackEvent();
    await _eventController.close();
    await _dataController.close();
    return DisposeResponse();
  }

  @override
  Future<ConcatenatingInsertAllResponse> concatenatingInsertAll(
    ConcatenatingInsertAllRequest request,
  ) async {
    return ConcatenatingInsertAllResponse();
  }

  @override
  Future<ConcatenatingRemoveRangeResponse> concatenatingRemoveRange(
    ConcatenatingRemoveRangeRequest request,
  ) async {
    return ConcatenatingRemoveRangeResponse();
  }

  @override
  Future<ConcatenatingMoveResponse> concatenatingMove(
    ConcatenatingMoveRequest request,
  ) async {
    return ConcatenatingMoveResponse();
  }

  @override
  Future<AudioEffectSetEnabledResponse> audioEffectSetEnabled(
    AudioEffectSetEnabledRequest request,
  ) async {
    return AudioEffectSetEnabledResponse();
  }

  @override
  Future<AndroidLoudnessEnhancerSetTargetGainResponse>
  androidLoudnessEnhancerSetTargetGain(
    AndroidLoudnessEnhancerSetTargetGainRequest request,
  ) async {
    return AndroidLoudnessEnhancerSetTargetGainResponse();
  }

  @override
  Future<AndroidEqualizerGetParametersResponse> androidEqualizerGetParameters(
    AndroidEqualizerGetParametersRequest request,
  ) async {
    return AndroidEqualizerGetParametersResponse(
      parameters: AndroidEqualizerParametersMessage(
        minDecibels: 0,
        maxDecibels: 0,
        bands: const <AndroidEqualizerBandMessage>[],
      ),
    );
  }

  @override
  Future<AndroidEqualizerBandSetGainResponse> androidEqualizerBandSetGain(
    AndroidEqualizerBandSetGainRequest request,
  ) async {
    return AndroidEqualizerBandSetGainResponse();
  }

  @override
  Future<SetWebCrossOriginResponse> setWebCrossOrigin(
    SetWebCrossOriginRequest request,
  ) async {
    return SetWebCrossOriginResponse();
  }

  @override
  Future<SetWebSinkIdResponse> setWebSinkId(SetWebSinkIdRequest request) async {
    return SetWebSinkIdResponse();
  }

  void _emitPlaybackEvent() {
    if (_eventController.isClosed) {
      return;
    }

    _eventController.add(
      PlaybackEventMessage(
        processingState: _processingState,
        updatePosition: _updatePosition,
        updateTime: _updateTime,
        bufferedPosition: _updatePosition,
        duration: _duration,
        icyMetadata: null,
        currentIndex: _index,
        androidAudioSessionId: null,
        errorCode: null,
        errorMessage: null,
      ),
    );
  }
}
