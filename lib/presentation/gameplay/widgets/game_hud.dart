import 'dart:math';

import 'package:flutter/material.dart';

import '../../../arcade/ui/ff_icons.dart';
import '../../theme/night_hud.dart';

export '../../theme/night_hud.dart';

/// The in-run HUD: icons and numbers, no word labels. Stage, checkpoint and
/// (on key-hunt stages) the key slots and boxes left on the left, lives in the
/// middle (limited-life bands only), the hourglass bar and the pause button on
/// the right.
class GameHud extends StatelessWidget {
  const GameHud({
    required this.stage,
    required this.remainingSeconds,
    required this.isPaused,
    required this.onPauseTap,
    required this.checkpoint,
    this.totalSeconds = 105,
    this.livesRemaining = -1,
    this.maxLives = 0,
    this.keysFound = 0,
    this.keysRequired = 0,
    this.boxesLeft = 0,
    this.stageLabel,
    this.souls,
    this.shield = 0,
    this.starsNow,
    super.key,
  });

  static const pauseKey = ValueKey<String>('hud_pause');
  static const keysKey = ValueKey<String>('hud_keys');

  final int stage;
  final int checkpoint;
  final int remainingSeconds;

  /// The stage's full clock, so the hourglass bar knows how much has drained.
  final int totalSeconds;
  final bool isPaused;
  final VoidCallback onPauseTap;

  /// Lives left in the current checkpoint band.
  /// -1 means unlimited (stages 1–25) → no hearts shown.
  final int livesRemaining;

  /// Total hearts to display for the band. 0 when unlimited.
  final int maxLives;

  /// Key hunt: keys found of [keysRequired] (0 = no hunt, nothing shown) and
  /// shut boxes left.
  final int keysFound;
  final int keysRequired;
  final int boxesLeft;

  /// Shown instead of the stage number (the Daily Nightmare shows "#12").
  final String? stageLabel;

  /// Soul wisps found this run (arcade menus); null hides the counter.
  final int? souls;

  /// Holy wards held (each blocks one death).
  final int shield;

  /// Stars an escape would earn right now (campaign); null hides them.
  final int? starsNow;

