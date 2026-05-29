import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_palette.dart';

class RealityGlassPanel extends StatelessWidget {
  const RealityGlassPanel({required this.color, super.key});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0C16).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
          topRight: Radius.circular(4),
          bottomLeft: Radius.circular(4),
        ),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(38),
          bottomRight: Radius.circular(38),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: CyberGridPainter(color: color),
              ),
            ),
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CyberGridPainter extends CustomPainter {
  CyberGridPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    const spacing = 32.0;
    for (double i = 0; i <= size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i <= size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HorrorHeader extends StatelessWidget {
  const HorrorHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class HorrorStatBox extends StatelessWidget {
  const HorrorStatBox({
    required this.label,
    required this.value,
    required this.color,
    this.icon,
    this.isWide = false,
    super.key,
  });

  final String label;
  final String value;
  final Color color;
  final IconData? icon;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isWide ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: color.withValues(alpha: 0.7), size: 12),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class FearButton extends StatefulWidget {
  const FearButton({
    required this.label,
    required this.onPressed,
    required this.color,
    this.isPrimary = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final Color color;
  final bool isPrimary;

  @override
  State<FearButton> createState() => _FearButtonState();
}

class _FearButtonState extends State<FearButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
        HapticFeedback.heavyImpact();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 60,
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.isPrimary ? widget.color : Colors.black.withValues(alpha: 0.3),
            border: Border.all(color: widget.color, width: 2),
            boxShadow: widget.isPrimary ? [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ] : null,
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isPrimary ? Colors.black : widget.color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 3,
            ),
          ),
        ),
      ),
    );
  }
}
