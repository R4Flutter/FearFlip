import 'package:shared_preferences/shared_preferences.dart';

import '../game/daily/daily_nightmare.dart';

/// Saves the Daily Nightmare streak and today's tries on this device.
class DailyNightmareStore {
  const DailyNightmareStore();

  static const _streak = 'daily.v1.streak';
  static const _best = 'daily.v1.best';
  static const _freezes = 'daily.v1.freezes';
  static const _lastEscape = 'daily.v1.last_escape_day';
  static const _day = 'daily.v1.day';
  static const _deaths = 'daily.v1.deaths';
  static const _bestSeconds = 'daily.v1.best_seconds';
  static const _deathsBeforeEscape = 'daily.v1.deaths_before_escape';

  Future<(DailyStreak, DailyDayRecord?)> load() async {
    final prefs = await SharedPreferences.getInstance();
    final streak = DailyStreak(
      current: prefs.getInt(_streak) ?? 0,
      best: prefs.getInt(_best) ?? 0,
      freezes: prefs.getInt(_freezes) ?? DailyStreak.startingFreezes,
      lastEscapeDay: prefs.getInt(_lastEscape),
    );
    final day = prefs.getInt(_day);
    final record = day == null
        ? null
        : DailyDayRecord(
            day: day,
            deaths: prefs.getInt(_deaths) ?? 0,
            bestSeconds: prefs.getInt(_bestSeconds),
            deathsBeforeEscape: prefs.getInt(_deathsBeforeEscape),
          );
    return (streak, record);
  }

  Future<void> save(DailyStreak streak, DailyDayRecord? today) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_streak, streak.current);
    await prefs.setInt(_best, streak.best);
    await prefs.setInt(_freezes, streak.freezes);
    final last = streak.lastEscapeDay;
    if (last == null) {
      await prefs.remove(_lastEscape);
    } else {
      await prefs.setInt(_lastEscape, last);
    }
    if (today == null) {
      return;
    }
    await prefs.setInt(_day, today.day);
    await prefs.setInt(_deaths, today.deaths);
    final best = today.bestSeconds;
    if (best == null) {
      await prefs.remove(_bestSeconds);
    } else {
      await prefs.setInt(_bestSeconds, best);
    }
    final before = today.deathsBeforeEscape;
    if (before == null) {
      await prefs.remove(_deathsBeforeEscape);
    } else {
      await prefs.setInt(_deathsBeforeEscape, before);
    }
  }
}
