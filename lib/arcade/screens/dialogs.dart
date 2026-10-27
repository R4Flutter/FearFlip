import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../arcade_controller.dart';
import '../model/boosts.dart';
import '../model/rewards.dart';
import '../model/shop_catalog.dart';
import '../model/worlds.dart';
import '../progress_controller.dart';
import '../ui/kit.dart';
import '../ui/runner_preview.dart';

/// A dialog frame: a stone panel with a title plate.
class DialogFrame extends StatelessWidget {
  const DialogFrame({
    required this.title,
    required this.child,
    this.width = 560,
    this.nightmare = false,
    this.onClose,
    this.glow = FF.amber,
    super.key,
  });

  final String title;
  final Widget child;
  final double width;
  final bool nightmare;
  final VoidCallback? onClose;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final up = designUpscaleOf(context);
    final maxW = min(width, size.width / up - 24);
    // Short (landscape phone) screens: shrink the whole dialog to fit; big
    // screens: grow it with the menus.
    return Transform.scale(
      scale: up,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW,
          maxHeight: size.height / up - 24,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: maxW,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 26),
                  child: StonePanel(
                    blood: nightmare,
                    glow: glow,
                    padding: const EdgeInsets.fromLTRB(18, 34, 18, 18),
                    child: child,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: BoneBox(
                      padding: const EdgeInsets.fromLTRB(22, 4, 22, 2),
                      child: Text(
                        title,
                        style: FF
                            .title(36, color: FF.slate)
                            .copyWith(
                              shadows: const [
                                Shadow(color: FF.bone2, offset: Offset(2, 2)),
                              ],
                            ),
                      ),
                    ),
                  ),
                ),
                if (onClose != null)
                  Positioned(
                    top: 18,
                    right: -6,
                    child: RoundButton(
                      icon: const FFIcon(FFGlyph.close, size: 20),
                      size: 40,
                      tone: ButtonTone.blood,
                      tooltip: 'Close',
                      onPressed: onClose,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Souls, power-ups and items as chips.
class RewardContents extends StatelessWidget {
  const RewardContents({required this.reward, this.size = 1, super.key});

  final Reward reward;
  final double size;

  @override
  Widget build(BuildContext context) {
    final item = reward.itemId == null
        ? null
        : ShopCatalog.byId(reward.itemId!);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12 * size,
      runSpacing: 10 * size,
      children: [
        if (reward.souls > 0)
          _RewardChip(
            icon: FFIcon(FFGlyph.soul, size: 40 * size),
            text: '+${formatNumber(reward.souls)}',
            size: size,
          ),
        for (final e in reward.boosts.entries)
          _RewardChip(
            icon: FFIcon(boostGlyphFor(e.key.name), size: 38 * size),
            text: '${Boosts.info[e.key]!.name} ×${e.value}',
            size: size,
          ),
        if (item != null)
          _RewardChip(
            icon: item.category == ShopCategory.runner
                ? RunnerPreview(
                    look: RunnerLook.of(
                      runnerId: item.id,
                      lanternId: ShopCatalog.defaultLantern,
                      trailId: 'trail_none',
                    ),
                    size: 64 * size,
                    walking: false,
                    turning: false,
                    floor: false,
                  )
                : FFIcon(FFGlyph.crown, size: 38 * size),
            text: 'NEW: ${item.name}',
            size: size,
            color: FF.gold,
          ),
      ],
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({
    required this.icon,
    required this.text,
    required this.size,
    this.color = FF.bone,
  });

  final Widget icon;
  final String text;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Slot(
      highlight: FF.amber,
      padding: EdgeInsets.symmetric(horizontal: 14 * size, vertical: 8 * size),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          SizedBox(width: 8 * size),
          Text(
            text,
            style: FF.text(22 * size, color: color, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Shows what was just won, with a burst of light.
Future<void> showRewardDialog(
  BuildContext context, {
  required Reward reward,
  String title = 'Reward',
  String? message,
}) {
  Sfx.instance.play(Sound.coins);
  return showFFDialog<void>(
    context,
    builder: (context) => DialogFrame(
      title: title,
      width: 520,
      glow: FF.gold,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Burst(size: 120),
          if (message != null) ...[
            Text(
              message,
              textAlign: TextAlign.center,
              style: FF.text(18, color: FF.bone2),
            ),
            const SizedBox(height: 12),
          ],
          RewardContents(reward: reward),
          const SizedBox(height: 20),
          SlabButton(
            label: 'COLLECT',
            width: 260,
            height: 58,
            tone: ButtonTone.gold,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ),
  );
}

/// Rays of light turning behind a soul wisp.
class _Burst extends StatefulWidget {
  const _Burst({required this.size, this.glyph = FFGlyph.soul});

  final double size;
  final FFGlyph glyph;

  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 1.6,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _c,
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: _RaysPainter(),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.3, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, v, child) =>
                Transform.scale(scale: v, child: child),
            child: FFIcon(widget.glyph, size: widget.size * 0.55),
          ),
        ],
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [FF.gold.withValues(alpha: 0.55), FF.gold.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    for (var i = 0; i < 12; i++) {
      final a = i * pi / 6;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + cos(a - 0.12) * r, c.dy + sin(a - 0.12) * r)
        ..lineTo(c.dx + cos(a + 0.12) * r, c.dy + sin(a + 0.12) * r)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A chest that shakes, bursts open and shows what it held.
Future<void> showChestOpening(BuildContext context, Reward reward) {
  return showFFDialog<void>(
    context,
    dismissible: false,
    builder: (context) => _ChestOpening(reward: reward),
  );
}

class _ChestOpening extends StatefulWidget {
  const _ChestOpening({required this.reward});

  final Reward reward;

  @override
  State<_ChestOpening> createState() => _ChestOpeningState();
}

class _ChestOpeningState extends State<_ChestOpening>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() {
      if (!mounted) return;
      Sfx.instance.play(Sound.chest);
      setState(() => _open = true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DialogFrame(
      title: 'Chest',
      width: 520,
      glow: FF.gold,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 150,
            child: _open
                ? const _Burst(size: 150, glyph: FFGlyph.chest)
                : AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) {
                      final shake = sin(_c.value * 60) * 6 * _c.value;
                      return Transform.translate(
                        offset: Offset(shake, 0),
                        child: Transform.scale(
                          scale: 1 + _c.value * 0.25,
                          child: const FFIcon(FFGlyph.chest, size: 96),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          AnimatedOpacity(
            opacity: _open ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: Column(
              children: [
                RewardContents(reward: widget.reward),
                const SizedBox(height: 18),
                SlabButton(
                  label: 'COLLECT',
                  width: 260,
                  height: 58,
                  tone: ButtonTone.gold,
                  onPressed: _open ? () => Navigator.of(context).pop() : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Daily login calendar
// -----------------------------------------------------------------------------

Future<void> showLoginCalendar(BuildContext context) {
  return showFFDialog<void>(
    context,
    builder: (context) => const _LoginCalendar(),
  );
}

class _LoginCalendar extends StatelessWidget {
  const _LoginCalendar();

  @override
  Widget build(BuildContext context) {
    final arcade = ArcadeScope.of(context);
    final progress = arcade.progress;
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) {
        final claimable = progress.loginClaimable;
        final next = progress.loginNextDay;
        final claimed = progress.loginClaimedDays;
        return DialogFrame(
          title: 'Daily Reward',
          width: 900,
          onClose: () => Navigator.of(context).pop(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                claimable
                    ? (progress.loginStreakBroken
                          ? 'You missed a night. The calendar starts again.'
                          : 'Come back every night. Day 7 brings a new runner!')
                    : 'Claimed! Next reward in ${_hms(progress.untilTomorrow)}.',
                textAlign: TextAlign.center,
                style: FF.text(18, color: FF.bone2),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (var day = 1; day <= 7; day++) ...[
                    if (day > 1) const SizedBox(width: 8),
                    Expanded(
                      flex: day == 7 ? 2 : 1,
                      child: _DayTile(
                        day: day,
                        reward: LoginCalendar.days[day - 1],
                        claimed: day <= claimed,
                        today: claimable && day == next,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              if (claimable)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SlabButton(
                      label: 'CLAIM',
                      width: 220,
                      height: 58,
                      tone: ButtonTone.amber,
                      pulse: true,
                      onPressed: () => _claim(context, doubled: false),
                    ),
                    const SizedBox(width: 14),
                    SlabButton(
                      label: 'CLAIM ×2',
                      sublabel: 'WATCH A VIDEO',
                      icon: FF.art('icon_film', size: 30),
                      width: 250,
                      height: 58,
                      tone: ButtonTone.gold,
                      onPressed: () => _claim(context, doubled: true),
                    ),
                  ],
                )
              else
                SlabButton(
                  label: 'SEE YOU TOMORROW',
                  width: 300,
                  height: 54,
                  tone: ButtonTone.stone,
                  onPressed: () => Navigator.of(context).pop(),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _claim(BuildContext context, {required bool doubled}) async {
    final arcade = ArcadeScope.of(context);
    if (doubled && !await arcade.watchRewarded()) return;
    final reward = arcade.progress.claimLogin(doubled: doubled);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    await showRewardDialog(
      context,
      reward: reward,
      title: 'Day ${arcade.progress.loginClaimedDays}',
    );
    arcade.announceAchievements();
  }
}

String _hms(Duration d) =>
    '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.day,
    required this.reward,
    required this.claimed,
    required this.today,
  });

  final int day;
  final Reward reward;
  final bool claimed;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final big = day == 7;
    final FFGlyph glyph;
    if (reward.itemId != null) {
      glyph = FFGlyph.crown;
    } else if (reward.chests > 0) {
      glyph = FFGlyph.chest;
    } else if (reward.boosts.isNotEmpty) {
      glyph = boostGlyphFor(reward.boosts.keys.first.name);
    } else {
      glyph = FFGlyph.soul;
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 150,
      decoration: BoxDecoration(
        color: claimed
            ? FF.ink.withValues(alpha: 0.9)
            : (today ? FF.bloodDeep : FF.slate),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: today ? FF.gold : (claimed ? FF.slate2 : FF.stone2),
          width: today ? 3 : 2,
        ),
        boxShadow: today
            ? [
                BoxShadow(
                  color: FF.amber.withValues(alpha: 0.45),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(6),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: claimed ? 0.45 : 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    'DAY $day',
                    style: FF.text(
                      15,
                      color: today ? FF.gold : FF.boneDim,
                      weight: FontWeight.w700,
                    ),
                  ),
                  FFIcon(glyph, size: big ? 56 : 42),
                  Text(
                    big ? '${reward.souls} + RUNNER' : '${reward.souls}',
                    textAlign: TextAlign.center,
                    style: FF.text(big ? 15 : 17, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          if (claimed) const Center(child: FFIcon(FFGlyph.check, size: 48)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Stage intro (boosts) and mode intros
// -----------------------------------------------------------------------------

/// The card before a campaign stage. Returns the boosts taken, or null when
/// the player backs out.
Future<Set<BoostType>?> showStageIntro(BuildContext context, int stage) {
  return showFFDialog<Set<BoostType>>(
    context,
    builder: (context) => _StageIntro(stage: stage),
  );
}

class _StageIntro extends StatefulWidget {
  const _StageIntro({required this.stage});

  final int stage;

  @override
  State<_StageIntro> createState() => _StageIntroState();
}

class _StageIntroState extends State<_StageIntro> {
  final Set<BoostType> _picked = <BoostType>{};

  @override
  Widget build(BuildContext context) {
    final arcade = ArcadeScope.of(context);
    final progress = arcade.progress;
    final world = Worlds.forStage(widget.stage);
    final stars = progress.starsFor(widget.stage);
    final best = progress.bestSecondsFor(widget.stage);
    final gate = Worlds.isGate(widget.stage);
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) => DialogFrame(
        title: gate ? 'Gate ${widget.stage}' : 'Stage ${widget.stage}',
        width: 640,
        glow: Color(world.accent),
        onClose: () => Navigator.of(context).pop(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'WORLD ${world.number} · ${world.name.toUpperCase()}',
              style: FF.text(
                18,
                color: Color(world.accent),
                weight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              world.twistText,
              textAlign: TextAlign.center,
              style: FF.text(17, color: FF.bone2),
            ),
            if (gate) ...[
              const SizedBox(height: 6),
              Text(
                'A gate stage: harder, and its first clear pays a chest.',
                textAlign: TextAlign.center,
                style: FF.text(15, color: FF.gold),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StarRow(earned: stars, size: 34, gap: 6),
                if (best != null) ...[
                  const SizedBox(width: 18),
                  StatChip(
                    icon: const FFIcon(FFGlyph.hourglass, size: 22),
                    text:
                        'BEST ${best ~/ 60}:${(best % 60).toString().padLeft(2, '0')}',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '★ Escape   ★★ 20% time left   ★★★ 45% time left, no revive',
              style: FF.text(14, color: FF.stoneLight),
            ),
            const SizedBox(height: 16),
            Text(
              'TAKE UP TO ${Boosts.maxPerStage} POWER-UPS',
              style: FF.text(
                16,
                color: FF.boneDim,
                weight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final type in BoostType.values) ...[
                  if (type != BoostType.values.first) const SizedBox(width: 10),
                  Expanded(
                    child: _BoostTile(
                      type: type,
                      count: progress.boostCount(type),
                      picked: _picked.contains(type),
                      onTap: () => _toggle(progress, type),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            SlabButton(
              label: 'ENTER THE MAZE',
              icon: const FFIcon(FFGlyph.play, size: 30),
              width: 340,
              height: 66,
              pulse: true,
              onPressed: () =>
                  Navigator.of(context).pop(Set<BoostType>.of(_picked)),
            ),
          ],
        ),
      ),
    );
  }

  void _toggle(ProgressController progress, BoostType type) {
    setState(() {
      if (_picked.remove(type)) return;
      if (_picked.length >= Boosts.maxPerStage) {
        Sfx.instance.play(Sound.denied, volume: 0.6);
        return;
      }
      if (progress.boostCount(type) <= 0) {
        if (progress.buyBoost(type)) {
          Sfx.instance.play(Sound.purchase, volume: 0.6);
        } else {
          Sfx.instance.play(Sound.denied, volume: 0.6);
          return;
        }
      }
      _picked.add(type);
    });
  }
}

class _BoostTile extends StatelessWidget {
  const _BoostTile({
    required this.type,
    required this.count,
    required this.picked,
    required this.onTap,
  });

  final BoostType type;
  final int count;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final info = Boosts.info[type]!;
    return Tooltip(
      message: info.text,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 132,
            decoration: BoxDecoration(
              color: picked
                  ? const Color(0xFF2A3A2A)
                  : FF.ink.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: picked ? FF.gold : FF.slate2,
                width: picked ? 3 : 2,
              ),
              boxShadow: picked
                  ? [
                      BoxShadow(
                        color: FF.gold.withValues(alpha: 0.4),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FFIcon(boostGlyphFor(type.name), size: 44),
                Text(
                  info.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: FF.text(14, weight: FontWeight.w700),
                ),
                if (picked)
                  Text(
                    'READY',
                    style: FF.text(14, color: FF.gold, weight: FontWeight.w700),
                  )
                else if (count > 0)
                  Text('OWNED ×$count', style: FF.text(13, color: FF.spirit))
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FFIcon(FFGlyph.soul, size: 18),
                      const SizedBox(width: 3),
                      Text(
                        '${info.price}',
                        style: FF.text(14, color: FF.bone2),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool?> showEndlessIntro(BuildContext context) {
  final progress = ArcadeScope.of(context).progress;
  return showFFDialog<bool>(
    context,
    builder: (context) => DialogFrame(
      title: 'Endless Night',
      width: 560,
      glow: FF.spirit,
      onClose: () => Navigator.of(context).pop(false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FFIcon(FFGlyph.infinity, size: 80),
          const SizedBox(height: 8),
          Text(
            'One maze after another, each a little meaner. One life (and one revive). How deep can you go?',
            textAlign: TextAlign.center,
            style: FF.text(18, color: FF.bone2),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StatChip(
                icon: const FFIcon(FFGlyph.flame, size: 22),
                text: 'BEST DEPTH ${progress.endlessBestDepth}',
              ),
              const SizedBox(width: 10),
              StatChip(
                icon: const FFIcon(FFGlyph.crown, size: 22),
                text: 'BEST ${formatNumber(progress.endlessBestScore)}',
              ),
            ],
          ),
          const SizedBox(height: 18),
          SlabButton(
            label: 'DESCEND',
            icon: const FFIcon(FFGlyph.play, size: 30),
            width: 300,
            height: 64,
            tone: ButtonTone.spirit,
            pulse: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ),
  );
}

Future<bool?> showDailyIntro(BuildContext context) {
  final arcade = ArcadeScope.of(context);
  final daily = arcade.todaysDaily;
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final day = weekdays[daily.date.weekday - 1];
  final best = arcade.dailyBestToday;
  return showFFDialog<bool>(
    context,
    builder: (context) => DialogFrame(
      title: 'Nightmare #${daily.number}',
      width: 600,
      nightmare: true,
      glow: FF.blood,
      onClose: () => Navigator.of(context).pop(false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FFIcon(FFGlyph.moon, size: 80),
          const SizedBox(height: 8),
          Text(
            "Today's maze is the same for every player. Free retries. "
            'Mondays are gentle; by Sunday it bites. ($day)',
            textAlign: TextAlign.center,
            style: FF.text(18, color: FF.bone2),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              StatChip(
                icon: const FFIcon(FFGlyph.flame, size: 22),
                text: arcade.dailyStreakDays > 0
                    ? '${arcade.dailyStreakDays}-DAY STREAK'
                    : 'START A STREAK',
                color: FF.gold,
              ),
              if (best != null)
                StatChip(
                  icon: const FFIcon(FFGlyph.hourglass, size: 22),
                  text:
                      'TODAY ${best ~/ 60}:${(best % 60).toString().padLeft(2, '0')}',
                ),
              StatChip(
                icon: const FFIcon(FFGlyph.soul, size: 22),
                text: arcade.progress.dailyNightmareRewardReady
                    ? 'FIRST ESCAPE: +120 & CHEST'
                    : 'REWARD CLAIMED',
              ),
            ],
          ),
          const SizedBox(height: 18),
          SlabButton(
            label: arcade.dailyEscapedToday ? 'BEAT YOUR TIME' : 'FACE IT',
            icon: const FFIcon(FFGlyph.play, size: 30),
            width: 320,
            height: 64,
            tone: ButtonTone.blood,
            pulse: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ),
  );
}

// -----------------------------------------------------------------------------
// Settings
// -----------------------------------------------------------------------------

Future<void> showSettingsDialog(BuildContext context) {
  return showFFDialog<void>(context, builder: (context) => const _Settings());
}

class _Settings extends StatelessWidget {
  const _Settings();

  @override
  Widget build(BuildContext context) {
    final arcade = ArcadeScope.of(context);
    final progress = arcade.progress;
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) => DialogFrame(
        title: 'Settings',
        width: 560,
        onClose: () => Navigator.of(context).pop(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Toggle(
              glyph: FFGlyph.music,
              label: 'Music',
              value: progress.musicOn,
              onChanged: (v) {
                progress.musicOn = v;
                Sfx.instance.setSwitches(musicOn: v, sfxOn: progress.sfxOn);
              },
            ),
            const SizedBox(height: 10),
            _Toggle(
              glyph: progress.sfxOn ? FFGlyph.sound : FFGlyph.soundOff,
              label: 'Sound effects',
              value: progress.sfxOn,
              onChanged: (v) {
                progress.sfxOn = v;
                Sfx.instance.setSwitches(musicOn: progress.musicOn, sfxOn: v);
              },
            ),
            const SizedBox(height: 10),
            _Toggle(
              glyph: FFGlyph.play,
              label: 'Touch: arrow pad (off = joystick)',
              value: progress.arrowPad,
              onChanged: (v) => progress.arrowPad = v,
            ),
            const SizedBox(height: 14),
            Slot(
              child: Text(
                'Keyboard: ARROWS or WASD to move · P or ESC to pause.\n'
                'Touch: the pad in the corner.',
                style: FF.text(15, color: FF.bone2),
              ),
            ),
            const SizedBox(height: 14),
            SlabButton(
              label: 'RESET PROGRESS',
              tone: ButtonTone.blood,
              height: 50,
              onPressed: () => _confirmReset(context, progress),
            ),
            const SizedBox(height: 10),
            Text(
              'Fonts: Jacquard 12 and Jersey 15 by Sarah Cadigan-Fried (SIL Open Font License).',
              textAlign: TextAlign.center,
              style: FF.text(12, color: FF.stone3, outline: false),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset(
    BuildContext context,
    ProgressController progress,
  ) async {
    final sure = await showFFDialog<bool>(
      context,
      builder: (context) => DialogFrame(
        title: 'Are you sure?',
        width: 480,
        nightmare: true,
        glow: FF.blood,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'All stars, souls, runners and records will be erased. This cannot be undone.',
              textAlign: TextAlign.center,
              style: FF.text(18, color: FF.bone2),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SlabButton(
                  label: 'KEEP',
                  tone: ButtonTone.stone,
                  width: 150,
                  height: 52,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(width: 12),
                SlabButton(
                  label: 'ERASE',
                  tone: ButtonTone.blood,
                  width: 150,
                  height: 52,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (sure == true) progress.resetProgress();
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.glyph,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final FFGlyph glyph;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Sfx.instance.play(Sound.click, volume: 0.6);
          onChanged(!value);
        },
        child: Slot(
          child: Row(
            children: [
              FFIcon(glyph, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: FF.text(18, weight: FontWeight.w700)),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 64,
                height: 32,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: value ? FF.amberDark : FF.slate2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: FF.ink, width: 2),
                ),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: value ? FF.gold : FF.stone3,
                    shape: BoxShape.circle,
                    border: Border.all(color: FF.ink, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
