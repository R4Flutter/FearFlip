import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import 'portal.dart';

Portal createPortal() => WebPortal();

/// `window.ffcg`, the bridge in web/index.html around the CrazyGames SDK.
@JS('ffcg')
external _Ffcg? get _bridge;

extension type _Ffcg(JSObject _) implements JSObject {
  external JSPromise<JSString> init();
  external JSString env();
  external void loadingStop();
  external void gameplayStart();
  external void gameplayStop();
  external void happytime();
  external JSPromise<JSString> requestAd(JSString type, JSFunction? onStarted);
  external JSString? getItem(JSString key);
  external void setItem(JSString key, JSString value);
  external JSBoolean isMuted();
  external void onMuteChange(JSFunction callback);
  external void loaderDone();
}

/// The CrazyGames portal (or plain web when the SDK isn't there).
class WebPortal implements Portal {
  final ValueNotifier<bool> _muted = ValueNotifier<bool>(false);
  String _env = 'none';
  bool _initialised = false;

  @override
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    final bridge = _bridge;
    if (bridge == null) return;
    try {
      _env = (await bridge.init().toDart.timeout(
        const Duration(seconds: 6),
        onTimeout: () => 'none'.toJS,
      )).toDart;
      _muted.value = bridge.isMuted().toDart;
      bridge.onMuteChange(
        ((JSBoolean muted) {
          _muted.value = muted.toDart;
        }).toJS,
      );
    } catch (error) {
      debugPrint('[Portal] init failed: $error');
      _env = 'none';
    }
  }

  @override
  String get environment => _env;

  @override
  bool get isWeb => true;

  void _safely(void Function(_Ffcg bridge) call) {
    final bridge = _bridge;
    if (bridge == null) return;
    try {
      call(bridge);
    } catch (error) {
      debugPrint('[Portal] $error');
    }
  }

  @override
  void finishLoading() => _safely((b) {
    b.loadingStop();
    b.loaderDone();
  });

  @override
  void gameplayStart() => _safely((b) => b.gameplayStart());

  @override
  void gameplayStop() => _safely((b) => b.gameplayStop());

  @override
  void happyTime() => _safely((b) => b.happytime());

  Future<AdOutcome> _ad(String type, VoidCallback? onStarted) async {
    final bridge = _bridge;
    if (bridge == null) return AdOutcome.unavailable;
    try {
      final result =
          (await bridge
                  .requestAd(
                    type.toJS,
                    onStarted == null ? null : (() => onStarted()).toJS,
                  )
                  .toDart)
              .toDart;
      return switch (result) {
        'finished' => AdOutcome.finished,
        'unavailable' => AdOutcome.unavailable,
        _ => AdOutcome.failed,
      };
    } catch (error) {
      debugPrint('[Portal] $type ad failed: $error');
      return AdOutcome.failed;
    }
  }

  @override
  Future<AdOutcome> rewardedAd({VoidCallback? onStarted}) =>
      _ad('rewarded', onStarted);

  @override
  Future<AdOutcome> midgameAd({VoidCallback? onStarted}) =>
      _ad('midgame', onStarted);

  @override
  ValueListenable<bool> get portalMuted => _muted;

  @override
  Future<String?> read(String key) async {
    final bridge = _bridge;
    if (bridge == null) return null;
    try {
      return bridge.getItem(key.toJS)?.toDart;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async =>
      _safely((b) => b.setItem(key.toJS, value.toJS));
}
