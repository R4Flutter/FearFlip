import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/ads_facade.dart';
import 'portal.dart';

Portal createPortal() => MobilePortal();

/// Phones: saves in SharedPreferences, ads through the existing AdMob/Unity
/// facade. Gameplay events are no-ops (they are a web-portal concept).
class MobilePortal implements Portal {
  final ValueNotifier<bool> _muted = ValueNotifier<bool>(false);
  SharedPreferences? _prefs;

  @override
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (error) {
      debugPrint('[Portal] prefs unavailable: $error');
    }
  }

  @override
  String get environment => 'mobile';

  @override
  bool get isWeb => false;

  @override
  void finishLoading() {}

  @override
  void gameplayStart() {}

  @override
  void gameplayStop() {}

  @override
  void happyTime() {}

  @override
  Future<AdOutcome> rewardedAd({VoidCallback? onStarted}) async {
    try {
      onStarted?.call();
      final rewarded = await AdsFacade.instance.showRewardedForRevive();
      return rewarded ? AdOutcome.finished : AdOutcome.failed;
    } catch (_) {
      return AdOutcome.unavailable;
    }
  }

  @override
  Future<AdOutcome> midgameAd({VoidCallback? onStarted}) async {
    try {
      final shown = await AdsFacade.instance.showInterstitialAfterGameOver();
      return shown ? AdOutcome.finished : AdOutcome.unavailable;
    } catch (_) {
      return AdOutcome.unavailable;
    }
  }

  @override
  ValueListenable<bool> get portalMuted => _muted;

  @override
  Future<String?> read(String key) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> write(String key, String value) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}
