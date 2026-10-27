import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/daily/daily_nightmare.dart';
import '../model/rewards.dart';
import '../model/run_tally.dart';
import '../model/worlds.dart';
import '../progress_controller.dart';
import 'kit.dart';

/// Dims the maze and centres a panel, shrunk to fit short landscape phones.
class _OverlayFrame extends StatelessWidget {
  const _OverlayFrame({
    required this.child,
    this.width = 620,
    this.tint = const Color(0xD905050A),
  });

  final Widget child;
  final double width;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: tint,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(width: width, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A title on a bone plate, as on every result screen.
class _Plate extends StatelessWidget {
  const _Plate(this.text, {this.color = FF.slate});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return BoneBox(
      padding: const EdgeInsets.fromLTRB(26, 4, 26, 2),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: FF.title(54, color: color).copyWith(
          shadows: const [Shadow(color: FF.bone2, offset: Offset(2, 2))],
        ),
      ),
    );
  }
}

String _mmss(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

// -----------------------------------------------------------------------------
// Victory (campaign)
// -----------------------------------------------------------------------------

class VictoryOverlay extends StatefulWidget {
  const VictoryOverlay({
    required this.result,
    required this.tally,
    required this.onNext,
    required this.onReplay,
    required this.onMap,
    required this.onDouble,
    this.doubled = false,
    super.key,
  });

  final StageClearResult result;
  final RunTally tally;
  final VoidCallback? onNext;
  final VoidCallback onReplay;
  final VoidCallback onMap;

  /// Doubles the souls after a video; null once used.
  final Future<void> Function()? onDouble;
  final bool doubled;

  @override
  State<VictoryOverlay> createState() => _VictoryOverlayState();
}

class _VictoryOverlayState extends State<VictoryOverlay> {
  int _shown = 0;
  final List<Timer> _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.result.stars; i++) {
      _timers.add(
        Timer(Duration(milliseconds: 450 + i * 420), () {
          if (!mounted) return;
          Sfx.instance.play(Sound.values[Sound.star1.index + i], volume: 0.8);
          setState(() => _shown = i + 1);
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final world = Worlds.forStage(r.stage);
    final totalSouls = r.souls + widget.tally.wisps;
    final last = r.stage >= Worlds.maxStage;
    return _OverlayFrame(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 34),
            child: StonePanel(
              glow: FF.gold,
              padding: const EdgeInsets.fromLTRB(22, 44, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    last ? 'THE NIGHTMARE IS OVER' : 'STAGE ${r.stage} · ${world.name.toUpperCase()}',
                    style: FF.text(18, color: Color(world.accent), weight: FontWeight.w700, letterSpacing: 2),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Padding(
                          padding: EdgeInsets.only(left: 8, right: 8, top: i == 1 ? 0 : 22),
                          child: AnimatedScale(
                            scale: i < _shown ? 1 : 0.6,
                            duration: const Duration(milliseconds: 380),
                            curve: Curves.elasticOut,
                            child: FFIcon(i < _shown ? FFGlyph.star : FFGlyph.starEmpty, size: i == 1 ? 96 : 76),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      StatChip(icon: const FFIcon(FFGlyph.hourglass, size: 22), text: _mmss(widget.tally.seconds)),
                      if (r.newBestTime) StatChip(icon: const FFIcon(FFGlyph.crown, size: 22), text: 'NEW BEST', color: FF.gold),
                      StatChip(icon: const FFIcon(FFGlyph.key, size: 22), text: '${widget.tally.keys}'),
                      if (r.newStars > 0) StatChip(icon: const FFIcon(FFGlyph.star, size: 22), text: '+${r.newStars} NEW', color: FF.gold),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Slot(
                    highlight: FF.spirit,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FFIcon(FFGlyph.soul, size: 44),
                        const SizedBox(width: 10),
                        RollingNumber(
                          value: widget.doubled ? totalSouls + r.souls : totalSouls,
                          style: FF.text(36, weight: FontWeight.w700),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.doubled ? 'SOULS (DOUBLED!)' : 'SOULS',
                          style: FF.text(18, color: widget.doubled ? FF.gold : FF.bone2, weight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  if (r.gateChest != null) ...[
                    const SizedBox(height: 10),
                    Text('GATE CHEST:', style: FF.text(16, color: FF.gold, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    _RewardLine(reward: r.gateChest!),
                  ],
                  if (r.worldCleared && !last) ...[
                    const SizedBox(height: 10),
                    Text(
                      'WORLD ${world.number + 1} OPENED: ${Worlds.all[world.index + 1].name.toUpperCase()}',
                      style: FF.text(17, color: FF.gold, weight: FontWeight.w700),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (widget.onDouble != null && !widget.doubled) ...[
                    SlabButton(
                      label: 'DOUBLE SOULS',
                      sublabel: 'WATCH A VIDEO',
                      icon: FF.art('icon_film', size: 30),
                      tone: ButtonTone.bone,
                      width: 300,
                      height: 58,
                      onPressed: widget.onDouble,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SlabButton(
                        label: 'MAP',
                        icon: const FFIcon(FFGlyph.map, size: 26),
                        tone: ButtonTone.stone,
                        width: 150,
                        height: 58,
                        onPressed: widget.onMap,
                      ),
                      const SizedBox(width: 10),
                      SlabButton(
                        label: 'REPLAY',
                        icon: FF.art('icon_retry', size: 28),
                        tone: ButtonTone.stone,
                        width: 160,
                        height: 58,
                        onPressed: widget.onReplay,
                      ),
                      if (widget.onNext != null) ...[
                        const SizedBox(width: 10),
                        SlabButton(
                          label: 'NEXT',
                          icon: const FFIcon(FFGlyph.play, size: 28),
                          width: 180,
                          height: 58,
                          pulse: true,
                          onPressed: widget.onNext,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(child: _Plate(last ? 'Freedom!' : 'Escaped!', color: FF.slate)),
          ),
        ],
      ),
    );
  }
}

class _RewardLine extends StatelessWidget {
  const _RewardLine({required this.reward});

  final Reward reward;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      alignment: WrapAlignment.center,
      children: [
        if (reward.souls > 0)
          StatChip(icon: const FFIcon(FFGlyph.soul, size: 22), text: '+${reward.souls}'),
        for (final e in reward.boosts.entries)
          StatChip(icon: FFIcon(boostGlyphFor(e.key.name), size: 22), text: '×${e.value}'),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Defeat
// -----------------------------------------------------------------------------

class DefeatOverlay extends StatelessWidget {
  const DefeatOverlay({
    required this.title,
    required this.reason,
    required this.nearMiss,
    required this.onRetry,
    required this.onMenu,
    this.onRevive,
    this.retryLabel = 'RETRY',
    this.menuLabel = 'MAP',
    this.reviveText = 'CONTINUE HERE',
    this.busy = false,
    this.wisps = 0,
    super.key,
  });

  final String title;
  final String reason;
  final String nearMiss;
  final Future<void> Function()? onRevive;
  final VoidCallback onRetry;
  final VoidCallback onMenu;
  final String retryLabel;
  final String menuLabel;
  final String reviveText;
  final bool busy;
  final int wisps;

  @override
  Widget build(BuildContext context) {
    return _OverlayFrame(
      tint: const Color(0xD9120306),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 34),
            child: StonePanel(
              blood: true,
              glow: FF.blood,
              padding: const EdgeInsets.fromLTRB(22, 44, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FF.art('icon_skull', size: 72),
                  const SizedBox(height: 6),
                  Text(reason, textAlign: TextAlign.center, style: FF.text(22, weight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  BoneBox(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(nearMiss, textAlign: TextAlign.center, style: FF.boxText(19)),
                  ),
                  if (wisps > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FFIcon(FFGlyph.soul, size: 26),
                        const SizedBox(width: 6),
                        Text('You keep the $wisps souls you found.', style: FF.text(16, color: FF.bone2)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (onRevive != null) ...[
                    SlabButton(
                      label: 'REVIVE',
                      sublabel: '$reviveText · WATCH A VIDEO',
                      icon: FF.art('icon_heart', size: 34),
                      tone: ButtonTone.gold,
                      width: 360,
                      height: 66,
                      pulse: !busy,
                      onPressed: busy ? null : onRevive,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SlabButton(
                        label: menuLabel,
                        icon: FF.art('icon_house', size: 26),
                        tone: ButtonTone.stone,
                        width: 170,
                        height: 58,
                        onPressed: busy ? null : onMenu,
                      ),
                      const SizedBox(width: 12),
                      SlabButton(
                        label: retryLabel,
                        icon: FF.art('icon_retry', size: 28),
                        tone: onRevive == null ? ButtonTone.amber : ButtonTone.blood,
                        width: 190,
                        height: 58,
                        pulse: onRevive == null,
                        onPressed: busy ? null : onRetry,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(child: _Plate(title, color: FF.blood2)),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Pause
// -----------------------------------------------------------------------------

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    required this.heading,
    required this.progress,
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
    this.quitLabel = 'QUIT',
    super.key,
  });

  final String heading;
  final ProgressController progress;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;
  final String quitLabel;

  @override
  Widget build(BuildContext context) {
    return _OverlayFrame(
      width: 480,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 34),
            child: StonePanel(
              padding: const EdgeInsets.fromLTRB(22, 44, 22, 20),
              child: ListenableBuilder(
                listenable: progress,
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(heading, textAlign: TextAlign.center, style: FF.text(18, color: FF.boneDim, weight: FontWeight.w700, letterSpacing: 2)),
                    const SizedBox(height: 14),
                    SlabButton(label: 'RESUME', icon: const FFIcon(FFGlyph.play, size: 28), height: 62, pulse: true, onPressed: onResume),
                    const SizedBox(height: 10),
                    SlabButton(label: 'RESTART', icon: FF.art('icon_retry', size: 26), tone: ButtonTone.stone, height: 54, onPressed: onRestart),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SlabButton(
                            label: progress.musicOn ? 'MUSIC ON' : 'MUSIC OFF',
                            icon: FFIcon(FFGlyph.music, size: 24, color: progress.musicOn ? null : FF.stone3),
                            tone: ButtonTone.stone,
                            height: 50,
                            fontSize: 16,
                            onPressed: () {
                              progress.musicOn = !progress.musicOn;
                              Sfx.instance.setSwitches(musicOn: progress.musicOn, sfxOn: progress.sfxOn);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SlabButton(
                            label: progress.sfxOn ? 'SOUND ON' : 'SOUND OFF',
                            icon: FFIcon(progress.sfxOn ? FFGlyph.sound : FFGlyph.soundOff, size: 24),
                            tone: ButtonTone.stone,
                            height: 50,
                            fontSize: 16,
                            onPressed: () {
                              progress.sfxOn = !progress.sfxOn;
                              Sfx.instance.setSwitches(musicOn: progress.musicOn, sfxOn: progress.sfxOn);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SlabButton(label: quitLabel, icon: FF.art('icon_house', size: 26), tone: ButtonTone.blood, height: 54, onPressed: onQuit),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(top: 0, left: 0, right: 0, child: Center(child: _Plate('Paused'))),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Endless Night results
// -----------------------------------------------------------------------------

class EndlessOverOverlay extends StatelessWidget {
  const EndlessOverOverlay({
    required this.result,
    required this.wisps,
    required this.onAgain,
    required this.onMenu,
    super.key,
  });

  final EndlessResult result;
  final int wisps;
  final VoidCallback onAgain;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return _OverlayFrame(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 34),
            child: StonePanel(
              glow: FF.spirit,
              padding: const EdgeInsets.fromLTRB(22, 44, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('YOU REACHED DEPTH', style: FF.text(18, color: FF.boneDim, weight: FontWeight.w700, letterSpacing: 2)),
                  Text('${result.depth}', style: FF.title(110, color: FF.spiritHi, glow: FF.spirit.withValues(alpha: 0.6))),
                  if (result.newBestDepth || result.newBestScore)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FFIcon(FFGlyph.crown, size: 30),
                          const SizedBox(width: 6),
                          Text('NEW PERSONAL BEST!', style: FF.text(22, color: FF.gold, weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      StatChip(icon: const FFIcon(FFGlyph.flame, size: 22), text: 'SCORE ${formatNumber(result.score)}'),
                      StatChip(icon: const FFIcon(FFGlyph.soul, size: 22), text: '+${result.souls + wisps} SOULS'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SlabButton(
                        label: 'MENU',
                        icon: FF.art('icon_house', size: 26),
                        tone: ButtonTone.stone,
                        width: 170,
                        height: 58,
                        onPressed: onMenu,
                      ),
                      const SizedBox(width: 12),
                      SlabButton(
                        label: 'DESCEND AGAIN',
                        icon: FF.art('icon_retry', size: 28),
                        tone: ButtonTone.spirit,
                        width: 250,
                        height: 58,
                        pulse: true,
                        onPressed: onAgain,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Positioned(top: 0, left: 0, right: 0, child: Center(child: _Plate('The Night Ends'))),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Daily Nightmare result
// -----------------------------------------------------------------------------

class DailyEscapeOverlay extends StatelessWidget {
  const DailyEscapeOverlay({
    required this.summary,
    required this.reward,
    required this.onShare,
    required this.onAgain,
    required this.onMenu,
    super.key,
  });

  final DailySummary summary;
  final Reward? reward;
  final Future<bool> Function() onShare;
  final VoidCallback onAgain;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return _OverlayFrame(
      tint: const Color(0xD9120306),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 34),
            child: StonePanel(
              blood: true,
              glow: FF.blood,
              padding: const EdgeInsets.fromLTRB(22, 44, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('DAILY NIGHTMARE #${summary.number}', style: FF.text(18, color: FF.bone2, weight: FontWeight.w700, letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text(_mmss(summary.seconds), style: FF.title(96, color: FF.bone, glow: FF.blood.withValues(alpha: 0.6))),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      StatChip(icon: const FFIcon(FFGlyph.crown, size: 22), text: 'TODAY ${_mmss(summary.bestSeconds)}'),
                      StatChip(icon: const FFIcon(FFGlyph.flame, size: 22), text: '${summary.streak}-DAY STREAK', color: FF.gold),
                      StatChip(icon: FF.art('icon_skull', size: 22), text: '${summary.deaths}'),
                    ],
                  ),
                  if (reward != null && !reward!.isEmpty) ...[
                    const SizedBox(height: 12),
                    Text("TONIGHT'S PRIZE", style: FF.text(16, color: FF.gold, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    _RewardLine(reward: reward!),
                  ],
                  const SizedBox(height: 10),
                  Text('Come back tomorrow for a new nightmare.', style: FF.text(16, color: FF.bone2)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SlabButton(label: 'MENU', icon: FF.art('icon_house', size: 26), tone: ButtonTone.stone, width: 150, height: 56, onPressed: onMenu),
                      const SizedBox(width: 10),
                      _ShareButton(onShare: onShare),
                      const SizedBox(width: 10),
                      SlabButton(label: 'AGAIN', icon: FF.art('icon_retry', size: 26), tone: ButtonTone.blood, width: 150, height: 56, onPressed: onAgain),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Positioned(top: 0, left: 0, right: 0, child: Center(child: _Plate('Escaped!', color: FF.blood2))),
        ],
      ),
    );
  }
}

class _ShareButton extends StatefulWidget {
  const _ShareButton({required this.onShare});

  final Future<bool> Function() onShare;

  @override
  State<_ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<_ShareButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return SlabButton(
      label: _copied ? 'COPIED!' : 'SHARE',
      tone: ButtonTone.bone,
      width: 160,
      height: 56,
      onPressed: () async {
        final sheet = await widget.onShare();
        if (!sheet && mounted) setState(() => _copied = true);
      },
    );
  }
}

double easeOutBack(double t) {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2);
}
