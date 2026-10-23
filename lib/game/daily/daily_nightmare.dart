import 'dart:math';

import 'package:flutter/foundation.dart';

/// The Daily Nightmare: one maze per calendar day, the same for everyone on
/// that date (like Wordle). See docs/retention_features.md.
@immutable
class DailyChallenge {
  const DailyChallenge._(this.dayIndex, this.date);

  /// The puzzle for [now]'s local calendar date.
  factory DailyChallenge.forDate(DateTime now) {
    final date = DateTime.utc(now.year, now.month, now.day);
    return DailyChallenge._(dayIndexFor(now), date);
  }

  /// Daily Nightmare #1.
  static final DateTime epoch = DateTime.utc(2026, 10, 1);

  /// Days since [epoch] for [now]'s local calendar date.
  static int dayIndexFor(DateTime now) =>
      DateTime.utc(now.year, now.month, now.day).difference(epoch).inDays;

  final int dayIndex;
  final DateTime date;

  /// The "#12" in the share text.
  int get number => dayIndex + 1;

  /// Seeds the maze (and through it the traps and boxes). Kept within 32 bits
  /// so the web build makes the same maze as the phones.
  int get seed {
    var h = (dayIndex * 0x9E37 + 0x7F4A) & 0xFFFFFFFF;
    h = ((h ^ (h >> 15)) * 0x2C1B) & 0xFFFFFFFF;
    h = ((h ^ (h >> 13)) * 0x297A) & 0xFFFFFFFF;
    return (h ^ (h >> 16)) & 0x7FFFFFFF;
  }

  /// The stage whose rules shape the maze: easiest on Monday, hardest on
  /// Sunday. None is a multiple of 6, so the walls never shift and the maze
  /// stays the same for everyone.
  int get profileStage =>
      const <int>[5, 8, 11, 14, 17, 20, 23][date.weekday - 1];

  @override
  bool operator ==(Object other) =>
      other is DailyChallenge && other.dayIndex == dayIndex;

  @override
  int get hashCode => dayIndex.hashCode;
}

/// A forgiving streak: one escape a day keeps it going, and a freeze covers a
/// missed day. Players start with one freeze and earn another every 7 days in
/// a row, holding at most [maxFreezes].
@immutable
class DailyStreak {
  const DailyStreak({
    this.current = 0,
    this.best = 0,
    this.freezes = startingFreezes,
    this.lastEscapeDay,
  });

  static const int startingFreezes = 1;
  static const int maxFreezes = 2;
  static const int freezeEvery = 7;

  final int current;
  final int best;
  final int freezes;

  /// [DailyChallenge.dayIndex] of the last escape, or null before the first.
  final int? lastEscapeDay;

  /// The streak after an escape on [day]. A second escape the same day
  /// changes nothing.
  DailyStreak recordEscape(int day) {
    final last = lastEscapeDay;
    if (last != null && day <= last) {
      return this;
    }
    var freezesLeft = freezes;
    final int next;
    if (last == null) {
      next = 1;
    } else {
      final missed = day - last - 1;
      if (missed == 0) {
        next = current + 1;
      } else if (missed <= freezesLeft) {
        freezesLeft -= missed;
        next = current + 1;
      } else {
        next = 1;
      }
    }
    if (next % freezeEvery == 0) {
      freezesLeft = min(maxFreezes, freezesLeft + 1);
    }
    return DailyStreak(
      current: next,
      best: max(best, next),
      freezes: freezesLeft,
      lastEscapeDay: day,
    );
  }

  /// The streak as it stands on [today]: still alive while the days missed
  /// since the last escape fit in the freezes.
  int currentOn(int today) {
    final last = lastEscapeDay;
    if (last == null) {
      return 0;
    }
    final missed = today - last - 1;
    if (missed <= 0) {
      return current;
    }
    return missed <= freezes ? current : 0;
  }

  /// Freezes an escape today would use.
  int freezesNeededOn(int today) {
    final last = lastEscapeDay;
    if (last == null) {
      return 0;
    }
    final missed = today - last - 1;
    return missed > 0 && missed <= freezes ? missed : 0;
  }

  bool escapedOn(int day) => lastEscapeDay == day;
}

/// One day's tries at the Daily Nightmare.
@immutable
class DailyDayRecord {
  const DailyDayRecord({
    required this.day,
    this.deaths = 0,
    this.bestSeconds,
    this.deathsBeforeEscape,
  });

  final int day;

  /// Every failed try today.
  final int deaths;

  /// The fastest escape today, or null before the first one.
  final int? bestSeconds;

  /// Failed tries before the first escape (the 💀 in the share text).
  final int? deathsBeforeEscape;

  bool get escaped => bestSeconds != null;

  DailyDayRecord withDeath() => DailyDayRecord(
    day: day,
    deaths: deaths + 1,
    bestSeconds: bestSeconds,
    deathsBeforeEscape: deathsBeforeEscape,
  );

  DailyDayRecord withEscape(int seconds) => DailyDayRecord(
    day: day,
    deaths: deaths,
    bestSeconds: bestSeconds == null ? seconds : min(bestSeconds!, seconds),
    deathsBeforeEscape: deathsBeforeEscape ?? deaths,
  );
}

/// How one escape went, from the game.
@immutable
class DailyRunResult {
  const DailyRunResult({required this.seconds, required this.keys});

  /// Seconds the escape took.
  final int seconds;

  /// Keys collected (the 🗝 in the share text).
  final int keys;
}

/// What the result screen shows after an escape.
@immutable
class DailySummary {
  const DailySummary({
    required this.number,
    required this.seconds,
    required this.bestSeconds,
    required this.keys,
    required this.deaths,
    required this.streak,
    required this.freezes,
    required this.shareText,
  });

  final int number;
  final int seconds;
  final int bestSeconds;
  final int keys;
  final int deaths;
  final int streak;
  final int freezes;
  final String shareText;
}

/// "0:48".
String formatRunTime(int seconds) {
  final s = max(0, seconds);
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// The spoiler-free share text: how fast, how many keys, how many deaths.
/// It says nothing about the maze itself.
String dailyShareText({
  required int number,
  required int seconds,
  required int keys,
  required int deaths,
  required int streak,
  String url = '',
}) {
  final lines = <String>[
    'FearFlip Daily #$number — escaped ${formatRunTime(seconds)} '
        '${'🗝' * max(0, keys)} 💀$deaths',
    if (streak > 1) '🔥 $streak-day streak',
    if (url.trim().isNotEmpty) url.trim(),
  ];
  return lines.join('\n');
}
