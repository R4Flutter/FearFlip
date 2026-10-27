import 'dart:async';

import 'package:flutter/material.dart';

import '../arcade_controller.dart';
import '../model/missions.dart';
import '../model/rewards.dart';
import '../progress_controller.dart';
import '../ui/kit.dart';
import 'dialogs.dart';

/// Tonight's rewards: the login calendar, three missions and the chests.
class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arcade = ArcadeScope.of(context);
    final progress = arcade.progress;
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) {
        final login = _LoginPanel(progress: progress);
        final missions = _MissionsPanel(progress: progress);
        final chests = _ChestPanel(progress: progress);
        return MenuPage(
          title: 'Daily Rewards',
          souls: progress.souls,
          onBack: () => Navigator.of(context).pop(),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 330,
                child: Column(
                  children: [
                    login,
                    const SizedBox(height: 14),
                    Expanded(child: chests),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: missions),
            ],
          ),
          tallBody: SingleChildScrollView(
            child: Column(
              children: [
                login,
                const SizedBox(height: 12),
                SizedBox(height: 470, child: missions),
                const SizedBox(height: 12),
                SizedBox(height: 330, child: chests),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _hms(Duration d) =>
    '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.text, {this.glyph});

  final String text;
  final FFGlyph? glyph;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (glyph != null) ...[
          FFIcon(glyph!, size: 34),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            text,
            style: FF.title(34, glow: FF.amber.withValues(alpha: 0.3)),
          ),
        ),
      ],
    );
  }
}

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({required this.progress});

  final ProgressController progress;

  @override
  Widget build(BuildContext context) {
    final ready = progress.loginClaimable;
    return StonePanel(
      glow: ready ? FF.amber : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelTitle('Login Streak', glyph: FFGlyph.calendar),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var d = 1; d <= 7; d++) ...[
                if (d > 1) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: d <= progress.loginClaimedDays
                          ? FF.amber
                          : (ready && d == progress.loginNextDay
                                ? FF.blood3
                                : FF.slate),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: FF.ink, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$d',
                      style: FF.text(14, weight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SlabButton(
            label: ready
                ? 'CLAIM DAY ${progress.loginNextDay}'
                : 'NEXT IN ${_hms(progress.untilTomorrow)}',
            tone: ready ? ButtonTone.amber : ButtonTone.stone,
            pulse: ready,
            height: 52,
            onPressed: () => showLoginCalendar(context),
          ),
        ],
      ),
    );
  }
}

class _MissionsPanel extends StatelessWidget {
  const _MissionsPanel({required this.progress});

  final ProgressController progress;

