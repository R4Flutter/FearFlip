import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/night_hud.dart';

export '../../theme/night_hud.dart';

/// The in-run HUD: icons and numbers, no word labels. Stage and checkpoint on
/// the left, lives in the middle (limited-life bands only), the hourglass
/// bar and the pause button on the right.
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
    super.key,
  });

  static const pauseKey = ValueKey<String>('hud_pause');

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
                value: '$stage',
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
          child: Row(
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
              GestureDetector(
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
                    full ? Icons.favorite_rounded : Icons.favorite_border_rounded,
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