  bool get _showHearts => livesRemaining >= 0 && maxLives > 0;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final uiScale = (min(screenSize.width, screenSize.height) / 390).clamp(
      0.84,
      1.2,
    );
    final isPanic = remainingSeconds <= 10;
    final fraction = totalSeconds <= 0
        ? 0.0
        : (remainingSeconds / totalSeconds).clamp(0.0, 1.0);

    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Metric(
                icon: 'icon_maze',
                fallback: Icons.grid_view_rounded,
                value: stageLabel ?? '$stage',
                size: 26 * uiScale,
                fontSize: 21 * uiScale,
              ),
              if (checkpoint > 0) ...[
                SizedBox(height: 4 * uiScale),
                _Metric(
                  icon: 'icon_flag',
                  fallback: Icons.flag_rounded,
                  value: '$checkpoint',
                  size: 20 * uiScale,
                  fontSize: 15 * uiScale,
                ),
              ],
              if (souls != null) ...[
                SizedBox(height: 6 * uiScale),
                _SoulPill(souls: souls!, scale: uiScale),
              ],
              if (shield > 0) ...[
                SizedBox(height: 6 * uiScale),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FFIcon(FFGlyph.shield, size: 26 * uiScale),
                    if (shield > 1)
                      Text(' ×$shield', style: NightHud.number(15 * uiScale)),
                  ],
                ),
              ],
              if (keysRequired > 0) ...[
                SizedBox(height: 6 * uiScale),
                _KeySlots(
                  key: keysKey,
                  found: keysFound,
                  needed: keysRequired,
                  boxesLeft: boxesLeft,
                  scale: uiScale,
                ),
              ],
            ],
          ),
        ),
        if (_showHearts)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: _HeartsDisplay(
                livesRemaining: livesRemaining,
                maxLives: maxLives,
              ),
            ),
          ),
        Positioned(
          right: 0,
          top: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IgnorePointer(
                child: TimeBar(
                  fraction: fraction,
                  panic: isPanic,
                  width: 132 * uiScale,
                  child: Text(
                    remainingSeconds.toString().padLeft(2, '0'),
                    style: NightHud.number(
                      15 * uiScale,
                      color: isPanic ? NightHud.blood : NightHud.bone,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 6 * uiScale),
              Tooltip(
                message: isPaused ? 'Resume run' : 'Pause run',
                child: GestureDetector(
                  key: pauseKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: onPauseTap,
                  child: NightHud.art(
                    isPaused ? 'button_pressed' : 'button',
                    width: 42 * uiScale,
                    fallback: Icon(
                      isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      color: NightHud.bone,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (starsNow != null)
            Padding(
              padding: EdgeInsets.only(top: 4 * uiScale, right: 48 * uiScale),
              child: _StarsNow(stars: starsNow!, scale: uiScale),
            ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.fallback,
    required this.value,
    required this.size,
    required this.fontSize,
  });

  final String icon;
  final IconData fallback;
  final String value;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NightHud.art(
          icon,
          width: size,
          fallback: Icon(fallback, color: NightHud.bone, size: size * 0.8),
        ),
        const SizedBox(width: 5),
        Text(value, style: NightHud.number(fontSize)),
      ],
    );
  }
}

/// The hourglass bar: the delivered stone frame with its sand, the spent part
/// of the slot drained dark from the right. The sand reddens in the last ten
/// seconds. [child] (the seconds) sits on the sand.
class TimeBar extends StatelessWidget {
  const TimeBar({
    required this.fraction,
    required this.panic,
    required this.width,
    required this.child,
    super.key,
  });

  /// Share of the clock left, 0..1.
  final double fraction;
  final bool panic;
  final double width;
  final Widget child;

  /// The sand slot inside ui/timebar.png (512×128), as fractions of it.
  static const slot = Rect.fromLTRB(0.176, 0.297, 0.941, 0.719);

  @override
  Widget build(BuildContext context) {
    final height = width / 4;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          NightHud.art(
            'timebar',
            width: width,
            height: height,
            fit: BoxFit.fill,
            fallback: DecoratedBox(
              decoration: BoxDecoration(
                color: NightHud.stone,
                border: Border.all(color: NightHud.ink, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          CustomPaint(painter: _DrainPainter(fraction, panic)),
          Positioned(
            left: width * slot.left,
            top: height * slot.top,
            width: width * slot.width,
            height: height * slot.height,
            child: Center(child: child),
          ),
        ],
      ),
    );
  }
}

class _DrainPainter extends CustomPainter {
  _DrainPainter(this.fraction, this.panic);

  final double fraction;
  final bool panic;

  @override
  void paint(Canvas canvas, Size size) {
    final s = TimeBar.slot;
    final slot = Rect.fromLTRB(
      size.width * s.left,
      size.height * s.top,
      size.width * s.right,
      size.height * s.bottom,
    );
    final edge = slot.left + slot.width * fraction;
    canvas.drawRect(
      Rect.fromLTRB(edge, slot.top, slot.right, slot.bottom),
      Paint()..color = const Color(0xE6120E10),
    );
    if (panic) {
      canvas.drawRect(
        Rect.fromLTRB(slot.left, slot.top, edge, slot.bottom),
        Paint()..color = const Color(0x8CB0202A),
      );
    }
  }

  @override
  bool shouldRepaint(_DrainPainter old) =>
      old.fraction != fraction || old.panic != panic;
}

/// Hearts for the band's revives: full ones left, empty ones spent. The last
/// full heart pulses when a life is lost.
class _HeartsDisplay extends StatefulWidget {
  const _HeartsDisplay({required this.livesRemaining, required this.maxLives});

  final int livesRemaining;
  final int maxLives;

  @override
  State<_HeartsDisplay> createState() => _HeartsDisplayState();
}

class _HeartsDisplayState extends State<_HeartsDisplay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _scaleAnim = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.45), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 1.45, end: 1.0), weight: 65),
  ]).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));
  late int _prevLives = widget.livesRemaining;

  @override
  void didUpdateWidget(_HeartsDisplay old) {
    super.didUpdateWidget(old);
    if (widget.livesRemaining < _prevLives) {
      _pulseCtrl.forward(from: 0);
    }
    _prevLives = widget.livesRemaining;
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.maxLives <= 3
        ? 26.0
        : widget.maxLives <= 5
        ? 22.0
        : 18.0;
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: NightHud.ink.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.maxLives, (i) {
            final full = i < widget.livesRemaining;
            final next = full && i == widget.livesRemaining - 1;
            return Transform.scale(
              scale: next ? _scaleAnim.value : 1.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: NightHud.art(
                  full ? 'icon_heart' : 'icon_heart_empty',
                  width: size,
                  fallback: Icon(
                    full
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: full ? NightHud.blood : NightHud.boneDim,
                    size: size,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// The key hunt in the HUD: one slot per key the exit needs (gold once
/// found; the newest pulses) and the shut boxes left, so the odds are in view.
class _KeySlots extends StatefulWidget {
  const _KeySlots({
    required this.found,
    required this.needed,
    required this.boxesLeft,
    required this.scale,
    super.key,
  });

  final int found;
  final int needed;
  final int boxesLeft;
  final double scale;

  @override
  State<_KeySlots> createState() => _KeySlotsState();
}

class _KeySlotsState extends State<_KeySlots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.6), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 1.6, end: 1.0), weight: 65),
  ]).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));

  @override
  void didUpdateWidget(_KeySlots old) {
    super.didUpdateWidget(old);
    if (widget.found > old.found) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = 22 * widget.scale;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 6 * widget.scale,
        vertical: 3 * widget.scale,
      ),
      decoration: BoxDecoration(
        color: NightHud.ink.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.needed; i++)
            AnimatedBuilder(
              animation: _scale,
              builder: (context, child) => Transform.scale(
                scale: i == widget.found - 1 ? _scale.value : 1.0,
                child: child,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: NightHud.art(
                  i < widget.found ? 'icon_key' : 'icon_key_empty',
                  width: size,
                  fallback: Icon(
                    i < widget.found
                        ? Icons.vpn_key_rounded
                        : Icons.vpn_key_outlined,
                    color: i < widget.found ? NightHud.gold : NightHud.boneDim,
                    size: size * 0.9,
                  ),
                ),
              ),
            ),
          SizedBox(width: 8 * widget.scale),
          NightHud.art(
            'icon_chest',
            width: size * 0.9,
            fallback: Icon(
              Icons.inventory_2_rounded,
              color: NightHud.boneDim,
              size: size * 0.8,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            '${widget.boxesLeft}',
            style: NightHud.number(15 * widget.scale),
          ),
        ],
      ),
    );
  }
}