  @override
  Widget build(BuildContext context) {
    final missions = progress.missions;
    return StonePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelTitle("Tonight's Missions", glyph: FFGlyph.scroll),
          Text(
            'New missions in ${_hms(progress.untilTomorrow)}',
            style: FF.text(15, color: FF.stoneLight),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < missions.length; i++) ...[
            _MissionRow(index: i, mission: missions[i]),
            const SizedBox(height: 10),
          ],
          const Spacer(),
          Slot(
            highlight: progress.missionsBonusReady ? FF.gold : null,
            child: Row(
              children: [
                const FFIcon(FFGlyph.chest, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ALL THREE DONE',
                        style: FF.text(18, weight: FontWeight.w700),
                      ),
                      Text(
                        progress.missionsBonusClaimed
                            ? 'Bonus claimed. See you tomorrow!'
                            : '+${DailyMissions.bonusSouls} souls and a rich chest',
                        style: FF.text(15, color: FF.bone2),
                      ),
                    ],
                  ),
                ),
                SlabButton(
                  label: progress.missionsBonusClaimed ? 'DONE' : 'OPEN',
                  tone: progress.missionsBonusReady
                      ? ButtonTone.gold
                      : ButtonTone.stone,
                  height: 48,
                  width: 120,
                  pulse: progress.missionsBonusReady,
                  sound: null,
                  onPressed: progress.missionsBonusReady
                      ? () async {
                          final reward = progress.claimMissionsBonus();
                          await showChestOpening(context, reward);
                          if (context.mounted) {
                            ArcadeScope.of(context).announceAchievements();
                          }
                        }
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionRow extends StatelessWidget {
  const _MissionRow({required this.index, required this.mission});

  final int index;
  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final arcade = ArcadeScope.of(context);
    final progress = arcade.progress;
    return Slot(
      highlight: mission.claimable ? FF.amber : null,
      child: Row(
        children: [
          FFIcon(
            mission.claimed ? FFGlyph.check : _glyphFor(mission.kind),
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.title,
                  style: FF.text(
                    18,
                    weight: FontWeight.w700,
                    color: mission.claimed ? FF.stone3 : FF.bone,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: BoneBar(
                        value: mission.fraction,
                        height: 18,
                        label: '${mission.progress}/${mission.target}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    const FFIcon(FFGlyph.soul, size: 22),
                    Text(
                      '${mission.reward}',
                      style: FF.text(16, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (mission.claimable) ...[
            SlabButton(
              label: 'CLAIM',
              tone: ButtonTone.amber,
              height: 46,
              width: 104,
              fontSize: 17,
              sound: null,
              onPressed: () => _claim(context, progress, doubled: false),
            ),
            const SizedBox(width: 8),
            SlabButton(
              label: '×2',
              icon: FF.art('icon_film', size: 24),
              tone: ButtonTone.gold,
              height: 46,
              width: 96,
              fontSize: 18,
              sound: null,
              onPressed: () => _claim(context, progress, doubled: true),
            ),
          ] else
            SizedBox(
              width: 208,
              child: Text(
                mission.claimed ? 'CLAIMED' : 'IN PROGRESS',
                textAlign: TextAlign.center,
                style: FF.text(
                  15,
                  color: mission.claimed ? FF.amber : FF.stoneLight,
                  weight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _claim(
    BuildContext context,
    ProgressController progress, {
    required bool doubled,
  }) async {
    final arcade = ArcadeScope.of(context);
    if (doubled && !await arcade.watchRewarded()) return;
    final reward = progress.claimMission(index, doubled: doubled);
    if (reward.isEmpty) return;
    Sfx.instance.play(Sound.coins);
    arcade.showToast(
      ToastMessage(
        '+${reward.souls} souls',
        subtitle: mission.title,
        kind: ToastKind.reward,
      ),
    );
    arcade.announceAchievements();
  }

  static FFGlyph _glyphFor(MissionKind kind) => switch (kind) {
    MissionKind.escapeMazes => FFGlyph.door,
    MissionKind.collectWisps => FFGlyph.soul,
    MissionKind.findKeys => FFGlyph.key,
    MissionKind.surviveFlips => FFGlyph.frost,
    MissionKind.earnStars => FFGlyph.star,
    MissionKind.perfectStage => FFGlyph.crown,
    MissionKind.endlessDepth => FFGlyph.infinity,
    MissionKind.safeCandles => FFGlyph.shield,
    MissionKind.dailyEscape => FFGlyph.moon,
    MissionKind.usePowerUps => FFGlyph.eye,
    MissionKind.openChest => FFGlyph.chest,
  };
}

class _ChestPanel extends StatelessWidget {
  const _ChestPanel({required this.progress});

  final ProgressController progress;

  @override
  Widget build(BuildContext context) {
    final arcade = ArcadeScope.of(context);
    final free = progress.freeChestReady;
    final adLeft = progress.adChestsLeft;
    return StonePanel(
      glow: free ? FF.gold : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelTitle('Chests', glyph: FFGlyph.chest),
          const SizedBox(height: 6),
          Expanded(
            child: Center(
              child: TweenAnimationBuilder<double>(
                key: ValueKey(free),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1600),
                builder: (context, v, child) => Transform.rotate(
                  angle: free
                      ? 0.06 * (v < 0.5 ? v : 1 - v) * (v * 40 % 2 > 1 ? 1 : -1)
                      : 0,
                  child: child,
                ),
                child: FFIcon(
                  FFGlyph.chest,
                  size: 96,
                  color: free || adLeft > 0 ? null : FF.stone2,
                ),
              ),
            ),
          ),
          SlabButton(
            label: free
                ? 'OPEN FREE CHEST'
                : 'FREE CHEST IN ${_hms(progress.untilTomorrow)}',
            tone: free ? ButtonTone.gold : ButtonTone.stone,
            pulse: free,
            height: 52,
            sound: null,
            onPressed: free
                ? () async {
                    final reward = progress.openFreeChest();
                    await showChestOpening(context, reward);
                    if (context.mounted) arcade.announceAchievements();
                  }
                : null,
          ),
          const SizedBox(height: 10),
          SlabButton(
            label: adLeft > 0 ? 'BONUS CHEST' : 'NO BONUS CHESTS LEFT',
            sublabel: adLeft > 0
                ? 'WATCH A VIDEO · $adLeft LEFT TODAY'
                : 'BACK TOMORROW',
            icon: adLeft > 0 ? FF.art('icon_film', size: 28) : null,
            tone: adLeft > 0 ? ButtonTone.bone : ButtonTone.stone,
            height: 56,
            sound: null,
            onPressed: adLeft > 0
                ? () async {
                    if (!await arcade.watchRewarded()) return;
                    final Reward reward = progress.openAdChest();
                    if (!context.mounted || reward.isEmpty) return;
                    await showChestOpening(context, reward);
                    if (context.mounted) arcade.announceAchievements();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
