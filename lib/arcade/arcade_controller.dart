import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../game/daily/daily_nightmare.dart';
import 'model/boosts.dart';
import 'model/run_tally.dart';
import 'model/shop_catalog.dart';
import 'platform/portal.dart';
import 'progress_controller.dart';
import 'ui/sfx.dart';

/// One trip into a maze, as the menu sets it up.
@immutable
class GameSession {
  const GameSession({
    required this.mode,
    required this.look,
    this.stage = 1,
    this.daily,
    this.boosts = const <BoostType>{},
    this.tutorial = false,
  });

  final PlayMode mode;
  final int stage;
  final DailyChallenge? daily;

  /// Boosts taken from the inventory for this stage.
  final Set<BoostType> boosts;
  final RunnerLook look;

  /// First-time hints (move keys, the flip, the Devil).
  final bool tutorial;
}

/// A short message sliding in at the top of the screen.
@immutable
class ToastMessage {
  const ToastMessage(this.title, {this.subtitle, this.kind = ToastKind.info});

  final String title;
  final String? subtitle;
  final ToastKind kind;
}

enum ToastKind { info, achievement, reward, warning }

/// The app's services in one place: progress, the portal (ads, saves,
/// gameplay events), the Daily Nightmare record and toasts.
class ArcadeController {
  ArcadeController({required this.portal, required this.progress});

  final Portal portal;
  final ProgressController progress;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final ValueNotifier<ToastMessage?> toast = ValueNotifier<ToastMessage?>(null);
  final List<ToastMessage> _toastQueue = <ToastMessage>[];
  Timer? _toastTimer;

  // ---------------------------------------------------------------------------
  // Toasts
  // ---------------------------------------------------------------------------

  void showToast(ToastMessage message) {
    _toastQueue.add(message);
    if (toast.value == null) _nextToast();
  }

  void _nextToast() {
    _toastTimer?.cancel();
    if (_toastQueue.isEmpty) {
      toast.value = null;
      return;
    }
    toast.value = _toastQueue.removeAt(0);
    if (toast.value!.kind == ToastKind.achievement) {
      Sfx.instance.play(Sound.levelup, volume: 0.55);
    }
    _toastTimer = Timer(const Duration(milliseconds: 2600), () {
      toast.value = null;
      _toastTimer = Timer(const Duration(milliseconds: 300), _nextToast);
    });
  }

