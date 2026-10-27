import 'dart:async';

import 'package:flutter/material.dart';

import '../arcade_controller.dart';
import '../model/worlds.dart';
import '../progress_controller.dart';
import '../ui/kit.dart';
import '../ui/runner_preview.dart';
import 'flows.dart';

/// The dashboard: play, the three modes, tonight's rewards, the shop and
/// trophies. Every claimable thing wears a red badge.
class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  Timer? _clock;
  bool _offeredLogin = false;

  @override
  void initState() {
    super.initState();
    // The daily countdowns tick once a second.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOfferLogin());
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  /// Returning players are greeted with today's login reward.
  Future<void> _maybeOfferLogin() async {
    if (!mounted || _offeredLogin) return;
    final progress = ArcadeScope.of(context).progress;
    _offeredLogin = true;
    if (progress.loginClaimable && progress.highestCleared > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) await showLoginCalendar(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final arcade = ArcadeScope.of(context);
    final progress = arcade.progress;
    return Material(
      type: MaterialType.transparency,
      child: DungeonBackdrop(
        child: ListenableBuilder(
          listenable: progress,
          builder: (context, _) => DesignCanvas(
            wide: _WideHub(arcade: arcade, progress: progress),
            tall: _TallHub(arcade: arcade, progress: progress),
          ),
        ),
      ),
    );
  }
}

String _countdown(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

// -----------------------------------------------------------------------------
// Pieces shared by both layouts
// -----------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({required this.arcade, required this.progress});

  final ArcadeController arcade;
  final ProgressController progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StreakChip(
          days: progress.loginClaimedDays,
          ready: progress.loginClaimable,
        ),
        const SizedBox(width: 10),
        StatChip(
          icon: const FFIcon(FFGlyph.star, size: 22),
          text: '${progress.totalStars}',
        ),
        const Spacer(),
        SoulCounter(souls: progress.souls, onTap: () => openShop(context)),
        const SizedBox(width: 10),
        RoundButton(
          icon: const FFIcon(FFGlyph.gear, size: 26),
          tooltip: 'Settings',
          onPressed: () => openSettings(context),
        ),
      ],
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.days, required this.ready});

  final int days;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => showLoginCalendar(context),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            StatChip(
              icon: const FFIcon(FFGlyph.flame, size: 22),
              text: days == 0 ? 'Day 1' : '$days-day streak',
              color: FF.gold,
            ),
            if (ready)
              const Positioned(right: -6, top: -6, child: BadgeDot(size: 18)),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.progress,
    this.width = 420,
    this.height = 92,
  });

  final ProgressController progress;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final stage = progress.nextStage;
    final world = Worlds.forStage(stage);
    final fresh = progress.highestCleared == 0;
    return SlabButton(
      label: fresh ? 'PLAY' : 'PLAY  ·  STAGE $stage',
      sublabel: fresh
          ? 'ESCAPE YOUR FIRST NIGHTMARE'
          : world.name.toUpperCase(),
      icon: FFIcon(FFGlyph.play, size: height * 0.42),
      width: width,
      height: height,
      fontSize: height * 0.34,
      pulse: true,
      onPressed: () => openStage(context, stage, quickStart: fresh),
    );
  }
}

/// A big mode card: icon, title, one line of status and a play arrow.
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.glyph,
    required this.title,
    required this.line,
    required this.onTap,
    this.accent = FF.amber,
    this.badge = false,
    this.nightmare = false,
    this.height = 150,
  });

  final FFGlyph glyph;
  final String title;
  final String line;
  final VoidCallback onTap;
  final Color accent;
  final bool badge;
  final bool nightmare;
  final double height;

  @override
  Widget build(BuildContext context) {
    return _Hoverable(
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: StonePanel(
                blood: nightmare,
                glow: accent,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  children: [
                    FFIcon(glyph, size: height * 0.4),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              title,
                              style: FF.title(
                                height * 0.27,
                                glow: accent.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Flexible(
                            child: Text(
                              line,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: FF.text(15, color: FF.bone2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    FFIcon(FFGlyph.play, size: height * 0.2, color: accent),
                  ],
                ),
              ),
            ),
            if (badge) const Positioned(right: -6, top: -6, child: BadgeDot()),
          ],
        ),
      ),
    );
  }
}