/// The wisps found this run.
class _SoulPill extends StatelessWidget {
  const _SoulPill({required this.souls, required this.scale});

  final int souls;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(souls),
      tween: Tween(begin: 1.35, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      builder: (context, v, child) => Transform.scale(scale: souls == 0 ? 1 : v, alignment: Alignment.centerLeft, child: child),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FFIcon(FFGlyph.soul, size: 26 * scale),
          const SizedBox(width: 4),
          Text('$souls', style: NightHud.number(17 * scale, color: NightHud.spirit)),
        ],
      ),
    );
  }
}

/// The stars an escape would earn right now; they drop as the clock runs.
class _StarsNow extends StatelessWidget {
  const _StarsNow({required this.stars, required this.scale});

  final int stars;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            AnimatedScale(
              scale: i < stars ? 1 : 0.8,
              duration: const Duration(milliseconds: 300),
              child: FFIcon(i < stars ? FFGlyph.star : FFGlyph.starEmpty, size: 20 * scale),
            ),
        ],
      ),
    );
  }
}

/// The flip timer: a ring that fills toward the next flip and burns red just
/// before it, so a flip is never a surprise. Shows which world is up.
class FlipDial extends StatelessWidget {
  const FlipDial({
    required this.progress,
    required this.soon,
    required this.flipped,
    this.scale = 1,
    this.compact = false,
    super.key,
  });

  final double progress;
  final bool soon;
  final bool flipped;
  final double scale;

  /// Just the dial, no word beside it (narrow screens).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = 46 * scale;
    return IgnorePointer(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _DialPainter(progress: progress, soon: soon, flipped: flipped),
            ),
          ),
          if (!compact) SizedBox(width: 6 * scale),
          if (!compact)
          Text(
            soon ? 'FLIP!' : (flipped ? 'FLIPPED' : 'NORMAL'),
            style: NightHud.number(
              15 * scale,
              color: soon ? NightHud.blood : (flipped ? NightHud.blood : NightHud.boneDim),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.progress, required this.soon, required this.flipped});

  final double progress;
  final bool soon;
  final bool flipped;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 3;
    canvas.drawCircle(c, r + 2, Paint()..color = NightHud.ink.withValues(alpha: 0.8));
    canvas.drawCircle(
      c,
      r - 3,
      Paint()..color = flipped ? const Color(0xFF4D0E15) : const Color(0xFF3B4660),
    );
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = soon ? NightHud.blood : NightHud.amber;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi / 2, 2 * pi * progress, false, ring);
    // Two curved arrows: the flip symbol.
    final arrow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..color = NightHud.bone;
    final a = r * 0.48;
    canvas.drawArc(Rect.fromCircle(center: c, radius: a), -pi * 0.9, pi * 0.75, false, arrow);
    canvas.drawArc(Rect.fromCircle(center: c, radius: a), pi * 0.1, pi * 0.75, false, arrow);
    void head(double angle) {
      final p = c + Offset(cos(angle), sin(angle)) * a;
      final dir = Offset(-sin(angle), cos(angle));
      final path = Path()
        ..moveTo(p.dx + dir.dx * 4, p.dy + dir.dy * 4)
        ..lineTo(p.dx - dir.dx * 1 + cos(angle) * 4, p.dy - dir.dy * 1 + sin(angle) * 4)
        ..lineTo(p.dx - dir.dx * 1 - cos(angle) * 4, p.dy - dir.dy * 1 - sin(angle) * 4)
        ..close();
      canvas.drawPath(path, Paint()..color = NightHud.bone);
    }
    head(-pi * 0.15);
    head(pi * 0.85);
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.progress != progress || old.soon != soon || old.flipped != flipped;
}