  /// Announces achievements finished since the last check.
  void announceAchievements() {
    for (final a in progress.takeNewAchievements()) {
      showToast(
        ToastMessage(
          'ACHIEVEMENT: ${a.title}',
          subtitle: 'Claim +${a.souls} souls in Trophies',
          kind: ToastKind.achievement,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Ads
  // ---------------------------------------------------------------------------

  bool _adBusy = false;

  /// Plays a rewarded video. True when the reward should be given (the video
  /// finished, or there is no ad system at all here).
  Future<bool> watchRewarded() async {
    if (_adBusy) return false;
    _adBusy = true;
    portal.gameplayStop();
    try {
      final outcome = await portal.rewardedAd(
        onStarted: () => Sfx.instance.setAdPlaying(true),
      );
      switch (outcome) {
        case AdOutcome.finished:
        case AdOutcome.unavailable:
          return true;
        case AdOutcome.failed:
          showToast(
            const ToastMessage(
              'No video right now',
              subtitle: 'Try again in a moment.',
              kind: ToastKind.warning,
            ),
          );
          return false;
      }
    } finally {
      Sfx.instance.setAdPlaying(false);
      _adBusy = false;
    }
  }

  /// A midgame ad between stages when one is due.
  Future<void> midgameIfDue() async {
    if (_adBusy || !progress.midgameDue()) return;
    _adBusy = true;
    portal.gameplayStop();
    try {
      final outcome = await portal.midgameAd(
        onStarted: () => Sfx.instance.setAdPlaying(true),
      );
      if (outcome != AdOutcome.unavailable) progress.markMidgameShown();
    } finally {
      Sfx.instance.setAdPlaying(false);
      _adBusy = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Daily Nightmare record (streak and today's tries)
  // ---------------------------------------------------------------------------

  static const String _dailyKey = 'fearflip.daily.v1';

  DailyStreak _streak = const DailyStreak();
  DailyDayRecord? _record;

  DailyChallenge get todaysDaily => DailyChallenge.forDate(DateTime.now());

  int get dailyStreakDays => _streak.currentOn(todaysDaily.dayIndex);
  int get dailyBestStreak => _streak.best;
  int get dailyFreezes => _streak.freezes;
  bool get dailyEscapedToday => _streak.escapedOn(todaysDaily.dayIndex);

  int? get dailyBestToday {
    final record = _record;
    return record != null && record.day == todaysDaily.dayIndex
        ? record.bestSeconds
        : null;
  }

  Future<void> loadDaily() async {
    try {
      final raw = await portal.read(_dailyKey);
      if (raw == null || raw.isEmpty) return;
      final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
      int? n(String k) => (json[k] as num?)?.toInt();
      _streak = DailyStreak(
        current: n('streak') ?? 0,
        best: n('best') ?? 0,
        freezes: n('freezes') ?? DailyStreak.startingFreezes,
        lastEscapeDay: n('last'),
      );
      final day = n('day');
      _record = day == null
          ? null
          : DailyDayRecord(
              day: day,
              deaths: n('deaths') ?? 0,
              bestSeconds: n('bestSeconds'),
              deathsBeforeEscape: n('before'),
            );
    } catch (error) {
      debugPrint('[Daily] load failed: $error');
    }
  }

  Future<void> _saveDaily() async {
    final record = _record;
    await portal.write(
      _dailyKey,
      jsonEncode(<String, dynamic>{
        'streak': _streak.current,
        'best': _streak.best,
        'freezes': _streak.freezes,
        'last': _streak.lastEscapeDay,
        if (record != null) ...{
          'day': record.day,
          'deaths': record.deaths,
          'bestSeconds': record.bestSeconds,
          'before': record.deathsBeforeEscape,
        },
      }),
    );
  }

  DailyDayRecord _recordFor(int day) {
    final record = _record;
    return record != null && record.day == day ? record : DailyDayRecord(day: day);
  }

  Future<void> recordDailyDeath(DailyChallenge daily) async {
    _record = _recordFor(daily.dayIndex).withDeath();
    await _saveDaily();
  }

  Future<DailySummary> recordDailyEscape(
    DailyChallenge daily,
    DailyRunResult result,
  ) async {
    final record = _recordFor(daily.dayIndex).withEscape(result.seconds);
    _record = record;
    _streak = _streak.recordEscape(daily.dayIndex);
    await _saveDaily();
    final streak = _streak.currentOn(daily.dayIndex);
    final best = record.bestSeconds ?? result.seconds;
    final deaths = record.deathsBeforeEscape ?? 0;
    return DailySummary(
      number: daily.number,
      seconds: result.seconds,
      bestSeconds: best,
      keys: result.keys,
      deaths: deaths,
      streak: streak,
      freezes: _streak.freezes,
      shareText: dailyShareText(
        number: daily.number,
        seconds: best,
        keys: result.keys,
        deaths: deaths,
        streak: streak,
      ),
    );
  }

  void dispose() {
    _toastTimer?.cancel();
    toast.dispose();
  }
}

/// Hands the [ArcadeController] to every screen.
class ArcadeScope extends InheritedWidget {
  const ArcadeScope({required this.arcade, required super.child, super.key});

  final ArcadeController arcade;

  static ArcadeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ArcadeScope>();
    assert(scope != null, 'No ArcadeScope above this widget');
    return scope!.arcade;
  }

  @override
  bool updateShouldNotify(covariant ArcadeScope oldWidget) =>
      oldWidget.arcade != arcade;
}
