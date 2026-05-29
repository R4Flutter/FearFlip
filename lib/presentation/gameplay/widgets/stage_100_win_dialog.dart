import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cyber_horror_ui_components.dart';

class Stage100WinDialog extends StatefulWidget {
  const Stage100WinDialog({
    required this.onPlayAgain,
    required this.onExit,
    super.key,
  });

  final VoidCallback onPlayAgain;
  final VoidCallback onExit;

  @override
  State<Stage100WinDialog> createState() => _Stage100WinDialogState();
}

class _Stage100WinDialogState extends State<Stage100WinDialog>
    with TickerProviderStateMixin {
  late AnimationController _crownController;
  late AnimationController _glowController;
  late AnimationController _entryController;
  late AnimationController _particleController;
  late Animation<double> _crownBounce;
  late Animation<double> _glow;

  static const Color _kGold = Color(0xFFFFD700);
  static const Color _kGoldLight = Color(0xFFFFF176);
  static const Color _kGoldDark = Color(0xFFFF8F00);

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _crownController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _crownBounce = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _crownController, curve: Curves.easeInOut),
    );
    _glow = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _entryController.forward();
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _crownController.dispose();
    _glowController.dispose();
    _entryController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _entryController,
        curve: Curves.elasticOut,
      ),
      child: FadeTransition(
        opacity: _entryController,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Gold glass background panel ──
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _glowController,
                builder: (_, _) => Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0800).withValues(alpha: 0.97),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                      topRight: Radius.circular(4),
                      bottomLeft: Radius.circular(4),
                    ),
                    border: Border.all(
                      color: _kGold.withValues(alpha: 0.35 + _glow.value * 0.45),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _kGold.withValues(alpha: _glow.value * 0.30),
                        blurRadius: 44,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: _kGoldDark.withValues(alpha: _glow.value * 0.15),
                        blurRadius: 80,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(38),
                      bottomRight: Radius.circular(38),
                    ),
                    child: CustomPaint(
                      painter: CyberGridPainter(
                        color: _kGold.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Gold particle confetti ──
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _particleController,
                builder: (_, _) => CustomPaint(
                  painter: _GoldParticlePainter(_particleController.value),
                ),
              ),
            ),

            // ── Content ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Crown icon
                    AnimatedBuilder(
                      animation: _crownBounce,
                      builder: (_, _) => Transform.translate(
                        offset: Offset(0, _crownBounce.value),
                        child: AnimatedBuilder(
                          animation: _glow,
                          builder: (_, _) => Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  _kGold.withValues(alpha: 0.22 * _glow.value),
                                  _kGoldDark.withValues(alpha: 0.05),
                                ],
                              ),
                              border: Border.all(
                                color: _kGold.withValues(alpha: 0.6 * _glow.value),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _kGold.withValues(alpha: 0.5 * _glow.value),
                                  blurRadius: 28,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                '👑',
                                style: TextStyle(fontSize: 44),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // "FEAR CONQUERED" gradient title
                    ShaderMask(
                      shaderCallback: (r) => const LinearGradient(
                        colors: [_kGoldLight, _kGold, _kGoldDark],
                        stops: [0.0, 0.5, 1.0],
                      ).createShader(r),
                      child: const Text(
                        'FEAR CONQUERED',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ALL 100 STAGES CLEARED',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _kGold.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Stats row
                    Row(
                      children: [
                        Expanded(
                          child: HorrorStatBox(
                            label: 'STAGES',
                            value: '100',
                            color: _kGold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: HorrorStatBox(
                            label: 'RANK',
                            value: 'MASTER',
                            color: _kGoldLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    HorrorStatBox(
                      label: 'ACHIEVEMENT UNLOCKED',
                      value: 'LEGEND',
                      color: _kGoldDark,
                      isWide: true,
                    ),
                    const SizedBox(height: 20),

                    // Inspirational quote
                    AnimatedBuilder(
                      animation: _glow,
                      builder: (_, _) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _kGold.withValues(alpha: 0.06),
                          border: Border.all(
                            color: _kGold.withValues(alpha: 0.2 + _glow.value * 0.2),
                          ),
                        ),
                        child: Text(
                          '"You didn\'t just escape the maze.\nYou became the maze."',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _kGold.withValues(alpha: 0.55 + _glow.value * 0.35),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Play Again (gold primary)
                    _GoldFearButton(
                      label: 'PLAY AGAIN',
                      onPressed: widget.onPlayAgain,
                      isPrimary: true,
                    ),
                    const SizedBox(height: 12),
                    _GoldFearButton(
                      label: 'EXIT TO MENU',
                      onPressed: widget.onExit,
                      isPrimary: false,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Gold-themed button ────────────────────────────────────────────────────────

class _GoldFearButton extends StatefulWidget {
  const _GoldFearButton({
    required this.label,
    required this.onPressed,
    required this.isPrimary,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  @override
  State<_GoldFearButton> createState() => _GoldFearButtonState();
}

class _GoldFearButtonState extends State<_GoldFearButton> {
  bool _pressed = false;

  static const Color _kGold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
        HapticFeedback.heavyImpact();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 60,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: widget.isPrimary
                ? const LinearGradient(
                    colors: [
                      Color(0xFFFF8F00),
                      Color(0xFFFFD700),
                      Color(0xFFFFF176),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  )
                : null,
            color: widget.isPrimary ? null : Colors.black.withValues(alpha: 0.3),
            border: Border.all(color: _kGold, width: 2),
            boxShadow: widget.isPrimary
                ? [
                    BoxShadow(
                      color: _kGold.withValues(alpha: 0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isPrimary ? Colors.black : _kGold,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 2.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Gold particle painter ─────────────────────────────────────────────────────

class _GoldParticlePainter extends CustomPainter {
  _GoldParticlePainter(this.t);
  final double t;

  static const _count = 28;
  static final _seeds = List.generate(_count, (i) => (i * 0.618033) % 1.0);
  static final _speeds = List.generate(_count, (i) => 0.3 + (i * 0.7) % 0.7);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < _count; i++) {
      final seed = _seeds[i];
      final speed = _speeds[i];
      final phase = (t * speed + seed) % 1.0;
      final x = (seed * size.width +
              sin(t * pi * 2 + seed * 10) * 28) %
          size.width;
      final y = size.height * (1.0 - phase);
      final alpha = (1.0 - phase) * 0.55;
      final radius = 1.5 + seed * 2.5;
      final color = i % 3 == 0
          ? const Color(0xFFFFD700).withValues(alpha: alpha)
          : i % 3 == 1
              ? const Color(0xFFFFF176).withValues(alpha: alpha * 0.8)
              : const Color(0xFFFF8F00).withValues(alpha: alpha * 0.7);
      canvas.drawCircle(Offset(x, y), radius, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_GoldParticlePainter o) => o.t != t;
}
