import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/audio_manager.dart';
import '../arcade_controller.dart';
import '../model/boosts.dart';
import '../model/run_tally.dart';
import '../model/shop_catalog.dart';
import '../ui/kit.dart';
import 'achievements_screen.dart';
import 'daily_screen.dart';
import 'dialogs.dart';
import 'game_page.dart';
import 'shop_screen.dart';
import 'world_map_screen.dart';

export 'dialogs.dart' show showLoginCalendar, showRewardDialog;

void openMap(BuildContext context, {int? focusStage}) {
  Navigator.of(context).push(fadeRoute<void>(WorldMapScreen(focusStage: focusStage)));
}

void openShop(BuildContext context, {ShopCategory? tab}) {
  Navigator.of(context).push(fadeRoute<void>(ShopScreen(initialTab: tab)));
}

void openDaily(BuildContext context) {
  Navigator.of(context).push(fadeRoute<void>(const DailyScreen()));
}

void openAchievements(BuildContext context) {
  Navigator.of(context).push(fadeRoute<void>(const AchievementsScreen()));
}

void openSettings(BuildContext context) {
  unawaited(showSettingsDialog(context));
}

/// The stage card (boosts, best stars), then the maze. [quickStart] skips
/// the card for a brand-new player.
Future<void> openStage(
  BuildContext context,
  int stage, {
  bool quickStart = false,
}) async {
  final arcade = ArcadeScope.of(context);
  final progress = arcade.progress;
  if (!progress.isUnlocked(stage)) return;
  Set<BoostType> boosts = const <BoostType>{};
  if (!quickStart) {
    final picked = await showStageIntro(context, stage);
    if (picked == null || !context.mounted) return;
    boosts = picked;
  }
  for (final boost in boosts) {
    progress.consumeBoost(boost);
  }
  await launchGame(
    context,
    GameSession(
      mode: PlayMode.campaign,
      stage: stage,
      look: progress.look,
      boosts: boosts,
      tutorial: !progress.tutorialDone && stage <= 2,
    ),
  );
}

Future<void> startEndless(BuildContext context) async {
  final arcade = ArcadeScope.of(context);
  final go = await showEndlessIntro(context);
  if (go != true || !context.mounted) return;
  await launchGame(
    context,
    GameSession(mode: PlayMode.endless, look: arcade.progress.look),
  );
}

Future<void> startDaily(BuildContext context) async {
  final arcade = ArcadeScope.of(context);
  final go = await showDailyIntro(context);
  if (go != true || !context.mounted) return;
  final daily = arcade.todaysDaily;
  await launchGame(
    context,
    GameSession(
      mode: PlayMode.daily,
      stage: daily.profileStage,
      daily: daily,
      look: arcade.progress.look,
    ),
  );
}

/// Plays [session] full screen; the menu music fades out and back.
Future<void> launchGame(BuildContext context, GameSession session) async {
  final arcade = ArcadeScope.of(context);
  unawaited(AudioManager.instance.setMenuThemeActive(false));
  Sfx.instance.play(Sound.swoosh, volume: 0.5);
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => GamePage(session: session),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: child,
      ),
    ),
  );
  arcade.portal.gameplayStop();
  arcade.progress.refreshDay();
  unawaited(AudioManager.instance.setMenuThemeActive(true));
  arcade.announceAchievements();
}
