import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_palette.dart';

class GameHud extends StatelessWidget {
  const GameHud({
    required this.stage,
    required this.remainingSeconds,
    required this.isPaused,
    required this.onPauseTap,
    required this.checkpoint,
    this.livesRemaining = -1,
    this.maxLives = 0,
    super.key,
  });

  final int stage;
  final int checkpoint;
  final int remainingSeconds;
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
    final shortestSide = min(screenSize.width, screenSize.height);
    final uiScale = (shortestSide / 390).clamp(0.84, 1.2);

    final floatingLabelSize = (10 * uiScale).clamp(8.0, 12.0);
    final floatingValueSize = (20 * uiScale).clamp(15.0, 24.0);
    final floatingSubValueSize = (14 * uiScale).clamp(11.0, 18.0);

    final isPanic = remainingSeconds <= 10;
    final timeDigits = remainingSeconds.toString().padLeft(2, '0');

    return Stack(
      children: [
        // ── Left: Stage & Checkpoint ─────────────────────────────────────────
        Positioned(
          left: 0,
          top: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FloatingHudMetric(
                label: 'STAGE',
                value: stage.toString(),
                labelColor: const Color(0xFF79EFFF),
                valueColor: AppPalette.accentPink,
                labelSize: floatingLabelSize,
                valueSize: floatingValueSize,
                icon: Icons.auto_awesome_rounded,
              ),
              const SizedBox(height: 8),
              _FloatingHudMetric(
                label: 'CHECKPOINT',
                value: checkpoint.toString(),
                labelColor: const Color(0xFFC5B0FF),
                valueColor: AppPalette.accentPurple,
                labelSize: floatingLabelSize,
                valueSize: floatingSubValueSize,
                icon: Icons.flag_rounded,
              ),
            ],
          ),
        ),

        // ── Center: Pink hearts (only for limited-life bands) ─────────────────
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

        // ── Right: Time & Pause ───────────────────────────────────────────────
        Positioned(
          right: 0,
          top: 0,
          child: _FloatingTimeControl(
            isPanic: isPanic,
            isPaused: isPaused,
            timeDigits: timeDigits,
            labelSize: floatingLabelSize,
            valueSize: floatingValueSize,
            onPauseTap: onPauseTap,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated pink hearts
// ─────────────────────────────────────────────────────────────────────────────

/// Renders [maxLives] hearts in a row.
/// Filled pink hearts = remaining revives; ghost outlines = spent revives.
/// The rightmost remaining heart pulses whenever a life is lost.
class _HeartsDisplay extends StatefulWidget {
  const _HeartsDisplay({
    required this.livesRemaining,
    required this.maxLives,
  });

  final int livesRemaining;
  final int maxLives;

  @override
  State<_HeartsDisplay> createState() => _HeartsDisplayState();
}

class _HeartsDisplayState extends State<_HeartsDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _scaleAnim;
  int _prevLives = -1;

  static const Color _kHeartFull = Color(0xFFFF3D8B);
  static const Color _kHeartEmpty = Color(0x44FF3D8B);

  @override
  void initState() {
    super.initState();
    _prevLives = widget.livesRemaining;
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.45),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.45, end: 1.0),
        weight: 65,
      ),
    ]).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_HeartsDisplay old) {
    super.didUpdateWidget(old);
    // Pulse when a life is consumed (count drops).
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

  double _heartSize(int total) {
    // Scale hearts down gracefully when there are many.
    if (total <= 3) return 22;
    if (total <= 5) return 19;
    return 16;
  }

  @override
  Widget build(BuildContext context) {
    final size = _heartSize(widget.maxLives);

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0x55000000),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _kHeartFull.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(widget.maxLives, (i) {
              final isFilled = i < widget.livesRemaining;
              // Animate only the last filled heart (the one just lost next).
              final isNext = isFilled && i == widget.livesRemaining - 1;

              return Transform.scale(
                scale: isNext ? _scaleAnim.value : 1.0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    isFilled
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFilled ? _kHeartFull : _kHeartEmpty,
                    size: size,
                    shadows: isFilled
                        ? [
                            Shadow(
                              color: _kHeartFull.withValues(alpha: 0.65),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Existing HUD sub-widgets (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _FloatingHudMetric extends StatelessWidget {
  const _FloatingHudMetric({
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
    required this.labelSize,
    required this.valueSize,
    required this.icon,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;
  final double labelSize;
  final double valueSize;
  final IconData icon;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final textAlign = alignEnd ? TextAlign.right : TextAlign.left;
    final crossAxis =
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: crossAxis,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: labelColor.withValues(alpha: 0.9),
              size: labelSize + 3,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              textAlign: textAlign,
              style: TextStyle(
                color: labelColor,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.9,
                fontSize: labelSize,
                height: 1,
                shadows: [
                  Shadow(
                    color: labelColor.withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
        Text(
          value,
          textAlign: textAlign,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
            fontSize: valueSize,
            height: 1,
            shadows: [
              Shadow(
                color: valueColor.withValues(alpha: 0.6),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
              const Shadow(
                color: Color(0x99000000),
                blurRadius: 9,
                offset: Offset(0, 3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FloatingTimeControl extends StatelessWidget {
  const _FloatingTimeControl({
    required this.isPanic,
    required this.isPaused,
    required this.timeDigits,
    required this.labelSize,
    required this.valueSize,
    required this.onPauseTap,
  });

  final bool isPanic;
  final bool isPaused;
  final String timeDigits;
  final double labelSize;
  final double valueSize;
  final VoidCallback onPauseTap;

  @override
  Widget build(BuildContext context) {
    final labelColor =
        isPanic ? const Color(0xFFFFA39A) : const Color(0xFFB7FFA8);
    final valueColor = isPanic ? AppPalette.danger : AppPalette.neonGreen;
    final buttonColor = isPaused
        ? AppPalette.neonGreen.withValues(alpha: 0.85)
        : AppPalette.accentPurple.withValues(alpha: 0.85);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IgnorePointer(
          child: _FloatingHudMetric(
            label: 'TIME',
            value: timeDigits,
            labelColor: labelColor,
            valueColor: valueColor,
            labelSize: labelSize,
            valueSize: valueSize,
            icon:
                isPanic ? Icons.favorite_rounded : Icons.schedule_rounded,
            alignEnd: true,
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: isPaused ? 'Resume run' : 'Pause run',
          child: Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: buttonColor,
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.55)),
              boxShadow: [
                BoxShadow(
                  color: buttonColor.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              constraints: const BoxConstraints.tightFor(
                width: 34,
                height: 34,
              ),
              padding: EdgeInsets.zero,
              splashRadius: 18,
              onPressed: onPauseTap,
              icon: Icon(
                isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                size: 20,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
