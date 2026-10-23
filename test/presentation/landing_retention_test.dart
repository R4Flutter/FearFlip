import 'package:fearflipgame/presentation/screens/landing_screen.dart';
import 'package:fearflipgame/presentation/widgets/save_progress_dialog.dart';
import 'package:fearflipgame/services/ads_service_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ads that do nothing (the landing only asks for a banner).
class _NoAds implements AdsServiceBase {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      invocation.isGetter ? false : Future<void>.value();
}

Future<void> _landing(
  WidgetTester tester, {
  VoidCallback? onDaily,
  VoidCallback? onSaveProgress,
  int streak = 0,
  bool escaped = false,
  int? best,
}) async {
  // Wide enough that the test font (wider than real ones) fits the top bar.
  tester.view.physicalSize = const Size(1600, 2600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LandingScreen(
          isStarting: false,
          onPlay: () {},
          onChooseCharacter: () {},
          onSettings: () {},
          onLeaderboard: () {},
          onRemoveAds: () {},
          onPrivacyPolicy: () {},
          playerName: 'GUEST-AB12',
          totalTrophies: 3,
          globalPanicRank: null,
          adsService: _NoAds(),
          onDaily: onDaily,
          dailyNumber: 23,
          dailyStreak: streak,
          dailyFreezes: 1,
          dailyEscapedToday: escaped,
          dailyBestSeconds: best,
          onSaveProgress: onSaveProgress,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('the menu offers today\'s Daily Nightmare with the streak', (
    tester,
  ) async {
    var opened = 0;
    await _landing(tester, onDaily: () => opened++, streak: 5);
    expect(find.text('DAILY NIGHTMARE #23'), findsOneWidget);
    expect(
      find.text('Same maze for everyone today · 🔥 5-day streak · ❄ 1'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(LandingScreen.dailyKey));
    expect(opened, 1);
  });

  testWidgets('after today\'s escape the button shows the time', (
    tester,
  ) async {
    await _landing(tester, onDaily: () {}, streak: 2, escaped: true, best: 48);
    expect(
      find.text('Escaped today in 0:48 · 🔥 2-day streak · ❄ 1'),
      findsOneWidget,
    );
  });

  testWidgets('guests get a save-progress button, others do not', (
    tester,
  ) async {
    var taps = 0;
    await _landing(tester, onSaveProgress: () => taps++);
    expect(find.text('SAVE YOUR PROGRESS'), findsOneWidget);
    await tester.tap(find.byKey(LandingScreen.saveProgressKey));
    expect(taps, 1);

    await _landing(tester);
    expect(find.text('SAVE YOUR PROGRESS'), findsNothing);
    expect(find.byKey(LandingScreen.dailyKey), findsNothing);
  });

  testWidgets('the save-progress offer signs in, shows errors, or waits', (
    tester,
  ) async {
    String? nextResult = 'No network.';
    var signIns = 0;
    var closes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SaveProgressDialog(
            onSignIn: () async {
              signIns++;
              return nextResult;
            },
            onClose: () => closes++,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(SaveProgressDialog.signInKey));
    await tester.pump();
    expect(signIns, 1);
    expect(find.text('No network.'), findsOneWidget);
    expect(closes, 0);

    nextResult = null;
    await tester.tap(find.byKey(SaveProgressDialog.signInKey));
    await tester.pump();
    expect(closes, 1);

    await tester.tap(find.byKey(SaveProgressDialog.laterKey));
    expect(closes, 2);
  });
}
