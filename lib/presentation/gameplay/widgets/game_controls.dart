import 'package:flutter/material.dart';
import '../../theme/app_palette.dart';
import '../../../domain/entities/direction4.dart';

class Joystick extends StatefulWidget {
  const Joystick({
    required this.size,
    required this.onDirection,
    required this.onEnd,
    super.key,
  });

  final double size;
  final ValueChanged<Direction4?> onDirection;
  final VoidCallback onEnd;

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  static const double _deadZone = 10;
  Offset _knobOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onPanDown: (details) => _handleDrag(details.localPosition),
        onPanUpdate: (details) => _handleDrag(details.localPosition),
        onPanEnd: (_) => _resetKnob(),
        onPanCancel: _resetKnob,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppPalette.surfaceAlt,
            border: Border.all(
              color: AppPalette.accentPurple.withAlpha(170),
              width: 2.6,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppPalette.neonGreen.withAlpha(90),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Transform.translate(
                  offset: _knobOffset,
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppPalette.neonGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1.2),
                      ),
                      child: const Icon(
                        Icons.control_camera,
                        size: 18,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleDrag(Offset local) {
    final radius = widget.size / 2;
    final maxKnobOffset = widget.size * 0.28;
    final dx = local.dx - radius;
    final dy = local.dy - radius;
    final vector = Offset(dx, dy);
    final distance = vector.distance;

    Offset limited = vector;
    if (distance > maxKnobOffset && distance > 0) {
      limited = vector / distance * maxKnobOffset;
    }

    setState(() {
      _knobOffset = limited;
    });

    widget.onDirection(_directionFromVector(vector));
  }

  void _resetKnob() {
    if (_knobOffset != Offset.zero) {
      setState(() {
        _knobOffset = Offset.zero;
      });
    }
    widget.onEnd();
  }

  Direction4? _directionFromVector(Offset vector) {
    final dx = vector.dx;
    final dy = vector.dy;
    if (dx.abs() < _deadZone && dy.abs() < _deadZone) {
      return null;
    }
    if (dx.abs() > dy.abs()) {
      return dx >= 0 ? Direction4.right : Direction4.left;
    }
    return dy >= 0 ? Direction4.down : Direction4.up;
  }
}

class ArrowPad extends StatelessWidget {
  const ArrowPad({
    required this.size,
    required this.onDirection,
    required this.onEnd,
    super.key,
  });

  final double size;
  final ValueChanged<Direction4?> onDirection;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final padSize = (size * 1.08).clamp(104.0, 188.0);
    final buttonSize = padSize * 0.34;

    return SizedBox(
      width: padSize,
      height: padSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _ArrowButton(
            alignment: Alignment.topCenter,
            icon: Icons.keyboard_arrow_up,
            size: buttonSize,
            onDown: () => onDirection(Direction4.up),
            onUp: onEnd,
          ),
          _ArrowButton(
            alignment: Alignment.bottomCenter,
            icon: Icons.keyboard_arrow_down,
            size: buttonSize,
            onDown: () => onDirection(Direction4.down),
            onUp: onEnd,
          ),
          _ArrowButton(
            alignment: Alignment.centerLeft,
            icon: Icons.keyboard_arrow_left,
            size: buttonSize,
            onDown: () => onDirection(Direction4.left),
            onUp: onEnd,
          ),
          _ArrowButton(
            alignment: Alignment.centerRight,
            icon: Icons.keyboard_arrow_right,
            size: buttonSize,
            onDown: () => onDirection(Direction4.right),
            onUp: onEnd,
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.alignment,
    required this.icon,
    required this.size,
    required this.onDown,
    required this.onUp,
  });

  final Alignment alignment;
  final IconData icon;
  final double size;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTapDown: (_) => onDown(),
        onTapUp: (_) => onUp(),
        onTapCancel: onUp,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppPalette.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppPalette.accentPurple.withAlpha(170),
              width: 1.3,
            ),
          ),
          child: Icon(icon, color: AppPalette.neonGreen, size: size * 0.68),
        ),
      ),
    );
  }
}