/// A row in tonight's rewards: icon, title, status, badge.
class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.glyph,
    required this.title,
    required this.status,
    required this.ready,
    required this.onTap,
    this.badge = 0,
  });

  final FFGlyph glyph;
  final String title;
  final String status;
  final bool ready;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Hoverable(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Slot(
            highlight: ready ? FF.amber : null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                FFIcon(glyph, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: FF.text(19, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        status,
                        style: FF.text(
                          14,
                          color: ready ? FF.gold : FF.stoneLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (badge > 0)
            Positioned(right: -6, top: -6, child: BadgeDot(count: badge)),
        ],
      ),
    );
  }
}

class _Hoverable extends StatefulWidget {
  const _Hoverable({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<_Hoverable> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () {
          Sfx.instance.play(Sound.click, volume: 0.6);
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _down ? 0.97 : (_hover ? 1.025 : 1),
          duration: const Duration(milliseconds: 110),
          child: widget.child,
        ),
      ),
    );
  }
}

List<Widget> _rewardRows(BuildContext context, ProgressController progress) {
  final until = _countdown(progress.untilTomorrow);
  final loginReady = progress.loginClaimable;
  final missionsReady =
      progress.claimableMissions + (progress.missionsBonusReady ? 1 : 0);
  final chestReady = progress.freeChestReady;
  return [
    _RewardRow(
      glyph: FFGlyph.calendar,
      title: 'Daily Reward',
      status: loginReady
          ? 'Day ${progress.loginNextDay} is ready!'
          : 'Next in $until',
      ready: loginReady,
      badge: loginReady ? 1 : 0,
      onTap: () => showLoginCalendar(context),
    ),
    const SizedBox(height: 10),
    _RewardRow(
      glyph: FFGlyph.scroll,
      title: 'Missions',
      status: missionsReady > 0
          ? 'Rewards to claim!'
          : '${progress.missionsDone}/${progress.missions.length} done · new in $until',
      ready: missionsReady > 0,
      badge: missionsReady,
      onTap: () => openDaily(context),
    ),
    const SizedBox(height: 10),
    _RewardRow(
      glyph: FFGlyph.chest,
      title: 'Free Chest',
      status: chestReady
          ? 'Open it now!'
          : progress.adChestsLeft > 0
          ? '${progress.adChestsLeft} bonus chests left'
          : 'Next in $until',
      ready: chestReady,
      badge: chestReady ? 1 : 0,
      onTap: () => openDaily(context),
    ),
  ];
}

List<Widget> _modeCards(
  BuildContext context,
  ArcadeController arcade,
  ProgressController progress, {
  required double height,
  required bool row,
}) {
  final daily = arcade.todaysDaily;
  final streak = arcade.dailyStreakDays;
  final dailyLine = arcade.dailyEscapedToday
      ? 'Escaped! Best ${_mmss(arcade.dailyBestToday ?? 0)} · next in ${_countdown(progress.untilTomorrow)}'
      : '#${daily.number} · one maze for all · ${streak > 0 ? '$streak-day streak' : 'new every day'}';
  final cards = <Widget>[
    _ModeCard(
      glyph: FFGlyph.map,
      title: 'World Map',
      line: '${progress.totalStars}/${progress.maxStars} stars · 5 worlds',
      onTap: () => openMap(context),
      height: height,
    ),
    _ModeCard(
      glyph: FFGlyph.infinity,
      title: 'Endless Night',
      line: progress.endlessBestDepth > 0
          ? 'Best depth ${progress.endlessBestDepth} · score ${formatNumber(progress.endlessBestScore)}'
          : 'How deep can you go?',
      accent: FF.spirit,
      onTap: () => startEndless(context),
      height: height,
    ),
    _ModeCard(
      glyph: FFGlyph.moon,
      title: 'Daily Nightmare',
      line: dailyLine,
      accent: FF.blood,
      nightmare: true,
      badge: !arcade.dailyEscapedToday,
      onTap: () => startDaily(context),
      height: height,
    ),
  ];
  if (!row) {
    return [
      for (var i = 0; i < cards.length; i++) ...[
        if (i > 0) const SizedBox(height: 10),
        cards[i],
      ],
    ];
  }
  return [
    for (var i = 0; i < cards.length; i++) ...[
      if (i > 0) const SizedBox(width: 16),
      Expanded(child: cards[i]),
    ],
  ];
}

