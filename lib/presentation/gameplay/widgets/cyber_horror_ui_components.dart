import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/night_hud.dart';

/// The in-run dialog panel: a Pokémon-style text box, dark slate inside a
/// double frame, its outer line in the dialog's (tamed) accent.
class RealityGlassPanel extends StatelessWidget {
  const RealityGlassPanel({required this.color, super.key});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NightHud.ink.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NightHud.tame(color), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0xAA000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: NightHud.boneDim.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

/// A faint grid in [color] (the stage-100 dialog's gold backdrop).
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
    this.emblem,
    super.key,
  });

  final String title;
  final String subtitle;

  /// Shown when there's no [emblem].
  final IconData icon;
  final Color color;

  /// A UI icon name (`assets/images/2d/ui/icon_<emblem>.png`) shown in the bone
  /// medallion.
  final String? emblem;

  @override
  Widget build(BuildContext context) {
    final accent = NightHud.tame(color);
    return Row(
      children: [
        if (emblem != null)
          NightHud.medallion(emblem!)
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              border: Border.all(
                color: accent.withValues(alpha: 0.5),
                width: 1.5,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 28),
          ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: accent,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  shadows: const [
                    Shadow(color: NightHud.ink, offset: Offset(2, 2)),
                  ],
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: NightHud.boneDim,
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
    final accent = NightHud.tame(color);
    return Container(
      width: isWide ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: NightHud.slate.withValues(alpha: 0.7),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: accent.withValues(alpha: 0.7), size: 12),
                const SizedBox(width: 6),
              ],
              // Long labels shrink to fit a half-width box on small phones.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: accent.withValues(alpha: 0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: NightHud.number(22)),
        ],
      ),
    );
  }
}

/// A text-box option: dark stone with a frame in its (tamed) accent; the
/// primary one is lit.
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
    final accent = NightHud.tame(widget.color);
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
            color: widget.isPrimary
                ? accent.withValues(alpha: 0.2)
                : NightHud.slate.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isPrimary ? accent : accent.withValues(alpha: 0.6),
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isPrimary ? NightHud.bone : accent,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 3,
              shadows: const [
                Shadow(color: NightHud.ink, offset: Offset(1.5, 1.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
