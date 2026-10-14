import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/night_hud.dart';

class StageClearOverlay extends StatelessWidget {
  const StageClearOverlay({
    required this.stage,
    required this.controller,
    super.key,
  });

  final int stage;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final bgFade = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.00, 0.25, curve: Curves.easeIn),
    );
    final burstAnim = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.00, 0.55, curve: Curves.easeOutCubic),
    );
    final slideIn = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.15, 0.55, curve: Curves.easeOutBack),
    );
    final textFade = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.20, 0.55, curve: Curves.easeOut),
    );
    final subFade = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.45, 0.72, curve: Curves.easeOut),
    );
    final starsFade = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.50, 0.82, curve: Curves.easeOut),
    );

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: controller,
          builder: (ctx, _) {
            final t = controller.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: (bgFade.value * 0.80).clamp(0.0, 1.0),
                  child: const ColoredBox(color: Colors.black),
                ),
                Center(
                  child: Opacity(
                    opacity: burstAnim.value,
                    child: CustomPaint(
                      size: const Size(340, 340),
                      painter: _BurstPainter(burstAnim.value),
                    ),
                  ),
                ),
                Opacity(
                  opacity: (t < 0.6 ? t / 0.6 : 1 - (t - 0.6) / 0.4).clamp(0, 1),
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _ScanPainter(t),
                  ),
                ),
                Center(
                  child: FadeTransition(
                    opacity: textFade,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.5),
                        end: Offset.zero,
                      ).animate(slideIn),
                      child: _ClearCard(stage: stage, subFade: subFade),
                    ),
                  ),
                ),
                Opacity(
                  opacity: starsFade.value,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _ParticlePainter(t),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ClearCard extends StatelessWidget {
  const _ClearCard({required this.stage, required this.subFade});
  final int stage;
  final Animation<double> subFade;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      decoration: BoxDecoration(
        color: NightHud.ink.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NightHud.gold, width: 3),
        boxShadow: [
          BoxShadow(
            color: NightHud.amber.withValues(alpha: 0.35),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NightHud.medallion('trophy', size: 84),
          const SizedBox(height: 16),
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              colors: [NightHud.gold, NightHud.amber],
            ).createShader(r),
            child: const Text(
              'STAGE CLEARED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 3.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              colors: [NightHud.bone, NightHud.gold],
            ).createShader(r),
            child: Text(
              '$stage',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 72,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FadeTransition(
            opacity: subFade,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.4),
                end: Offset.zero,
              ).animate(subFade),
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: NightHud.slate.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: NightHud.boneDim.withValues(alpha: 0.6),
                      ),
                    ),
                    child: const Text(
                      'NEXT STAGE LOADING…',
                      style: TextStyle(
                        color: NightHud.bone,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MiniStat(icon: Icons.bolt, label: 'ESCAPED'),
                      const SizedBox(width: 16),
                      _MiniStat(icon: Icons.star_rounded, label: '+1 TROPHY'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext ctx) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: NightHud.gold, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: NightHud.boneDim,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 0.8,
            ),
          ),
        ],
      );
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.width * 0.5 * t;
    canvas.drawCircle(
      Offset(cx, cy),
      maxR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = NightHud.boneDim.withValues(alpha: (1 - t) * 0.8),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      maxR * 0.65,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = NightHud.amber.withValues(alpha: (1 - t) * 0.7),
    );
    const rays = 12;
    final rp = Paint()
      ..strokeWidth = 1.5
      ..color = NightHud.amber.withValues(alpha: (1 - t) * 0.5);
    for (int i = 0; i < rays; i++) {
      final a = (i / rays) * pi * 2;
      canvas.drawLine(
        Offset(cx + maxR * 0.2 * cos(a), cy + maxR * 0.2 * sin(a)),
        Offset(cx + maxR * 0.95 * cos(a), cy + maxR * 0.95 * sin(a)),
        rp,
      );
    }
    canvas.drawCircle(
      Offset(cx, cy),
      maxR * 0.3,
      Paint()
        ..shader = RadialGradient(
          colors: [
            NightHud.amber.withValues(alpha: (1 - t) * 0.3),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(center: Offset(cx, cy), radius: maxR * 0.3),
        ),
    );
  }

  @override
  bool shouldRepaint(_BurstPainter o) => o.t != t;
}

class _ScanPainter extends CustomPainter {
  _ScanPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final y = t * size.height * 1.5 - size.height * 0.25;
    canvas.drawRect(
      Rect.fromLTWH(0, y - 2, size.width, 3),
      Paint()
        ..color = NightHud.amber.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    final p = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..strokeWidth = 0.5;
    const step = 36.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double yy = 0; yy < size.height; yy += step) {
      canvas.drawLine(Offset(0, yy), Offset(size.width, yy), p);
    }
  }

  @override
  bool shouldRepaint(_ScanPainter o) => o.t != t;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.t);
  final double t;
  static const _count = 24;
  static final _seeds = List.generate(_count, (i) => (i * 1.618033) % 1.0);
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    for (int i = 0; i < _count; i++) {
      final seed = _seeds[i];
      final angle = seed * pi * 2;
      final r = size.width * 0.58 * t * (0.3 + seed * 0.7);
      final alpha = (1 - t) * 0.8;
      final radius = (2.5 + seed * 3.0) * (1 - t * 0.5);
      final color = i % 3 == 0
          ? NightHud.amber.withValues(alpha: alpha)
          : i % 3 == 1
              ? NightHud.boneDim.withValues(alpha: alpha)
              : NightHud.blood.withValues(alpha: alpha);
      canvas.drawCircle(
        Offset(cx + r * cos(angle), cy + r * sin(angle)),
        radius,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter o) => o.t != t;
}