String _mmss(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

class _SideButtons extends StatelessWidget {
  const _SideButtons({required this.progress, this.vertical = true});

  final ProgressController progress;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      _IconTile(
        glyph: FFGlyph.bag,
        label: 'Shop',
        onTap: () => openShop(context),
      ),
      _IconTile(
        art: 'icon_trophy',
        label: 'Trophies',
        badge: progress.claimableAchievements,
        onTap: () => openAchievements(context),
      ),
      _IconTile(
        glyph: FFGlyph.gift,
        label: 'Rewards',
        badge: progress.dailyBadge ? 1 : 0,
        onTap: () => openDaily(context),
      ),
    ];
    return vertical
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                buttons[i],
              ],
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: buttons,
          );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.label,
    required this.onTap,
    this.glyph,
    this.art,
    this.badge = 0,
  });

  final FFGlyph? glyph;
  final String? art;
  final String label;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Hoverable(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: FF.ink, width: 3),
                  image: DecorationImage(
                    image: FF.texture(FF.rubbleTex),
                    repeat: ImageRepeat.repeat,
                    scale: 2.4,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xAA000000),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(6),
                child: Container(
                  decoration: BoxDecoration(
                    color: FF.ink.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: art != null
                      ? FF.art(art!, size: 52)
                      : FFIcon(glyph!, size: 50),
                ),
              ),
              if (badge > 0)
                Positioned(right: -6, top: -6, child: BadgeDot(count: badge)),
            ],
          ),
          const SizedBox(height: 6),
          Text(label, style: FF.text(17, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Layouts
// -----------------------------------------------------------------------------

class _WideHub extends StatelessWidget {
  const _WideHub({required this.arcade, required this.progress});

  final ArcadeController arcade;
  final ProgressController progress;

  @override
  Widget build(BuildContext context) {
    final world = Worlds.forStage(progress.nextStage);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 22),
      child: Column(
        children: [
          _TopBar(arcade: arcade, progress: progress),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 330,
                  child: StonePanel(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "TONIGHT'S REWARDS",
                          style: FF.text(
                            17,
                            color: FF.boneDim,
                            weight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ..._rewardRows(context, progress),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: FearFlipLogo(size: 120),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ESCAPE THE NIGHTMARE',
                        style: FF.text(18, color: FF.boneDim, letterSpacing: 6),
                      ),
                      RunnerPreview(look: progress.look, size: 170),
                      _PlayButton(progress: progress),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'WORLD ${world.number} · ${world.name.toUpperCase()}',
                            style: FF.text(
                              16,
                              color: Color(world.accent),
                              weight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const FFIcon(FFGlyph.star, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '${progress.starsInWorld(world)}/${Worlds.stagesPerWorld * 3}',
                            style: FF.text(16, weight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 150, child: _SideButtons(progress: progress)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: _modeCards(
              context,
              arcade,
              progress,
              height: 112,
              row: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _TallHub extends StatelessWidget {
  const _TallHub({required this.arcade, required this.progress});

  final ArcadeController arcade;
  final ProgressController progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        children: [
          _TopBar(arcade: arcade, progress: progress),
          const SizedBox(height: 10),
          const FittedBox(fit: BoxFit.scaleDown, child: FearFlipLogo(size: 84)),
          Text(
            'ESCAPE THE NIGHTMARE',
            style: FF.text(14, color: FF.boneDim, letterSpacing: 5),
          ),
          RunnerPreview(look: progress.look, size: 130),
          _PlayButton(progress: progress, width: 440, height: 86),
          const SizedBox(height: 14),
          ..._modeCards(context, arcade, progress, height: 92, row: false),
          const Spacer(),
          _SideButtons(progress: progress, vertical: false),
        ],
      ),
    );
  }
}
