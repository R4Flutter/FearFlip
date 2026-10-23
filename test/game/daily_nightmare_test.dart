import 'package:fearflipgame/game/daily/daily_nightmare.dart';
import 'package:fearflipgame/presentation/gameplay/maze_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DailyChallenge', () {
    test('is the same all day and changes at midnight', () {
      final morning = DailyChallenge.forDate(DateTime(2026, 10, 23, 0, 5));
      final night = DailyChallenge.forDate(DateTime(2026, 10, 23, 23, 59));
      final tomorrow = DailyChallenge.forDate(DateTime(2026, 10, 24, 0, 1));

      expect(morning, night);
      expect(morning.seed, night.seed);
      expect(tomorrow.number, morning.number + 1);
      expect(tomorrow.seed, isNot(morning.seed));
    });

    test('numbers start at #1 on the first day', () {
      expect(DailyChallenge.forDate(DateTime(2026, 10, 1, 9)).number, 1);
      expect(DailyChallenge.forDate(DateTime(2026, 10, 23, 9)).number, 23);
    });

    test('everyone gets the same maze for the day', () {
      final a = DailyChallenge.forDate(DateTime(2026, 11, 2, 8));
      final b = DailyChallenge.forDate(DateTime(2026, 11, 2, 20));
      final mazeA = MazeGenerator().generate(rows: 17, cols: 17, seed: a.seed);
      final mazeB = MazeGenerator().generate(rows: 17, cols: 17, seed: b.seed);
      expect(mazeA.end, mazeB.end);
      for (var y = 0; y < 17; y++) {
        for (var x = 0; x < 17; x++) {
          final ca = mazeA.cells[y][x];
          final cb = mazeB.cells[y][x];
          expect(
            [ca.top, ca.right, ca.bottom, ca.left],
            [cb.top, cb.right, cb.bottom, cb.left],
          );
        }
      }
    });

    test('gets harder through the week and never shifts walls', () {
      // 2026-10-26 is a Monday.
      final week = [
        for (var d = 0; d < 7; d++)
          DailyChallenge.forDate(DateTime(2026, 10, 26 + d, 12)).profileStage,
      ];
      expect(week, [5, 8, 11, 14, 17, 20, 23]);
      expect(week.any((stage) => stage % 6 == 0), isFalse);
    });

    test('seeds stay positive and within 31 bits', () {
      for (var day = 0; day < 4000; day += 37) {
        final seed = DailyChallenge.forDate(
          DateTime(2026, 10, 1).add(Duration(days: day)),
        ).seed;
        expect(seed, inInclusiveRange(0, 0x7FFFFFFF));
      }
    });
  });

  group('DailyStreak', () {
    test(
      'one escape a day builds the streak; a second escape changes nothing',
      () {
        var streak = const DailyStreak();
        streak = streak.recordEscape(10);
        expect(streak.current, 1);
        expect(streak.recordEscape(10).current, 1);
        streak = streak.recordEscape(11).recordEscape(12);
        expect(streak.current, 3);
        expect(streak.best, 3);
        expect(streak.escapedOn(12), isTrue);
      },
    );

    test('a freeze covers a missed day', () {
      var streak = const DailyStreak().recordEscape(10).recordEscape(11);
      expect(streak.freezes, 1);
      expect(streak.currentOn(13), 2); // day 12 missed: still alive
      expect(streak.freezesNeededOn(13), 1);
      streak = streak.recordEscape(13);
      expect(streak.current, 3);
      expect(streak.freezes, 0);
    });

    test('missing more days than freezes starts over, keeping the best', () {
      var streak = const DailyStreak()
          .recordEscape(1)
          .recordEscape(2)
          .recordEscape(3);
      expect(streak.currentOn(7), 0);
      streak = streak.recordEscape(7);
      expect(streak.current, 1);
      expect(streak.best, 3);
    });

    test('earns a freeze every 7 days in a row, holding at most 2', () {
      var streak = const DailyStreak();
      for (var day = 0; day < 21; day++) {
        streak = streak.recordEscape(day);
      }
      expect(streak.current, 21);
      expect(streak.freezes, DailyStreak.maxFreezes);
    });
  });

  group('DailyDayRecord', () {
    test('keeps the fastest escape and the deaths before the first one', () {
      var day = const DailyDayRecord(day: 5).withDeath().withDeath();
      day = day.withEscape(61);
      expect(day.escaped, isTrue);
      expect(day.deathsBeforeEscape, 2);
      day = day.withDeath().withEscape(48);
      expect(day.bestSeconds, 48);
      expect(day.deathsBeforeEscape, 2);
      expect(day.deaths, 3);
    });
  });

  group('share text', () {
    test('tells time, keys, deaths and streak without spoiling the maze', () {
      expect(
        dailyShareText(number: 12, seconds: 48, keys: 2, deaths: 1, streak: 5),
        'FearFlip Daily #12 — escaped 0:48 🗝🗝 💀1\n🔥 5-day streak',
      );
      expect(
        dailyShareText(
          number: 3,
          seconds: 125,
          keys: 2,
          deaths: 0,
          streak: 1,
          url: 'https://example.com/fearflip',
        ),
        'FearFlip Daily #3 — escaped 2:05 🗝🗝 💀0\nhttps://example.com/fearflip',
      );
    });

    test('formats run times', () {
      expect(formatRunTime(0), '0:00');
      expect(formatRunTime(59), '0:59');
      expect(formatRunTime(60), '1:00');
      expect(formatRunTime(-4), '0:00');
    });
  });
}
