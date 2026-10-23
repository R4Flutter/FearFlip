import 'package:fearflipgame/data/database/local_session_database.dart';
import 'package:fearflipgame/domain/usecases/start_survival_use_case.dart';
import 'package:fearflipgame/game/daily/daily_nightmare.dart';
import 'package:fearflipgame/presentation/providers/app_flow_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppFlowProvider _provider({DateTime Function()? clock}) {
  final db = LocalSessionDatabase();
  return AppFlowProvider(
    sessionDatabase: db,
    startSurvivalUseCase: StartSurvivalUseCase(sessionDatabase: db),
    enableAuthBootstrap: false,
    clock: clock,
  );
}

/// Lets the provider's async loads (prefs, daily state) finish.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 30));
}

void main() {
  group('guest-first start', () {
    testWidgets(
      'a new player gets a guest session as soon as consent is accepted',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final flow = _provider();
        await _settle(tester);
        expect(flow.showOnboarding, isTrue);

        await flow.acceptOnboarding();
        expect(flow.showAuthGate, isFalse);
        expect(flow.isGuest, isTrue);
        expect(flow.playerName, startsWith('GUEST-'));

        await flow.startSurvival();
        expect(flow.showLanding, isFalse, reason: 'straight into the maze');
        flow.dispose();
      },
    );

    testWidgets('a returning player never sees the sign-in screen', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'onboarding.consent.v1.accepted': true,
      });
      final flow = _provider();
      await _settle(tester);
      expect(flow.showOnboarding, isFalse);
      expect(flow.showAuthGate, isFalse);
      expect(flow.isGuest, isTrue);
      flow.dispose();
    });

    testWidgets('Google sign-in is only offered where this build supports it', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final flow = _provider();
      await _settle(tester);
      // No auth service in this build: nothing to offer.
      expect(flow.canOfferGoogleSignIn, isFalse);
      expect(flow.shouldOfferSaveProgress(1), isFalse);

      await flow.markSaveProgressOffered();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('prompt.save_progress.v1.offered'), isTrue);
      flow.dispose();
    });
  });

  group('Daily Nightmare', () {
    testWidgets(
      'a failure and an escape build the summary and the share text',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final flow = _provider(clock: () => DateTime(2026, 10, 23, 18));
        await _settle(tester);
        expect(flow.todaysDaily.number, 23);
        expect(flow.dailyStreakDays, 0);

        flow.startDaily();
        expect(flow.dailyActive, isTrue);
        expect(flow.showLanding, isFalse);

        await flow.recordDailyFailure();
        final summary = await flow.recordDailyEscape(
          const DailyRunResult(seconds: 48, keys: 2),
        );
        expect(summary.number, 23);
        expect(summary.deaths, 1);
        expect(summary.streak, 1);
        expect(summary.shareText, 'FearFlip Daily #23 — escaped 0:48 🗝🗝 💀1');
        expect(flow.dailyEscapedToday, isTrue);
        expect(flow.dailyBestSecondsToday, 48);

        flow.exitDaily();
        expect(flow.dailyActive, isFalse);
        expect(flow.showLanding, isTrue);
        flow.dispose();
      },
    );

    testWidgets('the streak survives a restart and grows the next day', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final first = _provider(clock: () => DateTime(2026, 10, 23, 9));
      await _settle(tester);
      first.startDaily();
      await first.recordDailyEscape(const DailyRunResult(seconds: 70, keys: 2));
      first.dispose();

      final next = _provider(clock: () => DateTime(2026, 10, 24, 9));
      await _settle(tester);
      expect(next.dailyStreakDays, 1);
      expect(next.dailyEscapedToday, isFalse);
      expect(next.dailyBestSecondsToday, isNull);
      next.startDaily();
      final summary = await next.recordDailyEscape(
        const DailyRunResult(seconds: 55, keys: 2),
      );
      expect(summary.streak, 2);
      expect(summary.deaths, 0);
      expect(summary.shareText, contains('🔥 2-day streak'));
      next.dispose();
    });

    testWidgets('a missed day is covered by the free freeze', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var now = DateTime(2026, 10, 20, 9);
      final flow = _provider(clock: () => now);
      await _settle(tester);
      flow.startDaily();
      await flow.recordDailyEscape(const DailyRunResult(seconds: 60, keys: 2));
      flow.exitDaily();

      now = DateTime(2026, 10, 22, 9); // the 21st was missed
      expect(flow.dailyStreakDays, 1);
      flow.startDaily();
      final summary = await flow.recordDailyEscape(
        const DailyRunResult(seconds: 60, keys: 2),
      );
      expect(summary.streak, 2);
      expect(summary.freezes, 0);
      flow.dispose();
    });
  });
}
